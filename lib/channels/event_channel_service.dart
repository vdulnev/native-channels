// -----------------------------------------------------------------------------
// LESSON 03 — EventChannel
// -----------------------------------------------------------------------------
// EventChannel is designed for one-directional, continuous data streams from
// native to Dart (e.g. sensor readings, location updates, network events).
//
// Key concepts:
//   • receiveBroadcastStream() returns a Dart Stream<dynamic>.
//   • Native side calls EventSink.success(data) to push events.
//   • Native calls EventSink.error(code, message) to push an error.
//   • When the Dart side cancels the stream, native should stop producing data.
//   • The stream is broadcast — multiple listeners can subscribe.
// -----------------------------------------------------------------------------

import 'package:flutter/services.dart';

class EventChannelService {
  static const _batteryChannel =
      EventChannel('com.example.nativechannels/battery');

  static const _sensorChannel =
      EventChannel('com.example.nativechannels/sensor');

  // -------------------------------------------------------------------------
  // Example 1 — Battery level stream (integer 0-100).
  // -------------------------------------------------------------------------
  /// Emits the battery level (0-100) whenever it changes.
  Stream<int> get batteryLevel {
    return _batteryChannel
        .receiveBroadcastStream()
        .map((event) => (event as int));
  }

  // -------------------------------------------------------------------------
  // Example 2 — Accelerometer stream (Map with x, y, z doubles).
  // -------------------------------------------------------------------------
  /// Emits accelerometer readings as Map<String, double> with keys x, y, z.
  Stream<Map<String, double>> get accelerometer {
    return _sensorChannel.receiveBroadcastStream().map((event) {
      final raw = Map<String, dynamic>.from(event as Map);
      return {
        'x': (raw['x'] as num).toDouble(),
        'y': (raw['y'] as num).toDouble(),
        'z': (raw['z'] as num).toDouble(),
      };
    });
  }

  // -------------------------------------------------------------------------
  // Example 3 — Stream with arguments (pass config to native on subscribe).
  // -------------------------------------------------------------------------
  /// Streams GPS coordinates, passing a sampling interval to native.
  Stream<Map<String, double>> locationStream({int intervalMs = 1000}) {
    // Pass arguments to receiveBroadcastStream; native receives them in
    // its onListen callback.
    return const EventChannel('com.example.nativechannels/location')
        .receiveBroadcastStream({'intervalMs': intervalMs}).map((event) {
      final raw = Map<String, dynamic>.from(event as Map);
      return {
        'lat': (raw['lat'] as num).toDouble(),
        'lng': (raw['lng'] as num).toDouble(),
        'accuracy': (raw['accuracy'] as num).toDouble(),
      };
    });
  }

  // -------------------------------------------------------------------------
  // Example 4 — Handling stream errors from native.
  // -------------------------------------------------------------------------
  /// Safe battery stream that handles errors gracefully.
  Stream<int> get safeBatteryLevel {
    return batteryLevel.handleError((error) {
      if (error is PlatformException) {
        // Log and emit a sentinel value instead of crashing.
        // ignore: avoid_print
        print('Battery channel error [${error.code}]: ${error.message}');
      }
    });
  }
}
