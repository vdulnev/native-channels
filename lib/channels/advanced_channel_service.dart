// -----------------------------------------------------------------------------
// LESSON 05 — Advanced Topics
// -----------------------------------------------------------------------------
// This file covers:
//   1. Supported data types across the StandardMessageCodec.
//   2. Running channel calls on a background isolate (Flutter 3.7+).
//   3. Mocking channels in tests.
//   4. Thread safety rules on the native side.
//   5. Binary data transfer (ByteData / BinaryCodec).
// -----------------------------------------------------------------------------

import 'dart:typed_data';
import 'package:flutter/services.dart';

// ─── 1. Supported StandardMessageCodec types ─────────────────────────────────
//
// The following Dart ↔ native type mappings are supported out of the box:
//
//  Dart type         │ Android (Kotlin)    │ iOS (Swift)
//  ──────────────────┼─────────────────────┼──────────────────
//  null              │ null                │ nil
//  bool              │ Boolean             │ Bool
//  int               │ Int / Long          │ Int
//  double            │ Double              │ Double
//  String            │ String              │ String
//  Uint8List         │ ByteArray           │ FlutterStandardTypedData
//  Int32List         │ IntArray            │ FlutterStandardTypedData
//  Int64List         │ LongArray           │ FlutterStandardTypedData
//  Float32List       │ FloatArray          │ FlutterStandardTypedData
//  Float64List       │ DoubleArray         │ FlutterStandardTypedData
//  List<T>           │ ArrayList           │ [Any]
//  Map<K, V>         │ HashMap             │ [AnyHashable: Any]
//
// Any other type must be serialised manually before sending.

class DataTypesDemo {
  static const _channel = MethodChannel('com.example.nativechannels/types');

  /// Sends every supported type to native and echoes them back.
  Future<Map<String, dynamic>> echoAllTypes() async {
    final result = await _channel.invokeMethod<Map>('echoTypes', {
      'nullValue': null,
      'boolValue': true,
      'intValue': 42,
      'doubleValue': 3.14,
      'stringValue': 'hello',
      'uint8list': Uint8List.fromList([1, 2, 3, 255]),
      'int32list': Int32List.fromList([-1, 0, 1]),
      'float64list': Float64List.fromList([1.1, 2.2, 3.3]),
      'listValue': [1, 'two', true],
      'mapValue': {'key': 'value', 'number': 7},
    });
    return Map<String, dynamic>.from(result ?? {});
  }
}

// ─── 2. Background isolate channel proxy (Flutter 3.7+) ─────────────────────
//
// By default, platform channels must be called from the main isolate.
// Flutter 3.7 introduced RootIsolateToken + BackgroundIsolateBinaryMessenger
// to allow channel calls from background isolates.

class BackgroundChannelExample {
  static const _channel =
      MethodChannel('com.example.nativechannels/background');

  /// Call this once from the main isolate to grab the token, then pass the
  /// token + method channel name to your background isolate.
  static RootIsolateToken getRootToken() {
    return RootIsolateToken.instance!;
  }

  /// Inside a background isolate:
  ///
  /// ```dart
  /// void backgroundEntry(List<dynamic> args) async {
  ///   final token = args[0] as RootIsolateToken;
  ///   BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  ///
  ///   const channel = MethodChannel('com.example.nativechannels/background');
  ///   final result = await channel.invokeMethod<String>('heavyWork');
  ///   // Send result back via SendPort...
  /// }
  /// ```
  ///
  /// This docstring serves as the lesson example; see the comment above.
  Future<String?> invokeFromMain() =>
      _channel.invokeMethod<String>('heavyWork');
}

// ─── 3. Binary data with BinaryCodec ─────────────────────────────────────────
//
// BinaryCodec sends raw bytes without any encoding overhead.
// Useful for images, audio chunks, or custom binary protocols.

class BinaryChannelService {
  static const _channel = BasicMessageChannel<ByteData?>(
    'com.example.nativechannels/binary',
    BinaryCodec(),
  );

  /// Upload raw bytes to native and receive processed bytes back.
  Future<ByteData?> processBytes(ByteData data) {
    return _channel.send(data);
  }

  /// Helper: convert a Uint8List to ByteData without copying.
  static ByteData fromUint8List(Uint8List list) =>
      list.buffer.asByteData(list.offsetInBytes, list.lengthInBytes);
}

// ─── 4. Testing — mock a MethodChannel ───────────────────────────────────────
//
// In widget/unit tests, set a mock handler on the default binary messenger
// so you do NOT need a running native host:
//
// ```dart
// import 'package:flutter/services.dart';
// import 'package:flutter_test/flutter_test.dart';
//
// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();
//
//   setUp(() {
//     // Install a mock handler before each test.
//     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
//         .setMockMethodCallHandler(
//       const MethodChannel('com.example.nativechannels/method'),
//       (call) async {
//         if (call.method == 'getDeviceInfo') return 'MockOS 1.0';
//         if (call.method == 'addNumbers') {
//           final args = call.arguments as Map;
//           return (args['a'] as int) + (args['b'] as int);
//         }
//         return null;
//       },
//     );
//   });
//
//   tearDown(() {
//     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
//         .setMockMethodCallHandler(
//       const MethodChannel('com.example.nativechannels/method'),
//       null, // remove mock
//     );
//   });
//
//   test('addNumbers returns correct sum', () async {
//     final service = MethodChannelService();
//     expect(await service.addNumbers(3, 4), 7);
//   });
// }
// ```
