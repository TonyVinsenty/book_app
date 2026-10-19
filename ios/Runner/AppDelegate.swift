import Flutter
import UIKit
import UniformTypeIdentifiers

// Channel and method names are checked against Dart by test/guards.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let filesChannel = "com.tonyvinsenty.bookapp/files"
  private let screenChannel = "com.tonyvinsenty.bookapp/screen"
  private var bookPicker: BookPicker?
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
