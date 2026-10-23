import 'package:clock_app/developer/logic/logger.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel("com.vicolo.chrono/alarm");

/// Shows the app over the lock screen and keeps the screen awake. Called when
/// the alarm notification screen opens, alongside
/// `FlutterShowWhenLocked().show()`, so the alarm can't be missed through
/// heads-up-banner fallbacks and the display doesn't sleep mid-mission.
Future<void> showOverLockScreen() async {
  await _invokeEach([
    "setShowWhenLocked",
    "setTurnScreenOn",
    "setKeepScreenOn",
  ]);
}

/// Clears the wake / show-over-lock-screen flags. Called when the alarm
/// notification screen closes, alongside `FlutterShowWhenLocked().hide()`.
Future<void> hideOverLockScreen() async {
  await _invokeEach([
    "clearShowWhenLocked",
    "clearTurnScreenOn",
    "clearKeepScreenOn",
  ]);
}

/// Whether the app is allowed to show full screen (alarm) notifications over
/// the lock screen. On Android 14 and above, USE_FULL_SCREEN_INTENT has to be
/// granted manually by the user for sideloaded apps.
Future<bool> canUseFullScreenIntent() async {
  try {
    return await _channel.invokeMethod<bool>("canUseFullScreenIntent") ?? true;
  } catch (e) {
    logger.e("Error checking full screen intent permission: $e");
    return true;
  }
}

/// Opens the system page where full-screen notifications can be allowed.
/// On Android 14+ this is a dedicated "full-screen notifications" switch for
/// the app, which is required for alarms to take over the lock screen.
Future<void> openFullScreenIntentSettings() async {
  try {
    await _channel.invokeMethod("openFullScreenIntentSettings");
  } catch (e) {
    logger.e("Error opening full screen intent settings: $e");
  }
}

Future<void> _invokeEach(List<String> methods) async {
  for (String method in methods) {
    try {
      await _channel.invokeMethod(method);
    } catch (e) {
      logger.e("Error calling $method: $e");
    }
  }
}
