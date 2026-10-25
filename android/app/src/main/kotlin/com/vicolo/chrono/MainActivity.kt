package com.vicolo.chrono

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val TAG = "ChronoMainActivity"

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.vicolo.chrono/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setShowWhenLocked" -> {
                        applyShowWhenLocked(true)
                        result.success(null)
                    }
                    "clearShowWhenLocked" -> {
                        applyShowWhenLocked(false)
                        result.success(null)
                    }
                    "setTurnScreenOn" -> {
                        applyTurnScreenOn(true)
                        result.success(null)
                    }
                    "clearTurnScreenOn" -> {
                        applyTurnScreenOn(false)
                        result.success(null)
                    }
                    "setKeepScreenOn" -> {
                        applyKeepScreenOn(true)
                        result.success(null)
                    }
                    "clearKeepScreenOn" -> {
                        applyKeepScreenOn(false)
                        result.success(null)
                    }
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    "openFullScreenIntentSettings" -> {
                        openFullScreenIntentSettings()
                        result.success(null)
                    }
                    "getSystemVolume" -> {
                        try {
                            result.success(getSystemVolume())
                        } catch (e: Exception) {
                            Log.e(TAG, "Reading the system alarm volume failed", e)
                            result.error("getSystemVolumeFailed", e.message, null)
                        }
                    }
                    "setSystemVolume" -> {
                        val percent = call.argument<Double>("percent") ?: 100.0
                        try {
                            result.success(setSystemVolume(percent))
                        } catch (e: Exception) {
                            Log.e(TAG, "Setting the system alarm volume to $percent% failed", e)
                            result.error("setSystemVolumeFailed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applyShowWhenLocked(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            if (show) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            }
        }
    }

    private fun applyTurnScreenOn(turnOn: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setTurnScreenOn(turnOn)
        } else {
            if (turnOn) {
                window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            }
        }
    }

    private fun applyKeepScreenOn(keepOn: Boolean) {
        if (keepOn) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    /// Whether the app is allowed to show full screen intents (alarms) over the
    /// lock screen. On Android 14 and above, USE_FULL_SCREEN_INTENT has to be
    /// granted manually for sideloaded apps.
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            return notificationManager.canUseFullScreenIntent()
        }
        // Before Android 14 the permission is granted automatically when declared
        return true
    }

    /// Reads the alarm audio stream: its current value in percent together
    /// with the step range Android has for it. The alarm stream only holds a
    /// handful of steps (7 on most phones, shown as 14% through 100%), and
    /// those steps are the only values the app's volume slider is allowed to
    /// show.
    private fun getSystemVolume(): Map<String, Any> {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val stream = AudioManager.STREAM_ALARM
        val max = am.getStreamMaxVolume(stream)
        // getStreamMinVolume was only made public in Android 9. Older versions
        // report the first step instead, so the slider never shows a 0% the
        // system can't be asked for anyway.
        val min = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            am.getStreamMinVolume(stream)
        } else {
            1
        }
        val percent = if (max <= 0) 100.0 else am.getStreamVolume(stream) * 100.0 / max
        return mapOf("percent" to percent, "min" to min, "max" to max)
    }

    /// Moves the alarm audio stream (the one the alarm and its volume preview
    /// play on, never media/notification) to [percent], snapped to the nearest
    /// step Android has for it, and returns the value Android actually stored.
    private fun setSystemVolume(percent: Double): Double {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val stream = AudioManager.STREAM_ALARM
        val max = am.getStreamMaxVolume(stream)
        if (max <= 0) return 100.0
        // Rounding, not truncating: 20% has to land on 1/7 = 14%, not on 0.
        val target = Math.round(percent / 100.0 * max).toInt().coerceIn(0, max)
        am.setStreamVolume(stream, target, 0)
        val stored = am.getStreamVolume(stream)
        if (stored != target) {
            Log.w(
                TAG,
                "Android kept the alarm volume at $stored instead of $target " +
                    "(volume fixed: ${am.isVolumeFixed})"
            )
        }
        return stored * 100.0 / max
    }

    /// Opens the Android 14+ "full-screen notifications" access page for this
    /// app, or the app notification settings on older versions. Without this
    /// permission, alarms can only appear as heads-up notifications instead of
    /// taking over a locked or sleeping screen.
    private fun openFullScreenIntentSettings() {
        val appNotificationSettings = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Intent(
                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                Uri.parse("package:$packageName")
            )
        } else {
            appNotificationSettings
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            startActivity(appNotificationSettings)
        }
    }
}
