package com.gymrats.gymrats_app

import android.media.AudioManager
import android.media.ToneGenerator
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Answers lib/services/device/device_controls.dart without a plugin: a beep
 * for each counted rep, and keeping the screen on during a battle.
 */
class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gymrats/device")
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
                    else -> result.notImplemented()
                }
            }
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
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
