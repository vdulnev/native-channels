import Cocoa
import FlutterMacOS

// =============================================================================
// MainFlutterWindow.swift — Native channel implementations for the tutorial
//
// Channels implemented:
//   1. FlutterMethodChannel  — com.example.nativechannels/method
//   2. FlutterEventChannel   — com.example.nativechannels/battery
//   3. FlutterEventChannel   — com.example.nativechannels/sensor
//   4. FlutterBasicMessageChannel (String) — com.example.nativechannels/string
//   5. FlutterBasicMessageChannel (JSON)   — com.example.nativechannels/json
//   6. FlutterBasicMessageChannel (Binary) — com.example.nativechannels/binary
//   7. FlutterMethodChannel  — com.example.nativechannels/types
//
// macOS differences vs iOS:
//   • Imports FlutterMacOS instead of Flutter
//   • Uses ProcessInfo / Host for device info (no UIDevice)
//   • No hardware accelerometer — simulates axis data with a timer
//   • Battery level read via IOKit power source APIs
//   • Channel setup lives here (FlutterViewController is created here)
// =============================================================================

// ── Channel name constants ────────────────────────────────────────────────────
private enum Channel {
    static let method  = "com.example.nativechannels/method"
    static let battery = "com.example.nativechannels/battery"
    static let sensor  = "com.example.nativechannels/sensor"
    static let string  = "com.example.nativechannels/string"
    static let json    = "com.example.nativechannels/json"
    static let binary  = "com.example.nativechannels/binary"
    static let types   = "com.example.nativechannels/types"
}

// =============================================================================
// Window — entry point
// =============================================================================
class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        let messenger = flutterViewController.engine.binaryMessenger
        setupMethodChannel(messenger)
        setupBatteryEventChannel(messenger)
        setupSensorEventChannel(messenger)
        setupStringMessageChannel(messenger)
        setupJsonMessageChannel(messenger)
        setupBinaryMessageChannel(messenger)
        setupTypesMethodChannel(messenger)

        super.awakeFromNib()
    }
}

// =============================================================================
// 1. FlutterMethodChannel
// =============================================================================
private func setupMethodChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Channel.method,
                                       binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
        switch call.method {

        // ── Example 1: No args, returns String ───────────────────────────────
        case "getDeviceInfo":
            let version  = ProcessInfo.processInfo.operatingSystemVersionString
            let hostname = Host.current().localizedName ?? "Mac"
            result("macOS \(version) — \(hostname)")

        // ── Example 2: Map args, returns Int ─────────────────────────────────
        case "addNumbers":
            guard let args = call.arguments as? [String: Int],
                  let a = args["a"], let b = args["b"] else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Expected a and b",
                                   details: nil))
                return
            }
            result(a + b)

        // ── Example 3: Error handling ─────────────────────────────────────────
        case "readNativeFile":
            guard let args = call.arguments as? [String: String],
                  let filename = args["filename"] else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "Missing filename", details: nil))
                return
            }
            if filename == "sample.txt" {
                result("Hello from macOS native!")
            } else {
                result(FlutterError(code: "FILE_NOT_FOUND",
                                   message: "No native file: \(filename)",
                                   details: nil))
            }

        // ── Example 4: Heavy work on background thread ────────────────────────
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

// =============================================================================
// 2. FlutterEventChannel — Battery level (via IOKit power sources)
// =============================================================================
private func setupBatteryEventChannel(_ messenger: FlutterBinaryMessenger) {
    FlutterEventChannel(name: Channel.battery, binaryMessenger: messenger)
        .setStreamHandler(MacBatteryStreamHandler())
}

// =============================================================================
// 3. FlutterEventChannel — Simulated sensor data
//    macOS has no built-in accelerometer; we emit synthetic sinusoidal values
//    to demonstrate the EventChannel streaming API without hardware dependency.
// =============================================================================
private func setupSensorEventChannel(_ messenger: FlutterBinaryMessenger) {
    FlutterEventChannel(name: Channel.sensor, binaryMessenger: messenger)
        .setStreamHandler(SimulatedSensorStreamHandler())
}

// =============================================================================
// 4. FlutterBasicMessageChannel — StringCodec
// =============================================================================
private func setupStringMessageChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterBasicMessageChannel(
        name: Channel.string,
        binaryMessenger: messenger,
        codec: FlutterStringCodec.sharedInstance())

    channel.setMessageHandler { message, reply in
        guard let text = message as? String else { reply(nil); return }
        reply("macOS echoes: \(text)")
    }

    // Native proactively sends a message after 3 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        channel.sendMessage("Hello from macOS! (native-initiated)")
    }
}

// =============================================================================
// 5. FlutterBasicMessageChannel — JSONMessageCodec
// =============================================================================
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

// =============================================================================
// 6. FlutterBasicMessageChannel — BinaryCodec
// =============================================================================
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

// =============================================================================
// 7. FlutterMethodChannel — Type echo demo
// =============================================================================
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

// =============================================================================
// MacBatteryStreamHandler
// Simulates a draining battery (100 → 0 % over 100 ticks at 10 s intervals).
// Real IOKit access requires a bridging header; this keeps the tutorial focused
// on the EventChannel API itself rather than IOKit C interop.
// =============================================================================
class MacBatteryStreamHandler: NSObject, FlutterStreamHandler {
    private var timer: Timer?
    private var level = 100

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        events(level)
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            if self.level > 0 { self.level -= 1 }
            events(self.level)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        timer?.invalidate()
        timer = nil
        return nil
    }
}

// =============================================================================
// SimulatedSensorStreamHandler
// Emits synthetic x/y/z values on a 100 ms interval using sine waves so the
// EventChannel streaming API can be demonstrated on macOS without hardware.
// =============================================================================
class SimulatedSensorStreamHandler: NSObject, FlutterStreamHandler {
    private var timer: Timer?
    private var tick: Double = 0

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        tick = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.tick += 0.1
            let x = sin(self.tick)
            let y = cos(self.tick * 0.7)
            let z = sin(self.tick * 0.3 + .pi / 4)
            events(["x": x, "y": y, "z": z])
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        timer?.invalidate()
        timer = nil
        return nil
    }
}
