import Flutter
import UIKit
import UniformTypeIdentifiers

// Channel and method names are checked against Dart by test/guards.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let filesChannel = "com.tonyvinsenty.bookapp/files"
  private let screenChannel = "com.tonyvinsenty.bookapp/screen"
  private var bookPicker: BookPicker?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BookFiles") else {
      return
    }
    let picker = BookPicker(registrar: registrar)
    bookPicker = picker
    FlutterMethodChannel(name: filesChannel, binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        switch call.method {
        case "pickBooks": picker.pick(result)
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
    return urls.enumerated().compactMap { (i, url) -> String? in
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      do {
        let dir = root.appendingPathComponent(String(i), isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = url.lastPathComponent.isEmpty ? "book" : url.lastPathComponent
        let file = dir.appendingPathComponent(name)
        try fm.copyItem(at: url, to: file)
        return file.path
      } catch {
        return nil
      }
    }
  }
}
