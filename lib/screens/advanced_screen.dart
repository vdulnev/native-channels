import 'package:flutter/material.dart';

class AdvancedScreen extends StatelessWidget {
  const AdvancedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Topics'),
        backgroundColor: const Color(0xFFBF360C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _TopicSection(
            number: '1',
            title: 'Thread safety rules',
            body:
                'Platform channel calls MUST be made from the main (UI) isolate '
                'unless you use BackgroundIsolateBinaryMessenger (Flutter 3.7+).\n\n'
                'On Android, the native MethodCallHandler runs on the platform '
                'thread (main thread). If your work is heavy, dispatch to a '
                'background thread and then call result.success() from the '
                'platform thread:\n',
            code: '''// Android — correct background dispatch
channel.setMethodCallHandler { call, result ->
  if (call.method == "heavyWork") {
    Executors.newSingleThreadExecutor().execute {
      val data = doHeavyWork()  // background
      Handler(Looper.getMainLooper()).post {
        result.success(data)    // back on main thread
      }
    }
  }
}

// iOS — correct background dispatch
channel.setMethodCallHandler { call, result in
  DispatchQueue.global(qos: .userInitiated).async {
    let data = self.doHeavyWork()
    DispatchQueue.main.async {
      result(data)  // back on main thread
    }
  }
}''',
          ),
          SizedBox(height: 16),
          _TopicSection(
            number: '2',
            title: 'Background isolates (Flutter 3.7+)',
            body: 'To call a platform channel from a background Dart isolate, '
                'capture the RootIsolateToken on the main isolate and pass it '
                'to your spawned isolate:',
            code: '''// Step 1: capture token on main isolate
final token = RootIsolateToken.instance!;
final port = ReceivePort();

await Isolate.spawn(_bgEntry, [token, port.sendPort]);

// Step 2: use it inside the background isolate
void _bgEntry(List<dynamic> args) async {
  final token    = args[0] as RootIsolateToken;
  final sendPort = args[1] as SendPort;

  // MUST call this before any channel invoke
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  const channel = MethodChannel('com.example/bg');
  final result  = await channel.invokeMethod<String>('work');
  sendPort.send(result);
}''',
          ),
          SizedBox(height: 16),
          _TopicSection(
            number: '3',
            title: 'Channel selection guide',
            body: 'Choose the right channel for your use-case:',
            code:
                '''┌─────────────────────┬──────────────────────────────────────────┐
│ Channel type        │ Best for                                 │
├─────────────────────┼──────────────────────────────────────────┤
│ MethodChannel       │ Discrete requests: get battery, open     │
│                     │ file picker, call native SDK method       │
├─────────────────────┼──────────────────────────────────────────┤
│ EventChannel        │ Continuous data: sensors, location,      │
│                     │ network status, Bluetooth scan results    │
├─────────────────────┼──────────────────────────────────────────┤
│ BasicMessageChannel │ Two-way chat, custom codecs, native-      │
│                     │ initiated messages, protobuf payloads     │
└─────────────────────┴──────────────────────────────────────────┘''',
          ),
          SizedBox(height: 16),
          _TopicSection(
            number: '4',
            title: 'Error codes — best practice',
            body: 'Always use meaningful error codes in PlatformException so '
                'Dart callers can handle specific failure modes:',
            code: '''// Android — well-structured errors
when (call.method) {
  "connectBluetooth" -> {
    if (!bluetoothEnabled)
      result.error("BT_DISABLED",
                   "Bluetooth is off", null)
    else if (deviceAddress == null)
      result.error("INVALID_ARGS",
                   "Missing deviceAddress", call.arguments)
    else
      result.success(connect(deviceAddress))
  }
}

// Dart — handle specific codes
try {
  await service.connectBluetooth(address);
} on PlatformException catch (e) {
  switch (e.code) {
    case 'BT_DISABLED':
      showEnableBluetoothDialog();
    case 'INVALID_ARGS':
      logError(e.details);
    default:
      rethrow;
  }
}''',
          ),
          SizedBox(height: 16),
          _TopicSection(
            number: '5',
            title: 'Unit testing with mock channels',
            body: 'Never run real platform channels in unit tests. '
                'Use setMockMethodCallHandler to inject fakes:',
            code: '''// test/method_channel_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel =
    MethodChannel('com.example.nativechannels/method');

  setUp(() {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getDeviceInfo': return 'MockOS 99';
        case 'addNumbers':
          final a = call.arguments['a'] as int;
          final b = call.arguments['b'] as int;
          return a + b;
        default: return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('addNumbers sums correctly', () async {
    final svc = MethodChannelService();
    expect(await svc.addNumbers(6, 7), 13);
  });
}''',
          ),
          SizedBox(height: 16),
          _TopicSection(
            number: '6',
            title: 'Performance tips',
            body: '',
            code: '''// 1. Batch multiple values into a single call
//    instead of many small invocations.
final data = await channel.invokeMethod('getBatch', {
  'ids': [1, 2, 3, 4, 5],
});

// 2. Use Uint8List / typed lists for large numeric
//    arrays — they skip per-element boxing overhead.
final pixels = await channel
    .invokeMethod<Uint8List>('captureFrame');

// 3. Avoid channels in tight animation loops.
//    Cache values, use streams, or compute on Dart side.

// 4. For large binary payloads (e.g. video frames),
//    prefer BinaryCodec to skip JSON/standard encoding.
const imageChannel = BasicMessageChannel<ByteData?>(
  'com.example/image',
  BinaryCodec(),
);''',
          ),
          SizedBox(height: 24),
          _SummaryCard(),
        ],
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _TopicSection extends StatelessWidget {
  const _TopicSection({
    required this.number,
    required this.title,
    required this.body,
    required this.code,
  });

  final String number, title, body, code;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBF360C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(number,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(body,
                  style: const TextStyle(
                      color: Colors.black54, height: 1.5, fontSize: 13)),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFD4D4D4),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0553B1), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Course complete!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          SizedBox(height: 8),
          Text(
            'You have covered all three platform channel types, their native '
            'Android and iOS implementations, error handling, background '
            'isolates, testing, and performance best practices.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          SizedBox(height: 12),
          Text('Next steps:',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(
            '• Build a plugin package wrapping a real native SDK\n'
            '• Explore Pigeon for type-safe channel code generation\n'
            '• Look at FFI (dart:ffi) for direct C library calls',
            style: TextStyle(color: Colors.white70, height: 1.7),
          ),
        ],
      ),
    );
  }
}
