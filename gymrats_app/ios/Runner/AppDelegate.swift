import AudioToolbox
import CoreMotion
import Flutter
import UIKit

/// iOS side of lib/services/device/device_controls.dart and phone_tilt.dart,
/// matching MainActivity.kt: a rep beep, keeping the screen on, the app's
/// private folder, and gravity plus gyro for the phone placement check.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let motion = CMMotionManager()
  private var gravitySink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GymratsDevice")
    else { return }
    let messenger = registrar.messenger()

    FlutterMethodChannel(name: "gymrats/device", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "beep":
          AudioServicesPlaySystemSound(1057)
          result(nil)
        case "keepScreenOn":
          UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) == true
          result(nil)
        case "filesDir":
          let dir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
          ).first!
          try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
          result(dir.path)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    FlutterEventChannel(name: "gymrats/gravity", binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  /// Sends Android's numbers: gravity in m/s^2 pointing like TYPE_GRAVITY
  /// (screen up, flat = +z), then the gyro in rad/s.
  fileprivate func startGravity(_ sink: @escaping FlutterEventSink) -> FlutterError? {
    stopGravity()
    guard motion.isDeviceMotionAvailable else {
      return FlutterError(code: "no_sensor", message: "No gravity sensor", details: nil)
    }
    gravitySink = sink
    motion.deviceMotionUpdateInterval = 1.0 / 50.0
    motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
      guard let self = self, let data = data, let sink = self.gravitySink else { return }
      let g = data.gravity
      let w = data.rotationRate
      let scale = -9.81
      sink([g.x * scale, g.y * scale, g.z * scale, w.x, w.y, w.z])
    }
    return nil
  }

  fileprivate func stopGravity() {
    motion.stopDeviceMotionUpdates()
    gravitySink = nil
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    return startGravity(events)
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopGravity()
    return nil
  }
}
