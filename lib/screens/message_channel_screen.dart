import 'package:flutter/material.dart';
import '../channels/message_channel_service.dart';

class MessageChannelScreen extends StatefulWidget {
  const MessageChannelScreen({super.key});

  @override
  State<MessageChannelScreen> createState() => _MessageChannelScreenState();
}

class _MessageChannelScreenState extends State<MessageChannelScreen> {
  final _stringService = StringMessageService();
  final _jsonService = JsonMessageService();

  final _textController = TextEditingController(text: 'Hello, native!');

  String _stringReply = '—';
  String _jsonReply = '—';
  bool _loading = false;
  final List<String> _nativeMessages = [];

  @override
  void initState() {
    super.initState();
    // Register listener for native-initiated messages.
    _stringService.startListening((msg) {
      setState(() => _nativeMessages.add(msg));
    });
    _jsonService.startListening((data) {
      setState(() => _nativeMessages.add('JSON from native: $data'));
    });
  }

  @override
  void dispose() {
    _stringService.stopListening();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendString() async {
    setState(() => _loading = true);
    final reply = await _stringService.sendText(_textController.text);
    setState(() {
      _stringReply = reply ?? '(null reply)';
      _loading = false;
    });
  }

  Future<void> _requestConfig() async {
    setState(() => _loading = true);
    final config = await _jsonService.requestConfig();
    setState(() {
      _jsonReply = config?.toString() ?? '(null)';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BasicMessageChannel'),
        backgroundColor: const Color(0xFF6A1B9A),
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
                Text('How BasicMessageChannel works',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
                SizedBox(height: 6),
                Text(
                  'Unlike MethodChannel, BasicMessageChannel has no method '
                  'name concept — you just send a value and optionally get '
                  'one back. Both sides can initiate messages. The codec '
                  'controls how values are serialised.',
                  style: TextStyle(height: 1.5, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Codec comparison table
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Codecs',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 10),
                  _CodecRow(
                      'StringCodec', 'UTF-8 strings', 'Simple text messages'),
                  _CodecRow('JSONMessageCodec', 'JSON → bytes',
                      'Structured data (List, Map)'),
                  _CodecRow('StandardMessageCodec', 'Efficient binary',
                      'Default for Method/EventChannel'),
                  _CodecRow('BinaryCodec', 'Raw ByteData',
                      'Images, audio, custom binary'),
                  _CodecRow(
                      'Custom', 'You define it', 'Protobuf, MessagePack, etc.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // StringCodec example
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Example 1 — StringCodec',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  const _CodeSnippet(
                    code: "const _channel = BasicMessageChannel<String>(\n"
                        "  'com.example.nativechannels/string',\n"
                        "  StringCodec(),\n"
                        ");\n\n"
                        "final reply = await _channel.send(message);",
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Message to send',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: Text('Reply: $_stringReply',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 13))),
                      FilledButton(
                        onPressed: _loading ? null : _sendString,
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // JSONCodec example
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Example 2 — JSONMessageCodec',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  const _CodeSnippet(
                    code: "const _channel = BasicMessageChannel<Object?>(\n"
                        "  'com.example.nativechannels/json',\n"
                        "  JSONMessageCodec(),\n"
                        ");\n\n"
                        "// Sends {'action':'getConfig'}\n"
                        "// Receives config map from native",
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: Text('Config: $_jsonReply',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 13))),
                      FilledButton(
                        onPressed: _loading ? null : _requestConfig,
                        child: const Text('Request'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Incoming native messages
          if (_nativeMessages.isNotEmpty) ...[
            Card(
              elevation: 0,
              color: const Color(0xFFF3E5F5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Messages received from native',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._nativeMessages.map((m) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $m',
                              style: const TextStyle(fontSize: 13)),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Native implementations
          const _NativeExpandable(
            title: 'Android — Kotlin (StringCodec)',
            code: '''// MainActivity.kt
BasicMessageChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "com.example.nativechannels/string",
    StringCodec.INSTANCE
).setMessageHandler { message, reply ->
    Log.d("Channel", "Dart says: \$message")
    // Send reply back to Dart
    reply.reply("Native echoes: \$message")
}

// Native proactively sends to Dart:
val channel = BasicMessageChannel(...)
channel.send("Hello from Android!")''',
          ),
          const SizedBox(height: 8),
          const _NativeExpandable(
            title: 'iOS — Swift (JSONMessageCodec)',
            code: '''// AppDelegate.swift
FlutterBasicMessageChannel(
    name: "com.example.nativechannels/json",
    binaryMessenger: controller.binaryMessenger,
    codec: FlutterJSONMessageCodec.sharedInstance())
  .setMessageHandler { message, reply in
    guard let msg = message as? [String: Any],
          msg["action"] as? String == "getConfig" else {
      reply(nil); return
    }
    // Return config dict to Dart
    reply(["theme": "dark", "version": "2.0"])
}''',
          ),
          const SizedBox(height: 8),
          const _NativeExpandable(
            title: 'Windows — C++ (StringCodec & JSONMessageCodec)',
            code: '''// channel_setup.cpp

// ── StringCodec ──────────────────────────────────────────
// flutter::StringCodec encodes std::string ↔ UTF-8 bytes.
string_channel_ =
  std::make_unique<flutter::BasicMessageChannel<EncodableVal>>(
    messenger,
    "com.example.nativechannels/string",
    &flutter::StringCodec::GetInstance());

string_channel_->SetMessageHandler(
  [](const EncodableVal& msg,
     flutter::MessageReply<EncodableVal> reply) {
    const auto* text = std::get_if<std::string>(&msg);
    reply(EncodableVal("Windows echoes: " +
                       (text ? *text : "(non-string)")));
  });

// Native proactively sends to Dart:
string_channel_->Send(
  EncodableVal(std::string("Hello from Windows!")), nullptr);

// ── JSONMessageCodec ──────────────────────────────────────
// Maps → JSON objects, lists → JSON arrays.
json_channel_ =
  std::make_unique<flutter::BasicMessageChannel<EncodableVal>>(
    messenger,
    "com.example.nativechannels/json",
    &flutter::JsonMessageCodec::GetInstance());

json_channel_->SetMessageHandler(
  [](const EncodableVal& msg,
     flutter::MessageReply<EncodableVal> reply) {
    const auto* map = std::get_if<EncodableMap>(&msg);
    if (!map) { reply(EncodableVal()); return; }

    auto it = map->find(EncodableVal(std::string("action")));
    const auto* action = it != map->end()
        ? std::get_if<std::string>(&it->second) : nullptr;

    if (action && *action == "getConfig") {
      reply(EncodableVal(EncodableMap{
        {EncodableVal("theme"),   EncodableVal(std::string("dark"))},
        {EncodableVal("version"), EncodableVal(std::string("2.0"))},
        {EncodableVal("debug"),   EncodableVal(false)},
      }));
    } else {
      reply(EncodableVal());
    }
  });''',
          ),
        ],
      ),
    );
  }
}

class _CodecRow extends StatelessWidget {
  const _CodecRow(this.name, this.encoding, this.useCase);
  final String name, encoding, useCase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(name,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF6A1B9A),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(encoding,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                Text(useCase,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
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
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white54, size: 18),
                ],
              ),
            ),
          ),
          if (_open)
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
