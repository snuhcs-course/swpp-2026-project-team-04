package com.gymrats.gymrats_app

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// AI-assisted: Cursor, Grok 4.7, 2026-10-16, 송현우
/**
 * Answers lib/services/device/device_controls.dart without a plugin: a beep
 * for each counted rep, keeping the screen on during a battle, the app's
 * private folder for the saved form reports, and gravity plus gyro so the
 * setup can tell a propped, steady phone from one lying down or being held.
 */
class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null
    private var sensorManager: SensorManager? = null
    private var gravitySink: EventChannel.EventSink? = null

    private val motionListener = object : SensorEventListener {
        private var gravity: FloatArray? = null
        private var gyro: FloatArray? = null

        fun reset() {
            gravity = null
            gyro = null
        }

        override fun onSensorChanged(event: SensorEvent) {
            val v = event.values
            if (v.size < 3) return
            val sample = floatArrayOf(v[0], v[1], v[2])
            if (event.sensor.type == Sensor.TYPE_GYROSCOPE) {
                gyro = sample
            } else {
                gravity = sample
            }
            val g = gravity ?: return
            val w = gyro
            // Three numbers until the gyro has reported. Dart treats that as
            // "not still yet", so a missing gyro cannot start a round.
            val payload = if (w == null) {
                listOf(g[0].toDouble(), g[1].toDouble(), g[2].toDouble())
            } else {
                listOf(
                    g[0].toDouble(),
                    g[1].toDouble(),
                    g[2].toDouble(),
                    w[0].toDouble(),
                    w[1].toDouble(),
                    w[2].toDouble(),
                )
            }
            gravitySink?.success(payload)
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "gymrats/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "beep" -> {
                        beep()
                        result.success(null)
                    }
                    "keepScreenOn" -> {
                        val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        if (call.arguments == true) {
                            window.addFlags(flag)
                        } else {
                            window.clearFlags(flag)
                        }
                        result.success(null)
                    }
                    "filesDir" -> result.success(filesDir.absolutePath)
                    else -> result.notImplemented()
                }
            }
        EventChannel(messenger, "gymrats/gravity").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    stopGravity()
                    gravitySink = events
                    motionListener.reset()
                    val manager = getSystemService(SENSOR_SERVICE) as SensorManager
                    sensorManager = manager
                    val gravitySensor = manager.getDefaultSensor(Sensor.TYPE_GRAVITY)
                        ?: manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                    if (gravitySensor == null) {
                        events.error("no_sensor", "No gravity sensor", null)
                        return
                    }
                    val rate = SensorManager.SENSOR_DELAY_GAME
                    manager.registerListener(motionListener, gravitySensor, rate)
                    manager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)?.let { gyro ->
                        manager.registerListener(motionListener, gyro, rate)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    stopGravity()
                }
            },
        )
    }

    private fun stopGravity() {
        sensorManager?.unregisterListener(motionListener)
        motionListener.reset()
        gravitySink = null
    }

    /** A short beep at the media volume. One generator serves the whole app. */
    private fun beep() {
        try {
            val tones = toneGenerator
                ?: ToneGenerator(AudioManager.STREAM_MUSIC, 80).also { toneGenerator = it }
            tones.startTone(ToneGenerator.TONE_PROP_BEEP, 150)
        } catch (e: RuntimeException) {
            // No free audio resources: this rep stays silent but still counts.
        }
    }

    override fun onDestroy() {
        stopGravity()
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
