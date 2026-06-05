package com.example.safe_drive_monitor
// ─────────────────────────────────────────────────────────────────────────────
//  MainActivity.kt
//  Place this file at:
//    android/app/src/main/kotlin/com/example/safe_drive_monitor/MainActivity.kt
//
//  Replace  com.example.safe_drive_monitor  with your actual package name
//  (check android/app/build.gradle → applicationId)
//
//  This handles the MethodChannel 'safe_drive/siren' called from
//  eye_detection_service.dart to play the Android alarm siren.
// ─────────────────────────────────────────────────────────────────────────────

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Channel name must exactly match the one in eye_detection_service.dart
    private val SIREN_CHANNEL = "safe_drive/siren"

    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SIREN_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // ── Play alarm siren ──────────────────────────────────────────
                "play" -> {
                    try {
                        // Stop any currently playing ringtone first
                        ringtone?.stop()

                        // Get the device's default alarm URI
                        // RingtoneManager.TYPE_ALARM → loud ambulance-style siren
                        val alarmUri: Uri = RingtoneManager.getDefaultUri(
                            RingtoneManager.TYPE_ALARM
                        )

                        // Fallback to ringtone if alarm not set
                        val uri = if (alarmUri != null) alarmUri else
                            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

                        ringtone = RingtoneManager.getRingtone(applicationContext, uri)

                        // Set max volume on alarm stream
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            ringtone?.isLooping = true
                            ringtone?.audioAttributes = AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                        }

                        // Set alarm stream volume to max
                        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_ALARM,
                            maxVolume,
                            0
                        )

                        ringtone?.play()
                        result.success("playing")
                    } catch (e: Exception) {
                        result.error("SIREN_ERROR", "Failed to play alarm: ${e.message}", null)
                    }
                }

                // ── Stop alarm siren ──────────────────────────────────────────
                "stop" -> {
                    try {
                        ringtone?.stop()
                        ringtone = null
                        result.success("stopped")
                    } catch (e: Exception) {
                        result.error("SIREN_STOP_ERROR", "Failed to stop alarm: ${e.message}", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        // Always stop siren when app is destroyed
        ringtone?.stop()
        ringtone = null
        super.onDestroy()
    }
}
