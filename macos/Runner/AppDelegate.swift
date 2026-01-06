import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Set up method channel for iCloud access
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    let icloudChannel = FlutterMethodChannel(name: "com.execute.icloud",
                                              binaryMessenger: controller.engine.binaryMessenger)
    icloudChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getICloudPath" {
        if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
          result(url.path)
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }
}
