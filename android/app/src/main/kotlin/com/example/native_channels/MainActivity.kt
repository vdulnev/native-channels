package com.example.native_channels

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.BinaryCodec
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.JSONMessageCodec
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StringCodec
import java.nio.ByteBuffer
import java.util.concurrent.Executors

// =============================================================================
// MainActivity.kt — Native channel implementations for the tutorial course
//
// This file wires up every channel that the Dart code references:
//   1. MethodChannel  — com.example.nativechannels/method
//   2. EventChannel   — com.example.nativechannels/battery
//   3. EventChannel   — com.example.nativechannels/sensor
//   4. BasicMessageChannel (String) — com.example.nativechannels/string
//   5. BasicMessageChannel (JSON)   — com.example.nativechannels/json
//   6. BasicMessageChannel (Binary) — com.example.nativechannels/binary
//   7. MethodChannel  — com.example.nativechannels/types  (type echo demo)
// =============================================================================

class MainActivity : FlutterActivity() {

    // ── Channel name constants ────────────────────────────────────────────────
    companion object {
        const val METHOD_CHANNEL   = "com.example.nativechannels/method"
        const val BATTERY_CHANNEL  = "com.example.nativechannels/battery"
        const val SENSOR_CHANNEL   = "com.example.nativechannels/sensor"
        const val STRING_CHANNEL   = "com.example.nativechannels/string"
        const val JSON_CHANNEL     = "com.example.nativechannels/json"
        const val BINARY_CHANNEL   = "com.example.nativechannels/binary"
        const val TYPES_CHANNEL    = "com.example.nativechannels/types"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // =========================================================================
    // configureFlutterEngine — called once when the engine is ready
    // =========================================================================
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        setupMethodChannel(messenger)
        setupBatteryEventChannel(messenger)
        setupSensorEventChannel(messenger)
        setupStringMessageChannel(messenger)
        setupJsonMessageChannel(messenger)
        setupBinaryMessageChannel(messenger)
        setupTypesMethodChannel(messenger)
    }

    // =========================================================================
    // 1. MethodChannel
    // =========================================================================
    private fun setupMethodChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Example 1: No args, returns a String ─────────────────
                    "getDeviceInfo" -> {
                        val info = "Android ${Build.VERSION.RELEASE} " +
                                   "(API ${Build.VERSION.SDK_INT}) — ${Build.MODEL}"
                        result.success(info)
                    }

                    // ── Example 2: Map args, returns Int ─────────────────────
                    "addNumbers" -> {
                        val a = call.argument<Int>("a") ?: 0
                        val b = call.argument<Int>("b") ?: 0
                        result.success(a + b)
                    }

                    // ── Example 3: Error handling ─────────────────────────────
                    "readNativeFile" -> {
                        val filename = call.argument<String>("filename")
                        when (filename) {
                            "sample.txt" -> result.success("Hello from Android native!")
                            else -> result.error(
                                "FILE_NOT_FOUND",
                                "No native file named: $filename",
                                null
                            )
                        }
                    }

                    // ── Example 4: Heavy work on background thread ────────────
                    "heavyWork" -> {
                        executor.execute {
                            val data = simulateHeavyWork()
                            // Must call result on the main thread
                            mainHandler.post { result.success(data) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun simulateHeavyWork(): String {
        Thread.sleep(500) // simulate work
        return "Heavy work done on background thread!"
    }

    // =========================================================================
    // 2. EventChannel — Battery level
    // =========================================================================
    private fun setupBatteryEventChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        EventChannel(messenger, BATTERY_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                private var batteryReceiver: BroadcastReceiver? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    // Immediately push the current level
                    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val initial = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    events.success(initial)

                    // Register for ongoing changes
                    batteryReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context, intent: Intent) {
                            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
                            val pct = (level * 100 / scale)
                            events.success(pct)
                        }
                    }
                    registerReceiver(batteryReceiver,
                        IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                }

                override fun onCancel(arguments: Any?) {
                    // Dart unsubscribed — release the receiver
                    batteryReceiver?.let { unregisterReceiver(it) }
                    batteryReceiver = null
                }
            })
    }

    // =========================================================================
    // 3. EventChannel — Accelerometer sensor
    // =========================================================================
    private fun setupSensorEventChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val accel = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        EventChannel(messenger, SENSOR_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                private var sensorListener: SensorEventListener? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sensorListener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent) {
                            // Push Map with x, y, z to Dart
                            events.success(mapOf(
                                "x" to event.values[0].toDouble(),
                                "y" to event.values[1].toDouble(),
                                "z" to event.values[2].toDouble()
                            ))
                        }
                        override fun onAccuracyChanged(s: Sensor, accuracy: Int) {}
                    }
                    sensorManager.registerListener(
                        sensorListener, accel,
                        SensorManager.SENSOR_DELAY_NORMAL
                    )
                }

                override fun onCancel(arguments: Any?) {
                    sensorListener?.let { sensorManager.unregisterListener(it) }
                    sensorListener = null
                }
            })
    }

    // =========================================================================
    // 4. BasicMessageChannel — StringCodec
    // =========================================================================
    private fun setupStringMessageChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        val channel = BasicMessageChannel(messenger, STRING_CHANNEL, StringCodec.INSTANCE)

        // Handle messages from Dart
        channel.setMessageHandler { message, reply ->
            val response = "Android echoes: $message"
            reply.reply(response)
        }

        // Example: native proactively sends a message to Dart after 3 seconds
        mainHandler.postDelayed({
            channel.send("Hello from Android! (native-initiated)")
        }, 3000)
    }

    // =========================================================================
    // 5. BasicMessageChannel — JSONMessageCodec
    // =========================================================================
    @Suppress("UNCHECKED_CAST")
    private fun setupJsonMessageChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        val channel = BasicMessageChannel(
            messenger, JSON_CHANNEL, JSONMessageCodec.INSTANCE
        )

        channel.setMessageHandler { message, reply ->
            val msg = message as? Map<String, Any> ?: run {
                reply.reply(mapOf("error" to "invalid message"))
                return@setMessageHandler
            }

            when (msg["action"] as? String) {
                "getConfig" -> reply.reply(mapOf(
                    "theme"      to "dark",
                    "version"    to "2.0",
                    "maxRetries" to 3,
                    "debug"      to false
                ))
                else -> reply.reply(mapOf("error" to "unknown action"))
            }
        }
    }

    // =========================================================================
    // 6. BasicMessageChannel — BinaryCodec
    // =========================================================================
    private fun setupBinaryMessageChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        BasicMessageChannel(messenger, BINARY_CHANNEL, BinaryCodec.INSTANCE)
            .setMessageHandler { message, reply ->
                if (message == null) { reply.reply(null); return@setMessageHandler }
                // Simple demo: invert each byte
                val bytes = ByteArray(message.remaining())
                message.get(bytes)
                val processed = bytes.map { (it.toInt() xor 0xFF).toByte() }.toByteArray()
                reply.reply(ByteBuffer.wrap(processed))
            }
    }

    // =========================================================================
    // 7. MethodChannel — Type echo demo
    // =========================================================================
    private fun setupTypesMethodChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, TYPES_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "echoTypes") {
                    // Echo every argument back unchanged to demonstrate codec fidelity
                    result.success(call.arguments)
                } else {
                    result.notImplemented()
                }
            }
    }
}
