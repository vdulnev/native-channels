import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../channels/method_channel_service.dart';

// Top-level entry point for the background isolate demo.
// Must be top-level (not a closure) to work with Isolate.spawn.
void _bgIsolateEntry(List<dynamic> args) async {
  final token = args[0] as RootIsolateToken;
  final sendPort = args[1] as SendPort;

  // Required before any channel call inside a background isolate.
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  const channel = MethodChannel('com.example.nativechannels/method');
  final result = await channel.invokeMethod<String>('heavyWork');
  sendPort.send(result ?? 'no result');
}

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({super.key});

  @override
  State<AdvancedScreen> createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen> {
  final _service = MethodChannelService();

  // ── Example 1: Native background thread ──────────────────────────────────
  String _heavyResult = '—';
  Duration? _heavyDuration;
  bool _heavyLoading = false;

  // ── Example 2: PlatformException error codes ──────────────────────────────
  String _errorResult = '—';
  bool _errorLoading = false;

  // ── Example 3: Dart background isolate ───────────────────────────────────
  String _isolateResult = '—';
  bool _isolateLoading = false;

  Future<void> _runHeavyWork() async {
    setState(() {
      _heavyLoading = true;
      _heavyResult = '—';
      _heavyDuration = null;
    });
    final sw = Stopwatch()..start();
    final result = await _service.heavyWork();
    sw.stop();
    setState(() {
      _heavyResult = result;
      _heavyDuration = sw.elapsed;
      _heavyLoading = false;
    });
  }

  Future<void> _runErrorCodes() async {
    setState(() {
      _errorLoading = true;
      _errorResult = '—';
    });
    try {
      // Intentionally use a filename that doesn't exist to trigger an error.
      await _service.readNativeFile('missing.txt');
      setState(() {
        _errorResult = 'No error (unexpected)';
        _errorLoading = false;
      });
    } on Exception catch (e) {
      setState(() {
        _errorResult = e.toString();
        _errorLoading = false;
      });
    }
  }

  Future<void> _runIsolateDemo() async {
    setState(() {
      _isolateLoading = true;
      _isolateResult = '—';
    });
    final token = RootIsolateToken.instance!;
    final port = ReceivePort();
    await Isolate.spawn(_bgIsolateEntry, [token, port.sendPort]);
    final result = await port.first as String;
    port.close();
    if (mounted) {
      setState(() {
        _isolateResult = 'Isolate result: $result';
        _isolateLoading = false;
      });
    }
  }

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
        children: [
          const _ConceptCard(
            title: 'What this lesson covers',
            body:
                'Three patterns every Flutter developer needs when going beyond '
                'simple channel calls: running heavy work on a native background '
                'thread, handling typed PlatformException error codes, and '
                'calling platform channels from a Dart background isolate '
                '(Flutter 3.7+).',
          ),
          const SizedBox(height: 16),

          // ── Example 1 ──────────────────────────────────────────────────────
          _ExampleCard(
            title: 'Example 1 — Native background thread',
            codeSnippet:
                '// Android: Executors.newSingleThreadExecutor().execute {\n'
                '//   val data = doHeavyWork()   // background\n'
                '//   mainHandler.post { result.success(data) }\n'
                '// }\n'
                '\n'
                'final result = await _channel\n'
                "    .invokeMethod<String>('heavyWork');",
            result: _heavyDuration != null
                ? '$_heavyResult\n(${_heavyDuration!.inMilliseconds} ms)'
                : _heavyResult,
            onRun: _runHeavyWork,
            loading: _heavyLoading,
          ),
          const SizedBox(height: 12),

          // ── Example 2 ──────────────────────────────────────────────────────
          _ExampleCard(
            title: 'Example 2 — PlatformException error codes',
            codeSnippet: "try {\n"
                "  await channel.invokeMethod('readNativeFile',\n"
                "      {'filename': 'missing.txt'});\n"
                "} on PlatformException catch (e) {\n"
                "  print(e.code);     // 'FILE_NOT_FOUND'\n"
                "  print(e.message);  // human-readable\n"
                "}",
            result: _errorResult,
            onRun: _runErrorCodes,
            loading: _errorLoading,
          ),
          const SizedBox(height: 12),

          // ── Example 3 ──────────────────────────────────────────────────────
          _ExampleCard(
            title: 'Example 3 — Background isolate (Flutter 3.7+)',
            codeSnippet: '// Main isolate: capture token before spawning\n'
                'final token = RootIsolateToken.instance!;\n'
                'final port  = ReceivePort();\n'
                'await Isolate.spawn(_bgEntry, [token, port.sendPort]);\n'
                'final result = await port.first;\n'
                '\n'
                '// Inside the isolate:\n'
                'BackgroundIsolateBinaryMessenger\n'
                '    .ensureInitialized(token);\n'
                "const ch = MethodChannel('...method');\n"
                "final r  = await ch.invokeMethod('heavyWork');",
            result: _isolateResult,
            onRun: _runIsolateDemo,
            loading: _isolateLoading,
          ),
          const SizedBox(height: 24),

          // ── Native code reference ──────────────────────────────────────────
          const _NativeCodeCard(
            title: 'Android — Kotlin (background thread pattern)',
            code: '''// In your MethodCallHandler:
"heavyWork" -> {
  executor.execute {
    val data = doHeavyWork()         // runs off main thread
    mainHandler.post {
      result.success(data)           // result MUST be on main thread
    }
  }
}

// Where executor and mainHandler are:
private val executor    = Executors.newSingleThreadExecutor()
private val mainHandler = Handler(Looper.getMainLooper())''',
          ),
          const SizedBox(height: 12),
          const _NativeCodeCard(
            title: 'iOS — Swift (background thread pattern)',
            code: '''// In your setMethodCallHandler:
case "heavyWork":
  DispatchQueue.global(qos: .userInitiated).async {
    let data = self.doHeavyWork()    // runs off main thread
    DispatchQueue.main.async {
      result(data)                   // result MUST be on main thread
    }
  }''',
          ),
          const SizedBox(height: 12),
          const _NativeCodeCard(
            title: 'Android — Kotlin (structured error codes)',
            code: '''when (call.method) {
  "readNativeFile" -> {
    val name = call.argument<String>("filename")
    when {
      name == null ->
        result.error("INVALID_ARGS", "filename is required", null)
      name == "sample.txt" ->
        result.success("Hello from Android!")
      else ->
        result.error("FILE_NOT_FOUND",
                     "No native file: \$name", null)
    }
  }
}

// Dart — catch by code:
// on PlatformException catch (e) {
//   switch (e.code) {
//     case 'FILE_NOT_FOUND': showDialog(...);
//     case 'INVALID_ARGS':   logError(e.details);
//     default:               rethrow;
//   }
// }''',
          ),
          const SizedBox(height: 12),
          const _SummaryCard(),
        ],
      ),
    );
  }
}

// ─── Widgets ───────────────────────────────────────────────────────────────────

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF8A65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFBF360C),
            ),
          ),
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
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  codeSnippet,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFD4D4D4),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    result,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFBF360C),
                  ),
                  onPressed: loading ? null : onRun,
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.code,
                    color: Color(0xFF569CD6),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
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
              child: Text(
                widget.code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFFD4D4D4),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
        ],
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
          Text(
            'Course complete!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You have covered all three platform channel types, their native '
            'Android and iOS implementations, error handling, background '
            'isolates, testing, and performance best practices.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          SizedBox(height: 12),
          Text(
            'Next steps:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
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
