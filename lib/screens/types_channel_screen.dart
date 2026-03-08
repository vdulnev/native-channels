import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../channels/method_channel_service.dart';

class TypesChannelScreen extends StatefulWidget {
  const TypesChannelScreen({super.key});

  @override
  State<TypesChannelScreen> createState() => _TypesChannelScreenState();
}

class _TypeExample {
  const _TypeExample({
    required this.name,
    required this.dartCode,
    required this.value,
  });

  final String name;
  final String dartCode;
  final Object? value;
}

class _TypesChannelScreenState extends State<TypesChannelScreen> {
  final _service = TypesChannelService();

  late final List<_TypeExample> _examples;
  final _results = <String, Object?>{};
  final _loaded = <String>{};
  final _loading = <String>{};
  bool _runningAll = false;

  @override
  void initState() {
    super.initState();
    _examples = [
      const _TypeExample(name: 'null', dartCode: 'null', value: null),
      const _TypeExample(name: 'bool', dartCode: 'true', value: true),
      const _TypeExample(name: 'int', dartCode: '42', value: 42),
      const _TypeExample(name: 'double', dartCode: '3.14', value: 3.14),
      const _TypeExample(name: 'String', dartCode: "'hello'", value: 'hello'),
      const _TypeExample(
        name: 'List',
        dartCode: "[1, 'two', true]",
        value: [1, 'two', true],
      ),
      const _TypeExample(
        name: 'Map',
        dartCode: "{'key': 'value', 'n': 7}",
        value: {'key': 'value', 'n': 7},
      ),
      _TypeExample(
        name: 'Uint8List',
        dartCode: 'Uint8List([0x41, 0x42, 0x43])',
        value: Uint8List.fromList([0x41, 0x42, 0x43]),
      ),
    ];
  }

  Future<void> _echo(String name, Object? value) async {
    setState(() => _loading.add(name));
    final result = await _service.echoTypes(value);
    if (mounted) {
      setState(() {
        _results[name] = result;
        _loaded.add(name);
        _loading.remove(name);
      });
    }
  }

  Future<void> _echoAll() async {
    setState(() => _runningAll = true);
    for (final ex in _examples) {
      await _echo(ex.name, ex.value);
    }
    if (mounted) setState(() => _runningAll = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Type Echo Demo'),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Concept card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCE93D8)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'StandardMessageCodec type fidelity',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'MethodChannel uses StandardMessageCodec internally. '
                  'It serialises Dart values to binary, native deserialises '
                  'them, then re-serialises on return. This demo sends each '
                  'supported type through echoTypes — native returns it '
                  'unchanged — proving the round-trip is lossless.',
                  style: TextStyle(height: 1.5, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const _CodeSnippet(
            code: "const _channel =\n"
                "    MethodChannel('com.example.nativechannels/types');\n\n"
                "// Native: result.success(call.arguments)\n"
                "final echoed = await _channel\n"
                "    .invokeMethod<Object?>('echoTypes', value);",
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _runningAll ? null : _echoAll,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Echo all types'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Type rows
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                for (int i = 0; i < _examples.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 14),
                  _TypeRow(
                    example: _examples[i],
                    result: _results[_examples[i].name],
                    hasResult: _loaded.contains(_examples[i].name),
                    loading: _loading.contains(_examples[i].name),
                    onEcho: () => _echo(_examples[i].name, _examples[i].value),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Native code
          const _NativeExpandable(
            title: 'Android — Kotlin (echoTypes)',
            code: '''// MainActivity.kt
MethodChannel(
    messenger,
    "com.example.nativechannels/types"
).setMethodCallHandler { call, result ->
    if (call.method == "echoTypes") {
        // Echo every argument back unchanged
        result.success(call.arguments)
    } else {
        result.notImplemented()
    }
}''',
          ),
          const SizedBox(height: 8),
          const _NativeExpandable(
            title: 'iOS — Swift (echoTypes)',
            code: '''// AppDelegate.swift
FlutterMethodChannel(
    name: "com.example.nativechannels/types",
    binaryMessenger: controller.binaryMessenger)
  .setMethodCallHandler { call, result in
    if call.method == "echoTypes" {
        result(call.arguments)   // echo back unchanged
    } else {
        result(FlutterMethodNotImplemented)
    }
}''',
          ),
          const SizedBox(height: 12),

          // Type mapping reference
          const _TypeMappingCard(),
        ],
      ),
    );
  }
}

// ─── Type row ─────────────────────────────────────────────────────────────────

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.example,
    required this.result,
    required this.hasResult,
    required this.loading,
    required this.onEcho,
  });

  final _TypeExample example;
  final Object? result;
  final bool hasResult;
  final bool loading;
  final VoidCallback onEcho;

  String _formatResult(Object? value) {
    if (!hasResult) return '';
    if (value == null) return 'null';
    if (value is Uint8List) {
      final hex = value
          .map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}')
          .join(', ');
      return '[$hex]  (Uint8List)';
    }
    return '$value  (${value.runtimeType})';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              example.name,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF4A148C),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  example.dartCode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                if (hasResult) ...[
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.arrow_forward,
                            size: 12, color: Colors.black38),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatResult(result),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: onEcho,
                  tooltip: 'Echo',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
        ],
      ),
    );
  }
}

// ─── Type mapping reference card ─────────────────────────────────────────────

class _TypeMappingCard extends StatelessWidget {
  const _TypeMappingCard();

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
            const Text(
              'StandardMessageCodec type mapping',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            for (final row in const [
              ('Dart', 'Android (Kotlin)', 'iOS (Swift)'),
              ('null', 'null', 'nil'),
              ('bool', 'Boolean', 'NSNumber(bool)'),
              ('int', 'Int / Long', 'NSNumber(Int)'),
              ('double', 'Double', 'NSNumber(Double)'),
              ('String', 'String', 'String'),
              ('Uint8List', 'ByteArray', 'FlutterStandardTypedData'),
              ('List', 'ArrayList', 'NSArray'),
              ('Map', 'HashMap', 'NSDictionary'),
            ])
              _TypeMapRow(
                dart: row.$1,
                android: row.$2,
                ios: row.$3,
                isHeader: row.$1 == 'Dart',
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeMapRow extends StatelessWidget {
  const _TypeMapRow({
    required this.dart,
    required this.android,
    required this.ios,
    this.isHeader = false,
  });

  final String dart, android, ios;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          )
        : const TextStyle(fontSize: 12, fontFamily: 'monospace');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(dart, style: style)),
          SizedBox(width: 110, child: Text(android, style: style)),
          Expanded(child: Text(ios, style: style)),
        ],
      ),
    );
  }
}

// ─── Shared helper widgets ────────────────────────────────────────────────────

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
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          color: Color(0xFFD4D4D4),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}

class _NativeExpandable extends StatefulWidget {
  const _NativeExpandable({required this.title, required this.code});
  final String title, code;

  @override
  State<_NativeExpandable> createState() => _NativeExpandableState();
}

class _NativeExpandableState extends State<_NativeExpandable> {
  bool _open = false;

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
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.code, color: Color(0xFF569CD6), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
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
