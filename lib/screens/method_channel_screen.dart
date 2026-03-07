import 'package:flutter/material.dart';
import '../channels/method_channel_service.dart';

class MethodChannelScreen extends StatefulWidget {
  const MethodChannelScreen({super.key});

  @override
  State<MethodChannelScreen> createState() => _MethodChannelScreenState();
}

class _MethodChannelScreenState extends State<MethodChannelScreen> {
  final _service = MethodChannelService();

  String _deviceInfo = '—';
  int _sum = 0;
  String _fileContent = '—';
  bool _loading = false;

  Future<void> _runGetDeviceInfo() async {
    setState(() => _loading = true);
    final info = await _service.getDeviceInfo();
    setState(() {
      _deviceInfo = info;
      _loading = false;
    });
  }

  Future<void> _runAddNumbers() async {
    setState(() => _loading = true);
    final sum = await _service.addNumbers(17, 25);
    setState(() {
      _sum = sum;
      _loading = false;
    });
  }

  Future<void> _runReadFile() async {
    setState(() => _loading = true);
    try {
      final content = await _service.readNativeFile('sample.txt');
      setState(() => _fileContent = content);
    } catch (e) {
      setState(() => _fileContent = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MethodChannel'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConceptCard(
            title: 'How MethodChannel works',
            body: 'Dart calls invokeMethod(name, args) → Flutter encodes the '
                'call → native MethodCallHandler receives it → native executes '
                'code → result is returned back to Dart as a Future.',
          ),
          const SizedBox(height: 16),
          _ExampleCard(
            title: 'Example 1 — No arguments, String result',
            codeSnippet: "final info = await _channel\n"
                "    .invokeMethod<String>('getDeviceInfo');",
            result: 'OS: $_deviceInfo',
            onRun: _runGetDeviceInfo,
            loading: _loading,
          ),
          const SizedBox(height: 12),
          _ExampleCard(
            title: 'Example 2 — Map arguments, int result',
            codeSnippet: "final sum = await _channel\n"
                "    .invokeMethod<int>('addNumbers', {'a': 17, 'b': 25});",
            result: 'Sum of 17 + 25 = $_sum',
            onRun: _runAddNumbers,
            loading: _loading,
          ),
          const SizedBox(height: 12),
          _ExampleCard(
            title: 'Example 3 — Error handling (PlatformException)',
            codeSnippet: "try {\n"
                "  await _channel.invokeMethod('readNativeFile', ...);\n"
                "} on PlatformException catch (e) {\n"
                "  print(e.code);  // e.g. 'FILE_NOT_FOUND'\n"
                "}",
            result: _fileContent,
            onRun: _runReadFile,
            loading: _loading,
          ),
          const SizedBox(height: 24),
          _NativeCodeCard(
            title: 'Android — Kotlin',
            code: '''// In MainActivity.kt
MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
              "com.example.nativechannels/method")
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "getDeviceInfo" ->
        result.success("Android \${Build.VERSION.RELEASE}")

      "addNumbers" -> {
        val a = call.argument<Int>("a") ?: 0
        val b = call.argument<Int>("b") ?: 0
        result.success(a + b)
      }

      "readNativeFile" -> {
        val name = call.argument<String>("filename")
        if (name == "sample.txt")
          result.success("Hello from native!")
        else
          result.error("FILE_NOT_FOUND", "No file: \$name", null)
      }

      else -> result.notImplemented()
    }
  }''',
          ),
          const SizedBox(height: 12),
          _NativeCodeCard(
            title: 'iOS — Swift',
            code: '''// In AppDelegate.swift
let channel = FlutterMethodChannel(
    name: "com.example.nativechannels/method",
    binaryMessenger: controller.binaryMessenger)

channel.setMethodCallHandler { call, result in
  switch call.method {
  case "getDeviceInfo":
    result(UIDevice.current.systemVersion)

  case "addNumbers":
    let args = call.arguments as! [String: Int]
    result(args["a"]! + args["b"]!)

  case "readNativeFile":
    let args = call.arguments as! [String: String]
    if args["filename"] == "sample.txt" {
      result("Hello from native!")
    } else {
      result(FlutterError(code: "FILE_NOT_FOUND",
                          message: "No file",
                          details: nil))
    }

  default:
    result(FlutterMethodNotImplemented)
  }
}''',
          ),
          const SizedBox(height: 12),
          _NativeCodeCard(
            title: 'Windows — C++',
            code: '''// channel_setup.cpp
// Arguments / return values use flutter::EncodableValue,
// a std::variant that maps to the StandardMessageCodec types.

method_channel_ =
  std::make_unique<flutter::MethodChannel<EncodableVal>>(
    messenger,
    "com.example.nativechannels/method",
    &flutter::StandardMethodCodec::GetInstance());

method_channel_->SetMethodCallHandler(
  [](const flutter::MethodCall<EncodableVal>& call,
     std::unique_ptr<flutter::MethodResult<EncodableVal>> result) {

    if (call.method_name() == "getDeviceInfo") {
      result->Success(EncodableVal(std::string("Windows 11 build 26100")));

    } else if (call.method_name() == "addNumbers") {
      const auto* args =
        std::get_if<EncodableMap>(call.arguments());
      int a = GetInt(*args, "a");
      int b = GetInt(*args, "b");
      result->Success(EncodableVal(a + b));

    } else if (call.method_name() == "readNativeFile") {
      const auto* args =
        std::get_if<EncodableMap>(call.arguments());
      std::string name = GetString(*args, "filename");
      if (name == "sample.txt")
        result->Success(EncodableVal(
          std::string("Hello from Windows native!")));
      else
        result->Error("FILE_NOT_FOUND",
                      "No native file: " + name);

    } else {
      result->NotImplemented();
    }
  });''',
          ),
        ],
      ),
    );
  }
}

// ─── Shared widget helpers ────────────────────────────────────────────────────

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.5, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.title,
    required this.codeSnippet,
    required this.result,
    required this.onRun,
    required this.loading,
  });

  final String title;
  final String codeSnippet;
  final String result;
  final VoidCallback onRun;
  final bool loading;

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
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(codeSnippet,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFD4D4D4),
                      fontSize: 12)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(result,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13)),
                ),
                FilledButton(
                  onPressed: loading ? null : onRun,
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Run'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeCodeCard extends StatefulWidget {
  const _NativeCodeCard({required this.title, required this.code});
  final String title;
  final String code;

  @override
  State<_NativeCodeCard> createState() => _NativeCodeCardState();
}

class _NativeCodeCardState extends State<_NativeCodeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.code, color: Color(0xFF569CD6), size: 16),
                  const SizedBox(width: 8),
                  Text(widget.title,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(widget.code,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFD4D4D4),
                      fontSize: 12,
                      height: 1.6)),
            ),
        ],
      ),
    );
  }
}
