# Flutter Native Channels — Tutorial Course

A hands-on course covering all three Flutter platform channel types with full
Dart, Android (Kotlin), iOS (Swift), and Windows (C++) implementations.

---

## Course outline

| Lesson | Topic | Channel type |
|--------|-------|--------------|
| 01 | Call native methods on demand | `MethodChannel` |
| 02 | Stream continuous native data | `EventChannel` |
| 03 | Two-way messaging with codecs | `BasicMessageChannel` |
| 04 | Advanced: threads, testing, perf | — |

---

## Project structure

```
native-channels/
├── pubspec.yaml
├── lib/
│   ├── main.dart                          # App entry point
│   ├── screens/
│   │   ├── home_screen.dart               # Course menu
│   │   ├── method_channel_screen.dart     # Lesson 01
│   │   ├── event_channel_screen.dart      # Lesson 02
│   │   ├── message_channel_screen.dart    # Lesson 03
│   │   └── advanced_screen.dart          # Lesson 04
│   └── channels/
│       ├── method_channel_service.dart    # Dart MethodChannel API
│       ├── event_channel_service.dart     # Dart EventChannel API
│       ├── message_channel_service.dart   # Dart BasicMessageChannel API
│       └── advanced_channel_service.dart  # Types, isolates, testing
├── android/app/src/main/kotlin/…/
│   └── MainActivity.kt                    # All Android channel handlers
└── ios/Runner/
    └── AppDelegate.swift                  # All iOS channel handlers
```

---

## Lesson 01 — MethodChannel

**Use when:** you need a one-shot request/response — like an RPC call.

### Dart side

```dart
// Declare the channel (name MUST match native)
static const _channel = MethodChannel('com.example.nativechannels/method');

// No arguments, typed return
final String info = await _channel.invokeMethod<String>('getDeviceInfo') ?? '';

// With arguments (Map)
final int sum = await _channel.invokeMethod<int>(
  'addNumbers',
  {'a': 17, 'b': 25},
) ?? 0;

// Error handling
try {
  await _channel.invokeMethod('readNativeFile', {'filename': 'missing.txt'});
} on PlatformException catch (e) {
  print('${e.code}: ${e.message}');  // FILE_NOT_FOUND: No file: missing.txt
}
```

### Android (Kotlin)

```kotlin
MethodChannel(messenger, "com.example.nativechannels/method")
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "getDeviceInfo" -> result.success("Android ${Build.VERSION.RELEASE}")
      "addNumbers"    -> result.success(
          call.argument<Int>("a")!! + call.argument<Int>("b")!!)
      "readNativeFile" -> result.error("FILE_NOT_FOUND", "…", null)
      else -> result.notImplemented()
    }
  }
```

### iOS (Swift)

```swift
FlutterMethodChannel(name: "com.example.nativechannels/method",
                     binaryMessenger: messenger)
  .setMethodCallHandler { call, result in
    switch call.method {
    case "getDeviceInfo": result(UIDevice.current.systemVersion)
    case "addNumbers":
      let args = call.arguments as! [String: Int]
      result(args["a"]! + args["b"]!)
    default: result(FlutterMethodNotImplemented)
    }
  }
```

---

## Lesson 02 — EventChannel

**Use when:** native needs to push data continuously (sensors, battery,
location, network status, Bluetooth scan results).

### Dart side

```dart
static const _channel = EventChannel('com.example.nativechannels/battery');

// Returns a broadcast Stream — subscribe with .listen()
Stream<int> get batteryLevel =>
    _channel.receiveBroadcastStream().map((e) => e as int);

// Always cancel the subscription when done
late StreamSubscription<int> _sub;

_sub = batteryLevel.listen((level) {
  setState(() => _batteryLevel = level);
});

@override
void dispose() {
  _sub.cancel();   // triggers native onCancel
  super.dispose();
}
```

### Android (Kotlin)

```kotlin
EventChannel(messenger, "com.example.nativechannels/battery")
  .setStreamHandler(object : EventChannel.StreamHandler {

    private var receiver: BroadcastReceiver? = null

    override fun onListen(args: Any?, sink: EventChannel.EventSink) {
      receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
          val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
          sink.success(level)
        }
      }
      registerReceiver(receiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    }

    override fun onCancel(args: Any?) {
      unregisterReceiver(receiver)
      receiver = null
    }
  })
```

