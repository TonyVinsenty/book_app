import Flutter
import UIKit
import UniformTypeIdentifiers

// Channel and method names are checked against Dart by test/guards.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let filesChannel = "com.tonyvinsenty.bookapp/files"
  private let screenChannel = "com.tonyvinsenty.bookapp/screen"
  private var bookPicker: BookPicker?
  private var pickedFolders: PickedFolders?
  // Kept here: the registrar holds scene delegates weakly.
  private var incomingFiles: IncomingFiles?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Our scene delegate goes first: Flutter gives a file URL to the first
    // plugin that takes it.
    defer { GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry) }
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BookFiles") else {
      return
    }
    let picker = BookPicker(registrar: registrar)
    bookPicker = picker
    let folders = PickedFolders(registrar: registrar)
    pickedFolders = folders
    let files = FlutterMethodChannel(name: filesChannel, binaryMessenger: registrar.messenger())
    // Registered before the scene connects (the storyboard creates the
    // engine first), so a cold start with a file reaches it too.
    let incoming = IncomingFiles(channel: files)
    incomingFiles = incoming
    registrar.addSceneDelegate(incoming)
    files.setMethodCallHandler { call, result in
      switch call.method {
      case "pickBooks": picker.pick(result)
      case "hasInitialFiles": incoming.hasInitialFiles(result)
      case "pickFolder": folders.pick(result)
      case "listFolder": folders.list(call.arguments as? String ?? "", result)
      case "copyFolderFiles":
        let args = call.arguments as? [String: Any]
        folders.copy(args?["ref"] as? String ?? "", args?["keys"] as? [String] ?? [], result)
      // A bookmark holds no lasting access to give back.
      case "releaseFolder": result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    FlutterMethodChannel(name: screenChannel, binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        switch call.method {
        case "setKeepOn":
          UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
  }
}

/// Files from other apps ("Open in", "Share", ADR 0005). Flutter passes
/// scene events to it like to a plugin; answering true also keeps Flutter
/// from taking the file URL for a deep link. Copies go to
/// tmp/incoming/<n>/<file name>, like MainActivity.kt does on Android.
private final class IncomingFiles: NSObject, FlutterSceneLifeCycleDelegate {
  // Shared by all instances: a reconnected scene gets a new engine and a
  // new instance, whose cleanup must not cut into a copy still running.
  private static let io = DispatchQueue(label: "com.tonyvinsenty.bookapp.incoming")
  private static var count = 0  // Used on io only.

  private let channel: FlutterMethodChannel
  // Files the app was started with, kept until Dart asks for them;
  // nil once it has (later files go straight to Dart).
  private var initial: [URL]? = []

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    // Each engine has its own Dart side, so nothing still uses old copies.
    // The serial queue runs this before any new copy.
    IncomingFiles.io.async { try? FileManager.default.removeItem(at: IncomingFiles.root) }
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    return receive(connectionOptions?.urlContexts.map(\.url) ?? [])
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return receive(URLContexts.map(\.url))
  }

  // Answers at once, so the first screen doesn't wait for big copies;
  // the files follow through onIncomingFiles.
  func hasInitialFiles(_ result: FlutterResult) {
    let urls = initial ?? []
    initial = nil
    result(!urls.isEmpty)
    if !urls.isEmpty { send(urls) }
  }

  private func receive(_ all: [URL]) -> Bool {
    let urls = all.filter(\.isFileURL)
    if urls.isEmpty { return false }
    if initial != nil {
      initial?.append(contentsOf: urls)
    } else {
      send(urls)
    }
    return true
  }

  private func send(_ urls: [URL]) {
    IncomingFiles.io.async {
      let paths = urls.map { IncomingFiles.makeCopy(of: $0) }
      DispatchQueue.main.async {
        self.channel.invokeMethod("onIncomingFiles", arguments: paths)
      }
    }
  }

  private static var root: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("incoming", isDirectory: true)
  }

  // Runs on io: each file gets its own folder, as earlier ones may still
  // wait in the Dart import queue (it deletes each copy when done). A file
  // that can't be read still gets a path, with nothing there: the importer
  // then tells the user it couldn't open it. Once copied, the system's
  // copy in Documents/Inbox is removed, so it doesn't pile up.
  private static func makeCopy(of url: URL) -> String {
    let dir = root.appendingPathComponent(String(count), isDirectory: true)
    count += 1
    guard let file = copyFile(url, into: dir) else {
      return dir.appendingPathComponent(fileName(url)).path
    }
    if isInInbox(url) { try? FileManager.default.removeItem(at: url) }
    return file.path
  }

  // Only the system's copies are removed, never a file opened in place.
  private static func isInInbox(_ url: URL) -> Bool {
    guard
      let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    else { return false }
    let inbox = docs.appendingPathComponent("Inbox").resolvingSymlinksInPath().path + "/"
    return url.resolvingSymlinksInPath().path.hasPrefix(inbox)
  }
}

