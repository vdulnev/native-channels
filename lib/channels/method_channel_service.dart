// -----------------------------------------------------------------------------
// LESSON 02 — MethodChannel
// -----------------------------------------------------------------------------
// MethodChannel is the most common channel type. It lets Dart call a named
// method on the native side and optionally receive a result back.
//
// Key concepts:
//   • One channel name shared between Dart and native (must match exactly).
//   • invokeMethod<T>(name, args) — calls native, returns a Future<T?>.
//   • Native side registers a MethodCallHandler that receives the call and
//     sends back a result (or an error).
//   • Communication is asynchronous and serialised through the platform thread.
// -----------------------------------------------------------------------------

import 'package:flutter/services.dart';

class MethodChannelService {
  // The channel name MUST match what is registered on the native side.
  static const _channel = MethodChannel('com.example.nativechannels/method');

  // -------------------------------------------------------------------------
  // Example 1 — Simple call with no arguments, returns a String.
  // -------------------------------------------------------------------------
  /// Returns the device OS version string from native code.
  Future<String> getDeviceInfo() async {
    // invokeMethod sends the call and waits for the native result.
    final result = await _channel.invokeMethod<String>('getDeviceInfo');
    return result ?? 'Unknown';
  }

  // -------------------------------------------------------------------------
  // Example 2 — Call with a Map argument, returns a Map result.
  // -------------------------------------------------------------------------
  /// Asks native to add two numbers.  Native returns their sum.
  Future<int> addNumbers(int a, int b) async {
    final result = await _channel.invokeMethod<int>(
      'addNumbers',
      {'a': a, 'b': b}, // arguments are encoded as a Map
    );
    return result ?? 0;
  }

  // -------------------------------------------------------------------------
  // Example 3 — Call that can fail; handle PlatformException.
  // -------------------------------------------------------------------------
  /// Reads a file by name from the native app bundle/assets.
  /// Throws a [PlatformException] if the file doesn't exist.
  Future<String> readNativeFile(String filename) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'readNativeFile',
        {'filename': filename},
      );
      return result ?? '';
    } on PlatformException catch (e) {
      // PlatformException carries:
      //   e.code    — a string code set by native (e.g. "FILE_NOT_FOUND")
      //   e.message — human-readable description
      //   e.details — any extra payload (can be null)
      throw Exception('Native error [${e.code}]: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Example 4 — Heavy work on a native background thread.
  // -------------------------------------------------------------------------
  /// Asks native to run expensive work off the main thread and return the result.
  Future<String> heavyWork() async {
    final result = await _channel.invokeMethod<String>('heavyWork');
    return result ?? '';
  }

  // -------------------------------------------------------------------------
  // Example 5 — Native calls back into Dart (reverse MethodChannel).
  // -------------------------------------------------------------------------
  /// Register a handler so native code can invoke Dart methods on this channel.
  void registerDartHandler() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNativeEvent':
          final payload = call.arguments as Map;
          // Return a value back to native by returning from this async function.
          return 'Dart received event: ${payload['type']}';
        default:
          throw MissingPluginException('Unknown method: ${call.method}');
      }
    });
  }
}