### iOS (Swift)

```swift
class BatteryStreamHandler: NSObject, FlutterStreamHandler {
  private var timer: Timer?

  func onListen(withArguments _: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    UIDevice.current.isBatteryMonitoringEnabled = true
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      events(Int(UIDevice.current.batteryLevel * 100))
    }
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    timer?.invalidate(); timer = nil
    return nil
  }
}
```

---

## Lesson 03 — BasicMessageChannel

**Use when:** you need true bidirectional messaging, a non-standard codec,
or native code needs to initiate messages to Dart.

### Built-in codecs

| Codec | Dart type | Use case |
|-------|-----------|----------|
| `StringCodec` | `String` | Simple text |
| `JSONMessageCodec` | `Object?` | Structured data |
| `StandardMessageCodec` | `Object?` | Default (efficient binary) |
| `BinaryCodec` | `ByteData?` | Raw bytes (images, audio) |
| Custom | Any | Protobuf, MessagePack, etc. |

### Dart side (StringCodec)

```dart
const _channel = BasicMessageChannel<String>(
  'com.example.nativechannels/string',
  StringCodec(),
);

// Dart → Native
final reply = await _channel.send('Hello, native!');

// Native → Dart
_channel.setMessageHandler((message) async {
  print('From native: $message');
  return 'Dart acknowledged';
});
```

### Android (Kotlin)

```kotlin
val channel = BasicMessageChannel(messenger, "…/string", StringCodec.INSTANCE)
channel.setMessageHandler { msg, reply -> reply.reply("iOS echoes: $msg") }
// Native initiates:
channel.send("Hello from Android!")
```

### iOS (Swift)

```swift
let channel = FlutterBasicMessageChannel(
    name: "…/string",
    binaryMessenger: messenger,
    codec: FlutterStringCodec.sharedInstance())
channel.setMessageHandler { msg, reply in reply("iOS echoes: \(msg!)") }
// Native initiates:
channel.sendMessage("Hello from iOS!")
```

---

## Lesson 04 — Advanced Topics

### Thread safety

- Platform channel calls must be made on the **main isolate** (Dart).
- Native handlers run on the **platform thread** — dispatch heavy work to a
  background thread, then call `result.success()` back on the main thread.

```kotlin
// Android — correct background dispatch
executor.execute {
  val data = doHeavyWork()
  Handler(Looper.getMainLooper()).post { result.success(data) }
}
```

### Background isolates (Flutter 3.7+)

```dart
// Main isolate
final token = RootIsolateToken.instance!;
await Isolate.spawn(_bgEntry, [token, port.sendPort]);

// Background isolate
void _bgEntry(List args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args[0]);
  final result = await MethodChannel('…').invokeMethod<String>('work');
}
```

### Mocking in tests

```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(const MethodChannel('…'), (call) async {
  if (call.method == 'addNumbers') {
    return call.arguments['a'] + call.arguments['b'];
  }
  return null;
});
```

### Supported StandardMessageCodec types

| Dart | Android | iOS |
|------|---------|-----|
| `null` | `null` | `nil` |
| `bool` | `Boolean` | `Bool` |
| `int` | `Int`/`Long` | `Int` |
| `double` | `Double` | `Double` |
| `String` | `String` | `String` |
| `Uint8List` | `ByteArray` | `FlutterStandardTypedData` |
| `List<T>` | `ArrayList` | `[Any]` |
| `Map<K,V>` | `HashMap` | `[AnyHashable: Any]` |

---

## Windows — C++ channel implementation

Windows channels use the same channel names as Android and iOS.
Arguments and return values use `flutter::EncodableValue` — a `std::variant`
that maps directly to the `StandardMessageCodec` type table.

### Project structure (Windows)

```
windows/runner/
├── channel_setup.h       ← ChannelManager class declaration
├── channel_setup.cpp     ← All channel handler implementations
├── flutter_window.h      ← Owns a ChannelManager member
└── flutter_window.cpp    ← Calls SetupChannels() in OnCreate()
```