/// Shows the system file picker and returns paths to copies in
/// tmp/picked/<n>/<file name>, like MainActivity.kt does on Android.
private final class BookPicker: NSObject, UIDocumentPickerDelegate {
  private weak var registrar: FlutterPluginRegistrar?
  private var pending: FlutterResult?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  func pick(_ result: @escaping FlutterResult) {
    if pending != nil {
      result(FlutterError(code: "busy", message: "A file picker is already open", details: nil))
      return
    }
    guard var host = registrar?.viewController else {
      result(FlutterError(code: "unavailable", message: "No view to show the picker", details: nil))
      return
    }
    while let presented = host.presentedViewController { host = presented }
    pending = result
    // FB2 may come without a known type, so every file is offered.
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
    picker.allowsMultipleSelection = true
    picker.delegate = self
    host.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finish(urls)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish([])
  }

  private func finish(_ urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    DispatchQueue.global(qos: .userInitiated).async {
      let paths = BookPicker.copyToTemp(urls)
      DispatchQueue.main.async { result(paths) }
    }
  }

  // Files that can't be read are skipped. The previous pick is removed first.
  private static func copyToTemp(_ urls: [URL]) -> [String] {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("picked", isDirectory: true)
    try? fm.removeItem(at: root)
    return urls.enumerated().compactMap { (i, url) in
      copyFile(url, into: root.appendingPathComponent(String(i), isDirectory: true))?.path
    }
  }
}

/// Folders the user connects (ADR 0007). A folder is a bookmark (base64);
/// listing and copies run on their own queue, so incoming files don't wait
/// for a long listing. Copies go to tmp/folders/<n>/<file name>, like
/// MainActivity.kt does on Android.
private final class PickedFolders: NSObject, UIDocumentPickerDelegate {
  private static let io = DispatchQueue(label: "com.tonyvinsenty.bookapp.folders")
  private static var count = 0  // Used on io only.
  private static let maxDepth = 8  // As in Dart.

