import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up method channel for iCloud access
    let controller = window?.rootViewController as! FlutterViewController
    let icloudChannel = FlutterMethodChannel(name: "com.execute.icloud",
                                              binaryMessenger: controller.binaryMessenger)
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
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