### MethodChannel (C++)

```cpp
// flutter::StandardMethodCodec is the default codec — same as Android/iOS.
method_channel_ = std::make_unique<flutter::MethodChannel<EncodableVal>>(
    messenger,
    "com.example.nativechannels/method",
    &flutter::StandardMethodCodec::GetInstance());

method_channel_->SetMethodCallHandler(
    [](const flutter::MethodCall<EncodableVal>& call,
       std::unique_ptr<flutter::MethodResult<EncodableVal>> result) {

      if (call.method_name() == "getDeviceInfo") {
        result->Success(EncodableVal(std::string("Windows 11 build 26100")));

      } else if (call.method_name() == "addNumbers") {
        const auto* args = std::get_if<EncodableMap>(call.arguments());
        int a = std::get<int>(args->at(EncodableVal("a")));
        int b = std::get<int>(args->at(EncodableVal("b")));
        result->Success(EncodableVal(a + b));

      } else {
        result->NotImplemented();
      }
    });
```

### EventChannel (C++)

```cpp
// StreamHandlerFunctions wraps two lambdas: onListen and onCancel.
auto handler = std::make_unique<
    flutter::StreamHandlerFunctions<EncodableVal>>(
    // onListen
    [](const EncodableVal*, std::unique_ptr<flutter::EventSink<EncodableVal>>&& sink)
        -> std::unique_ptr<flutter::StreamHandlerError<EncodableVal>> {
      auto shared = std::shared_ptr<flutter::EventSink<EncodableVal>>(
          std::move(sink));
      std::thread([shared]() {
        for (int i = 100; i >= 0; --i) {
          shared->Success(EncodableVal(i));
          std::this_thread::sleep_for(std::chrono::seconds(1));
        }
        shared->EndOfStream();
      }).detach();
      return nullptr;
    },
    // onCancel
    [](const EncodableVal*)
        -> std::unique_ptr<flutter::StreamHandlerError<EncodableVal>> {
      return nullptr;  // stop the thread via a flag in practice
    });

battery_channel_ = std::make_unique<flutter::EventChannel<EncodableVal>>(
    messenger, "com.example.nativechannels/battery",
    &flutter::StandardMethodCodec::GetInstance());
battery_channel_->SetStreamHandler(std::move(handler));
```

### BasicMessageChannel (C++)

```cpp
// StringCodec — UTF-8 text
string_channel_ = std::make_unique<flutter::BasicMessageChannel<EncodableVal>>(
    messenger, "com.example.nativechannels/string",
    &flutter::StringCodec::GetInstance());

string_channel_->SetMessageHandler(
    [](const EncodableVal& msg, flutter::MessageReply<EncodableVal> reply) {
      const auto* text = std::get_if<std::string>(&msg);
      reply(EncodableVal("Windows echoes: " + (text ? *text : "")));
    });

// Native → Dart (proactive send)
string_channel_->Send(EncodableVal(std::string("Hello from Windows!")), nullptr);
```

### EncodableValue type mapping

| Dart type   | C++ type in `EncodableValue`        |
|-------------|-------------------------------------|
| `null`      | `std::monostate`                    |
| `bool`      | `bool`                              |
| `int`       | `int` / `int64_t`                   |
| `double`    | `double`                            |
| `String`    | `std::string`                       |
| `Uint8List` | `std::vector<uint8_t>`              |
| `List<T>`   | `flutter::EncodableList`            |
| `Map<K,V>`  | `flutter::EncodableMap`             |

---

## Running the app

```bash
# Get dependencies
flutter pub get

# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios

# Windows
flutter run -d windows

# Run tests
flutter test
```

> Tip: Run on a real device to see sensor and battery channels produce live data.
> Windows battery channel uses a simulated countdown; replace with
> `IDeviceInformation` / Win32 Power APIs for production use.

---

## Next steps

- **Pigeon** — generate type-safe channel boilerplate from a Dart interface
  definition: `flutter pub add pigeon --dev`
- **dart:ffi** — call C/C++ libraries directly without a channel
- **Platform Views** — embed native UI widgets inside Flutter
