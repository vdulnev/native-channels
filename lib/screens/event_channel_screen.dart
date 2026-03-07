import 'dart:async';
import 'package:flutter/material.dart';
import '../channels/event_channel_service.dart';

class EventChannelScreen extends StatefulWidget {
  const EventChannelScreen({super.key});

  @override
  State<EventChannelScreen> createState() => _EventChannelScreenState();
}

class _EventChannelScreenState extends State<EventChannelScreen> {
  final _service = EventChannelService();

  // Battery stream
  StreamSubscription<int>? _batterySub;
  int _batteryLevel = -1;
  bool _batteryListening = false;

  // Accelerometer stream
  StreamSubscription<Map<String, double>>? _accelSub;
  Map<String, double> _accel = {'x': 0, 'y': 0, 'z': 0};
  bool _accelListening = false;

  void _toggleBattery() {
    if (_batteryListening) {
      _batterySub?.cancel();
      setState(() {
        _batteryListening = false;
        _batteryLevel = -1;
      });
    } else {
      _batterySub = _service.safeBatteryLevel.listen(
        (level) => setState(() => _batteryLevel = level),
        onError: (e) => debugPrint('Battery error: $e'),
      );
      setState(() => _batteryListening = true);
    }
  }

  void _toggleAccel() {
    if (_accelListening) {
      _accelSub?.cancel();
      setState(() => _accelListening = false);
    } else {
      _accelSub = _service.accelerometer.listen(
        (data) => setState(() => _accel = data),
        onError: (e) => debugPrint('Accel error: $e'),
      );
      setState(() => _accelListening = true);
    }
  }

  @override
  void dispose() {
    _batterySub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EventChannel'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConceptBox(
            color: const Color(0xFFE8F5E9),
            borderColor: const Color(0xFFA5D6A7),
            titleColor: const Color(0xFF2E7D32),
            title: 'How EventChannel works',
            body: 'EventChannel wraps a native StreamHandler. When Dart calls '
                'receiveBroadcastStream().listen(), the native onListen is '
                'triggered. The native side calls eventSink.success(value) to '
                'push each event. When the Dart subscription is cancelled, '
                'native\'s onCancel fires so you can stop the sensor/timer.',
          ),
          const SizedBox(height: 16),

