// -----------------------------------------------------------------------------
// LESSON 04 — BasicMessageChannel
// -----------------------------------------------------------------------------
// BasicMessageChannel gives the most flexibility: both sides can send and
// receive messages, choosing their own MessageCodec.
//
// Built-in codecs:
//   • StandardMessageCodec  — efficient binary encoding (default for
//                             MethodChannel/EventChannel internally).
//   • StringCodec           — plain UTF-8 strings.
//   • JSONMessageCodec      — JSON strings encoded to bytes.
//   • BinaryCodec           — raw ByteData with no encoding.
//
// Use BasicMessageChannel when:
//   • You need a non-standard codec (e.g. protobuf, custom binary).
//   • You want true bidirectional messaging without the method/event model.
//   • You are building a plugin that native can proactively message.
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/services.dart';

// ─── Channel 1: String codec (simple text messages) ──────────────────────────

class StringMessageService {
  static const _channel = BasicMessageChannel<String>(
    'com.example.nativechannels/string',
    StringCodec(),
  );

  /// Send a plain text message to native and receive a text reply.
  Future<String?> sendText(String message) async {
    final reply = await _channel.send(message);
    return reply;
  }

  /// Listen for messages that native proactively sends to Dart.
  void startListening(void Function(String message) onMessage) {
    _channel.setMessageHandler((message) async {
      if (message != null) onMessage(message);
      // Return value is sent back to native as the reply.
      return 'Dart acknowledged: $message';
    });
  }

  void stopListening() => _channel.setMessageHandler(null);
}

// ─── Channel 2: JSON codec (structured data) ─────────────────────────────────

class JsonMessageService {
  // JSONMessageCodec encodes Dart objects → JSON string → UTF-8 bytes.
  static const _channel = BasicMessageChannel<Object?>(
    'com.example.nativechannels/json',
    JSONMessageCodec(),
  );

  /// Send a structured Dart map to native and get a structured reply.
  Future<Map<String, dynamic>?> requestConfig() async {
    final reply = await _channel.send({'action': 'getConfig'});
    if (reply == null) return null;
    return Map<String, dynamic>.from(reply as Map);
  }

  void startListening(void Function(Map<String, dynamic> data) onData) {
    _channel.setMessageHandler((message) async {
      if (message != null) {
        onData(Map<String, dynamic>.from(message as Map));
      }
      return {'status': 'ok'};
    });
  }
}

// ─── Channel 3: Custom codec (demonstrates codec extensibility) ───────────────

/// A simple codec that encodes messages as "key=value" pairs separated by &.
class KeyValueCodec extends MessageCodec<Map<String, String>> {
  // Not const — MessageCodec base class has no const constructor.
  KeyValueCodec();

  @override
  ByteData? encodeMessage(Map<String, String>? message) {
    if (message == null) return null;
    final encoded = message.entries.map((e) => '${e.key}=${e.value}').join('&');
    final bytes = Uint8List.fromList(utf8.encode(encoded));
    return ByteData.view(bytes.buffer);
  }

  @override
  Map<String, String>? decodeMessage(ByteData? message) {
    if (message == null) return null;
    final str = utf8.decode(message.buffer.asUint8List());
    return Map.fromEntries(
      str.split('&').map((pair) {
        final parts = pair.split('=');
        return MapEntry(parts[0], parts.length > 1 ? parts[1] : '');
      }),
    );
  }
}

class KeyValueMessageService {
  // Not const because KeyValueCodec() is not a const constructor.
  static final _channel = BasicMessageChannel<Map<String, String>>(
    'com.example.nativechannels/keyvalue',
    KeyValueCodec(),
  );

  Future<Map<String, String>?> sendKeyValue(Map<String, String> data) {
    return _channel.send(data);
  }
}

// ─── Channel 4: Binary codec (raw bytes) ─────────────────────────────────────

class BinaryMessageService {
  static const _channel = BasicMessageChannel<ByteData?>(
    'com.example.nativechannels/binary',
    BinaryCodec(),
  );

  /// Send raw [ByteData] to native and receive a transformed [ByteData] reply.
  Future<ByteData?> sendBytes(ByteData data) => _channel.send(data);
}

// ─── Windows channel (StandardMessageCodec) ──────────────────────────────────
//
// Windows ships only StandardMessageCodec and StandardMethodCodec.
// StringCodec and JSONMessageCodec are not available on the C++ side.
// This service uses the same StandardMessageCodec on both ends, communicating
// over a Windows-specific channel name ("…/win_message").

class WindowsMessageService {
  // StandardMessageCodec is the default — matches the C++ StandardMessageCodec.
  static const _channel = BasicMessageChannel<Object?>(
    'com.example.nativechannels/win_message',
    StandardMessageCodec(),
  );

  /// Send a plain string; Windows C++ echoes it back.
  Future<String?> sendText(String text) async {
    final reply = await _channel.send(text);
    return reply as String?;
  }

  /// Send an action map; Windows C++ returns a config map.
  Future<Map<String, dynamic>?> requestConfig() async {
    final reply = await _channel.send({'action': 'getConfig'});
    if (reply == null) return null;
    return Map<String, dynamic>.from(reply as Map);
  }

  /// Register a handler so Windows C++ can proactively message Dart.
  void startListening(void Function(String message) onMessage) {
    _channel.setMessageHandler((message) async {
      if (message is String) onMessage(message);
      return 'Dart acknowledged';
    });
  }

  void stopListening() => _channel.setMessageHandler(null);
}
