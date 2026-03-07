import UIKit
import Flutter
import CoreMotion

// =============================================================================
// AppDelegate.swift — Native channel implementations for the tutorial course
//
// Channels implemented:
//   1. FlutterMethodChannel  — com.example.nativechannels/method
//   2. FlutterEventChannel   — com.example.nativechannels/battery
//   3. FlutterEventChannel   — com.example.nativechannels/sensor
//   4. FlutterBasicMessageChannel (String) — com.example.nativechannels/string
//   5. FlutterBasicMessageChannel (JSON)   — com.example.nativechannels/json
//   6. FlutterBasicMessageChannel (Binary) — com.example.nativechannels/binary
//   7. FlutterMethodChannel  — com.example.nativechannels/types
// =============================================================================

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    // ── Channel name constants ────────────────────────────────────────────────
    private enum Channel {
        static let method  = "com.example.nativechannels/method"
        static let battery = "com.example.nativechannels/battery"
        static let sensor  = "com.example.nativechannels/sensor"
        static let string  = "com.example.nativechannels/string"
        static let json    = "com.example.nativechannels/json"
        static let binary  = "com.example.nativechannels/binary"
        static let types   = "com.example.nativechannels/types"
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController
                               as? FlutterViewController else {
            fatalError("rootViewController is not FlutterViewController")
        }
        let messenger = controller.binaryMessenger

        setupMethodChannel(messenger)
        setupBatteryEventChannel(messenger)
        setupSensorEventChannel(messenger)
        setupStringMessageChannel(messenger)
        setupJsonMessageChannel(messenger)
        setupBinaryMessageChannel(messenger)
        setupTypesMethodChannel(messenger)

        return super.application(application,
                                 didFinishLaunchingWithOptions: launchOptions)
    }

    // =========================================================================
    // 1. FlutterMethodChannel
    // =========================================================================
    private func setupMethodChannel(_ messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: Channel.method,
                                           binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {

            // ── Example 1: No args, returns String ───────────────────────────
            case "getDeviceInfo":
                let version = UIDevice.current.systemVersion
                let model   = UIDevice.current.model
                result("iOS \(version) — \(model)")

            // ── Example 2: Map args, returns Int ─────────────────────────────
            case "addNumbers":
                guard let args = call.arguments as? [String: Int],
                      let a = args["a"], let b = args["b"] else {
                    result(FlutterError(code: "INVALID_ARGS",
                                       message: "Expected a and b",
                                       details: nil))
                    return
                }
                result(a + b)

            // ── Example 3: Error handling ─────────────────────────────────────
            case "readNativeFile":
                guard let args = call.arguments as? [String: String],
                      let filename = args["filename"] else {
                    result(FlutterError(code: "INVALID_ARGS",
                                       message: "Missing filename", details: nil))
                    return
                }
                if filename == "sample.txt" {
                    result("Hello from iOS native!")
                } else {
                    result(FlutterError(code: "FILE_NOT_FOUND",
                                       message: "No native file: \(filename)",
                                       details: nil))
                }

            // ── Example 4: Heavy work on background thread ────────────────────
            case "heavyWork":
                DispatchQueue.global(qos: .userInitiated).async {
                    Thread.sleep(forTimeInterval: 0.5) // simulate work
                    DispatchQueue.main.async {
                        result("Heavy work done on background thread!")
                    }
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // =========================================================================
    // 2. FlutterEventChannel — Battery level
    // =========================================================================
    private func setupBatteryEventChannel(_ messenger: FlutterBinaryMessenger) {
        FlutterEventChannel(name: Channel.battery,
                            binaryMessenger: messenger)
            .setStreamHandler(BatteryStreamHandler())
    }

    // =========================================================================
    // 3. FlutterEventChannel — Accelerometer
    // =========================================================================
    private func setupSensorEventChannel(_ messenger: FlutterBinaryMessenger) {
        FlutterEventChannel(name: Channel.sensor,
                            binaryMessenger: messenger)
            .setStreamHandler(AccelerometerStreamHandler())
    }

    // =========================================================================
    // 4. FlutterBasicMessageChannel — StringCodec
    // =========================================================================
    private func setupStringMessageChannel(_ messenger: FlutterBinaryMessenger) {
        let channel = FlutterBasicMessageChannel(
            name: Channel.string,
            binaryMessenger: messenger,
            codec: FlutterStringCodec.sharedInstance())

        channel.setMessageHandler { message, reply in
            guard let text = message as? String else { reply(nil); return }
            reply("iOS echoes: \(text)")
        }

        // Native proactively sends a message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            channel.sendMessage("Hello from iOS! (native-initiated)")
        }
    }

    // =========================================================================
    // 5. FlutterBasicMessageChannel — JSONMessageCodec
    // =========================================================================
    private func setupJsonMessageChannel(_ messenger: FlutterBinaryMessenger) {
        let channel = FlutterBasicMessageChannel(
            name: Channel.json,
            binaryMessenger: messenger,
            codec: FlutterJSONMessageCodec.sharedInstance())

        channel.setMessageHandler { message, reply in
            guard let msg = message as? [String: Any],
                  let action = msg["action"] as? String else {
                reply(["error": "invalid message"])
                return
            }
            switch action {
            case "getConfig":
                reply(["theme": "dark",
                       "version": "2.0",
                       "maxRetries": 3,
                       "debug": false] as [String: Any])
            default:
                reply(["error": "unknown action"])
            }
        }
    }

    // =========================================================================
    // 6. FlutterBasicMessageChannel — BinaryCodec
    // =========================================================================
    private func setupBinaryMessageChannel(_ messenger: FlutterBinaryMessenger) {
        let channel = FlutterBasicMessageChannel(
            name: Channel.binary,
            binaryMessenger: messenger,
            codec: FlutterBinaryCodec.sharedInstance())

        channel.setMessageHandler { message, reply in
            guard let data = message as? FlutterStandardTypedData else {
                reply(nil); return
            }
            // Invert each byte as a simple demo
            let bytes = data.data.map { ~$0 }
            reply(FlutterStandardTypedData(bytes: Data(bytes)))
        }
    }

    // =========================================================================
    // 7. FlutterMethodChannel — Type echo demo
    // =========================================================================
    private func setupTypesMethodChannel(_ messenger: FlutterBinaryMessenger) {
        FlutterMethodChannel(name: Channel.types, binaryMessenger: messenger)
            .setMethodCallHandler { call, result in
                if call.method == "echoTypes" {
                    result(call.arguments) // echo back unchanged
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
    }
}

// =============================================================================
// BatteryStreamHandler
// =============================================================================
class BatteryStreamHandler: NSObject, FlutterStreamHandler {
    private var timer: Timer?

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        // Push initial value
        let level = Int(UIDevice.current.batteryLevel * 100)
        events(max(level, 0))

        // Poll every 10 seconds (real app would use UIDevice notifications)
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            let current = Int(UIDevice.current.batteryLevel * 100)
            events(max(current, 0))
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        timer?.invalidate()
        timer = nil
        UIDevice.current.isBatteryMonitoringEnabled = false
        return nil
    }
}

// =============================================================================
// AccelerometerStreamHandler
// =============================================================================
class AccelerometerStreamHandler: NSObject, FlutterStreamHandler {
    private let motionManager = CMMotionManager()

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        guard motionManager.isAccelerometerAvailable else {
            return FlutterError(code: "UNAVAILABLE",
                                message: "Accelerometer not available",
                                details: nil)
        }
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { data, error in
            if let error = error {
                events(FlutterError(code: "SENSOR_ERROR",
                                    message: error.localizedDescription,
                                    details: nil))
                return
            }
            guard let accel = data?.acceleration else { return }
            events(["x": accel.x, "y": accel.y, "z": accel.z])
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        motionManager.stopAccelerometerUpdates()
        return nil
    }
}