          // ── Battery ──
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Example 1 — Battery level stream',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  _CodeSnippet(
                    code: 'final stream = _channel\n'
                        '    .receiveBroadcastStream()\n'
                        '    .map((e) => e as int);\n\n'
                        'sub = stream.listen((level) {\n'
                        '  setState(() => _batteryLevel = level);\n'
                        '});',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusBadge(
                        active: _batteryListening,
                        label: _batteryLevel >= 0
                            ? 'Battery: $_batteryLevel%'
                            : 'Not listening',
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: _toggleBattery,
                        child: Text(_batteryListening ? 'Stop' : 'Listen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Accelerometer ──
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Example 2 — Accelerometer (Map stream)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  _CodeSnippet(
                    code: 'stream.map((event) {\n'
                        '  final raw = Map<String,dynamic>.from(event);\n'
                        '  return {\n'
                        '    \'x\': (raw[\'x\'] as num).toDouble(),\n'
                        '    \'y\': (raw[\'y\'] as num).toDouble(),\n'
                        '    \'z\': (raw[\'z\'] as num).toDouble(),\n'
                        '  };\n'
                        '});',
                  ),
                  const SizedBox(height: 12),
                  if (_accelListening) ...[
                    _AxisRow('X', _accel['x']!),
                    _AxisRow('Y', _accel['y']!),
                    _AxisRow('Z', _accel['z']!),
                    const SizedBox(height: 8),
                  ] else
                    const Text('Not listening',
                        style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _toggleAccel,
                      child: Text(_accelListening ? 'Stop' : 'Listen'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Native code ──
          _NativeCodeSection(
            windowsCode: '''// channel_setup.cpp
// flutter::StreamHandlerFunctions lets you pass lambdas
// instead of subclassing flutter::StreamHandler.

auto handler = std::make_unique<
    flutter::StreamHandlerFunctions<EncodableVal>>(
  // onListen — Dart subscribed
  [this](const EncodableVal* /*args*/,
         std::unique_ptr<flutter::EventSink<EncodableVal>>&& sink)
      -> std::unique_ptr<flutter::StreamHandlerError<EncodableVal>> {

    auto shared = std::shared_ptr<flutter::EventSink<EncodableVal>>(
        std::move(sink));
    battery_stop_ = false;

    battery_thread_ = std::thread([shared, this]() {
      int level = 85;
      while (!battery_stop_) {
        shared->Success(EncodableVal(level));
        level = (level > 5) ? level - 1 : 100;
        std::this_thread::sleep_for(std::chrono::seconds(1));
      }
    });
    return nullptr;
  },
  // onCancel — Dart unsubscribed
  [this](const EncodableVal* /*args*/)
      -> std::unique_ptr<flutter::StreamHandlerError<EncodableVal>> {
    battery_stop_ = true;
    if (battery_thread_.joinable()) battery_thread_.join();
    return nullptr;
  });

battery_channel_ =
  std::make_unique<flutter::EventChannel<EncodableVal>>(
    messenger,
    "com.example.nativechannels/battery",
    &flutter::StandardMethodCodec::GetInstance());
battery_channel_->SetStreamHandler(std::move(handler));''',
            androidCode: '''// In MainActivity.kt
EventChannel(flutterEngine.dartExecutor.binaryMessenger,
             "com.example.nativechannels/battery")
  .setStreamHandler(object : EventChannel.StreamHandler {

    private var receiver: BroadcastReceiver? = null

    override fun onListen(args: Any?, sink: EventChannel.EventSink) {
      // Start broadcasting battery updates
      receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
          val level = intent.getIntExtra(
            BatteryManager.EXTRA_LEVEL, -1)
          sink.success(level)   // push event to Dart
        }
      }
      context.registerReceiver(
        receiver,
        IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    }

    override fun onCancel(args: Any?) {
      // Dart cancelled — stop updates to save battery
      context.unregisterReceiver(receiver)
      receiver = null
    }
  })''',
            iosCode: '''// In AppDelegate.swift
FlutterEventChannel(
    name: "com.example.nativechannels/battery",
    binaryMessenger: controller.binaryMessenger)
  .setStreamHandler(BatteryStreamHandler())

// BatteryStreamHandler.swift
class BatteryStreamHandler: NSObject, FlutterStreamHandler {
  private var timer: Timer?

  func onListen(withArguments args: Any?,
                eventSink sink: @escaping FlutterEventSink)
                -> FlutterError? {
    UIDevice.current.isBatteryMonitoringEnabled = true
    // Poll every second as a simple demo
    timer = Timer.scheduledTimer(withTimeInterval: 1.0,
                                 repeats: true) { _ in
      let level = Int(UIDevice.current.batteryLevel * 100)
      sink(level)
    }
    return nil
  }

  func onCancel(withArguments args: Any?) -> FlutterError? {
    timer?.invalidate()
    timer = nil
    UIDevice.current.isBatteryMonitoringEnabled = false
    return nil
  }
}''',
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _ConceptBox extends StatelessWidget {
  const _ConceptBox({
    required this.color,
    required this.borderColor,
    required this.titleColor,
    required this.title,
    required this.body,
  });
  final Color color, borderColor, titleColor;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.5, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CodeSnippet extends StatelessWidget {
  const _CodeSnippet({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(code,
          style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFFD4D4D4),
              fontSize: 12,
              height: 1.5)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active, required this.label});
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFE8F5E9)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: active
                ? const Color(0xFF4CAF50)
                : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFF4CAF50) : Colors.grey,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: active
                      ? const Color(0xFF2E7D32)
                      : Colors.black45)),
        ],
      ),
    );
  }
}

class _AxisRow extends StatelessWidget {
  const _AxisRow(this.axis, this.value);
  final String axis;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(axis,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: (value + 10) / 20,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(value.toStringAsFixed(2),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12)),
        ],
      ),
    );
  }
}

class _NativeCodeSection extends StatefulWidget {
  const _NativeCodeSection({
    required this.androidCode,
    required this.iosCode,
    required this.windowsCode,
  });
  final String androidCode, iosCode, windowsCode;

  @override
  State<_NativeCodeSection> createState() => _NativeCodeSectionState();
}

class _NativeCodeSectionState extends State<_NativeCodeSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          TabBar(
            controller: _tab,
            labelColor: const Color(0xFF569CD6),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFF569CD6),
            tabs: const [
              Tab(text: 'Android'),
              Tab(text: 'iOS'),
              Tab(text: 'Windows'),
            ],
          ),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tab,
              children: [
                _CodeTab(widget.androidCode),
                _CodeTab(widget.iosCode),
                _CodeTab(widget.windowsCode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeTab extends StatelessWidget {
  const _CodeTab(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Text(code,
          style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFFD4D4D4),
              fontSize: 12,
              height: 1.6)),
    );
  }
}
