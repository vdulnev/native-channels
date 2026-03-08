import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../channels/message_channel_service.dart';

class BinaryChannelScreen extends StatefulWidget {
  const BinaryChannelScreen({super.key});

  @override
  State<BinaryChannelScreen> createState() => _BinaryChannelScreenState();
}

class _BinaryChannelScreenState extends State<BinaryChannelScreen> {
  final _service = BinaryMessageService();
  final _controller = TextEditingController(text: 'Hello');

  String? _inputHex;
  String? _outputHex;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _toHex(Uint8List bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  Future<void> _send() async {
    final text = _controller.text;
    if (text.isEmpty) return;

    final inputBytes = Uint8List.fromList(text.codeUnits);
    setState(() {
      _loading = true;
      _inputHex = _toHex(inputBytes);
      _outputHex = null;
    });

    final result = await _service.sendBytes(ByteData.view(inputBytes.buffer));

    if (mounted) {
      setState(() {
        if (result != null) {
          final out = result.buffer
              .asUint8List(result.offsetInBytes, result.lengthInBytes);
          _outputHex = _toHex(out);
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BinaryCodec'),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Concept card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF80CBC4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BinaryCodec — raw bytes, zero overhead',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00695C),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'BinaryCodec passes raw ByteData with no encoding. '
                  'Both sides deal with bytes directly — no type mapping, '
                  'no JSON parsing. Use it when you own the binary protocol: '
                  'image buffers, audio frames, protobuf, or custom formats.',
                  style: TextStyle(height: 1.5, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Demo card
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Example — XOR byte inversion',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Dart converts your text to UTF-8 bytes and sends them '
                    'over the channel. Native XORs every byte with 0xFF '
                    'and replies. Both sides see raw ByteData / ByteBuffer.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _CodeSnippet(
                    code: "const _channel = BasicMessageChannel<ByteData?>(\n"
                        "  'com.example.nativechannels/binary',\n"
                        "  BinaryCodec(),\n"
                        ");\n\n"
                        "final bytes = Uint8List.fromList(text.codeUnits);\n"
                        "final reply = await _channel.send(\n"
                        "  ByteData.view(bytes.buffer),\n"
                        ");",
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            labelText: 'Input text',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _loading ? null : _send,
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                  if (_inputHex != null) ...[
                    const SizedBox(height: 14),
                    _HexDisplay(label: 'Input bytes', hex: _inputHex!),
                    const SizedBox(height: 8),
                    if (_loading)
                      const LinearProgressIndicator()
                    else if (_outputHex != null)
                      _HexDisplay(
                        label: 'Output bytes (XOR 0xFF)',
                        hex: _outputHex!,
                        accent: const Color(0xFF2E7D32),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick presets
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick presets',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final p in ['Hi', 'ABC', 'Flutter', '12345'])
                        ActionChip(
                          label: Text(p),
                          onPressed: () => setState(() => _controller.text = p),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Native code
          const _NativeExpandable(
            title: 'Android — Kotlin (BinaryCodec)',
            code: '''// MainActivity.kt
BasicMessageChannel(
    messenger,
    "com.example.nativechannels/binary",
    BinaryCodec.INSTANCE
).setMessageHandler { message, reply ->
    if (message == null) { reply.reply(null); return@setMessageHandler }
    val bytes = ByteArray(message.remaining())
    message.get(bytes)
    // XOR every byte with 0xFF — simple binary transformation demo
    val processed = bytes
        .map { (it.toInt() xor 0xFF).toByte() }
        .toByteArray()
    reply.reply(ByteBuffer.wrap(processed))
}''',
          ),
          const SizedBox(height: 8),
          const _NativeExpandable(
            title: 'iOS — Swift (FlutterBinaryCodec)',
            code: '''// AppDelegate.swift
FlutterBasicMessageChannel(
    name: "com.example.nativechannels/binary",
    binaryMessenger: controller.binaryMessenger,
    codec: FlutterBinaryCodec.sharedInstance())
  .setMessageHandler { message, reply in
    guard let data = message as? Data else {
      reply(nil); return
    }
    var bytes = [UInt8](data)
    bytes = bytes.map { \$0 ^ 0xFF }   // XOR each byte
    reply(Data(bytes))
}''',
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _HexDisplay extends StatelessWidget {
  const _HexDisplay({
    required this.label,
    required this.hex,
    this.accent = const Color(0xFF1565C0),
  });

  final String label, hex;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: accent,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            hex,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF9CDCFE),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
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
                  Text(widget.title,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
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