  private weak var registrar: FlutterPluginRegistrar?
  private var pending: FlutterResult?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
    // Each engine has its own Dart side, so nothing still uses old copies.
    PickedFolders.io.async { try? FileManager.default.removeItem(at: PickedFolders.root) }
  }

  func pick(_ result: @escaping FlutterResult) {
    if pending != nil {
      result(FlutterError(code: "busy", message: "A folder picker is already open", details: nil))
      return
    }
    guard var host = registrar?.viewController else {
      result(FlutterError(code: "unavailable", message: "No view to show the picker", details: nil))
      return
    }
    while let presented = host.presentedViewController { host = presented }
    pending = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    host.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    PickedFolders.io.async {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      let ref = PickedFolders.bookmark(url)
      let name = (try? url.resourceValues(forKeys: [.localizedNameKey]))?.localizedName
      DispatchQueue.main.async {
        if let ref = ref {
          result(["ref": ref, "name": name ?? url.lastPathComponent])
        } else {
          result(FlutterError(code: "denied", message: "No bookmark for the folder", details: nil))
        }
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let result = pending else { return }
    pending = nil
    result(nil)
  }

  // Any failure is "lost": the bookmark or the folder is gone.
  func list(_ ref: String, _ result: @escaping FlutterResult) {
    PickedFolders.io.async {
      let answer = PickedFolders.listTree(ref)
      DispatchQueue.main.async {
        if let answer = answer {
          result(answer)
        } else {
          result(FlutterError(code: "lost", message: "No access to the folder", details: nil))
        }
      }
    }
  }

  // Each file in its own folder (the Dart import queue deletes it when
  // done); one that can't be read gets a path with nothing there.
  func copy(_ ref: String, _ keys: [String], _ result: @escaping FlutterResult) {
    PickedFolders.io.async {
      let folder = PickedFolders.resolve(ref)?.url
      let scoped = folder?.startAccessingSecurityScopedResource() ?? false
      defer { if scoped { folder?.stopAccessingSecurityScopedResource() } }
      let paths = keys.map { key -> String in
        let dir = PickedFolders.root.appendingPathComponent(
          String(PickedFolders.count), isDirectory: true)
        PickedFolders.count += 1
        if let folder = folder, let file = copyFile(folder.appendingPathComponent(key), into: dir) {
          return file.path
        }
        let name = (key as NSString).lastPathComponent
        return dir.appendingPathComponent(name.isEmpty ? "book" : name).path
      }
      DispatchQueue.main.async { result(paths) }
    }
  }

  private static var root: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("folders", isDirectory: true)
  }

  private static func bookmark(_ url: URL) -> String? {
    return (try? url.bookmarkData(
      options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil
    ))?.base64EncodedString()
  }

  private static func resolve(_ ref: String) -> (url: URL, stale: Bool)? {
    guard let data = Data(base64Encoded: ref) else { return nil }
    var stale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    else { return nil }
    return (url, stale)
  }

  // Runs on io. Book files of the folder, subfolders included (8 levels,
  // as in Dart); hidden files and folders are skipped. The key is the path
  // inside the folder, which is what copy takes. A stale bookmark comes
  // back renewed as "ref". A file still in iCloud starts downloading and
  // is left for the next scan.
  private static func listTree(_ ref: String) -> [String: Any]? {
    guard let resolved = resolve(ref) else { return nil }
    let folder = resolved.url
    // False for a folder inside the app's own container, which is readable
    // anyway, so the listing below is what tells whether there is access.
    let scoped = folder.startAccessingSecurityScopedResource()
    defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
    let fm = FileManager.default
    guard (try? fm.contentsOfDirectory(atPath: folder.path)) != nil,
      let walker = fm.enumerator(atPath: folder.path)
    else { return nil }
    var files: [[String: Any]] = []
    while let key = walker.nextObject() as? String {
      let name = (key as NSString).lastPathComponent
      let attributes = walker.fileAttributes ?? [:]
      if (attributes[.type] as? FileAttributeType) == .typeDirectory {
        if name.hasPrefix(".") || walker.level > maxDepth { walker.skipDescendants() }
        continue
      }
      if name.hasPrefix(".") {
        // ".Book.fb2.icloud": a file iCloud hasn't downloaded yet.
        if name.hasSuffix(".icloud") {
          let real = String(name.dropFirst().dropLast(".icloud".count))
          if isBookName(real) {
            let dir = folder.appendingPathComponent((key as NSString).deletingLastPathComponent)
            try? fm.startDownloadingUbiquitousItem(at: dir.appendingPathComponent(real))
          }
        }
        continue
      }
      guard isBookName(name) else { continue }
      let file = folder.appendingPathComponent(key)
      let status = (try? file.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
        .ubiquitousItemDownloadingStatus
      if let status = status, status != .current {
        try? fm.startDownloadingUbiquitousItem(at: file)
        continue
      }
      let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
      let date = attributes[.modificationDate] as? Date
      files.append([
        "key": key,
        "name": name,
        "size": size,
        "modified": date.map { Int64(($0.timeIntervalSince1970 * 1000).rounded()) } ?? 0,
      ])
    }
    var answer: [String: Any] = ["files": files]
    if resolved.stale, let renewed = bookmark(folder) { answer["ref"] = renewed }
    return answer
  }

  // As isBookFileName in Dart; the importer tells the format by content.
  private static func isBookName(_ name: String) -> Bool {
    let lower = name.lowercased()
    return [".fb2", ".epub", ".txt", ".zip"].contains {
      lower.hasSuffix($0) && lower.count > $0.count
    }
  }
}

private func fileName(_ url: URL) -> String {
  return url.lastPathComponent.isEmpty ? "book" : url.lastPathComponent
}

// Copies into dir/<file name>; nil when the file can't be read (the
// folder is removed then).
private func copyFile(_ url: URL, into dir: URL) -> URL? {
  let fm = FileManager.default
  let scoped = url.startAccessingSecurityScopedResource()
  defer { if scoped { url.stopAccessingSecurityScopedResource() } }
  do {
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent(fileName(url))
    try fm.copyItem(at: url, to: file)
    return file
  } catch {
    try? fm.removeItem(at: dir)
    return nil
  }
}
