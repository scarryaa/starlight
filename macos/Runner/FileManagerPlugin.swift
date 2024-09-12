import Cocoa
import FlutterMacOS

class FileManagerPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "io.scarryaa.starlight.file_manager", binaryMessenger: registrar.messenger)
    let instance = FileManagerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "listDirectory":
      if let arguments = call.arguments as? [String: Any],
         let path = arguments["path"] as? String {
        listDirectory(path: path, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func listDirectory(path: String, result: @escaping FlutterResult) {
    let fileManager = FileManager.default
    do {
      let contents = try fileManager.contentsOfDirectory(atPath: path)
      var items: [[String: Any]] = []
      for item in contents {
        let fullPath = (path as NSString).appendingPathComponent(item)
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory)
        items.append([
          "name": item,
          "path": fullPath,
          "isDirectory": isDirectory.boolValue
        ])
      }
      result(items)
    } catch {
      result(FlutterError(code: "LIST_DIRECTORY_ERROR", message: error.localizedDescription, details: nil))
    }
  }
}
