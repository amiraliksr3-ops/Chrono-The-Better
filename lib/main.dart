import 'dart:core';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:clock_app/alarm/logic/update_alarms.dart';
import 'package:clock_app/app.dart';
import 'package:clock_app/audio/logic/audio_session.dart';
import 'package:clock_app/audio/types/ringtone_player.dart';
import 'package:clock_app/common/data/paths.dart';
import 'package:clock_app/navigation/types/app_visibility.dart';
import 'package:clock_app/notifications/logic/foreground_task.dart';
import 'package:clock_app/notifications/logic/notifications.dart';
import 'package:clock_app/settings/logic/initialize_settings.dart';
import 'package:clock_app/system/data/app_info.dart';
import 'package:clock_app/system/data/device_info.dart';
import 'package:clock_app/system/logic/background_service.dart';
import 'package:clock_app/system/logic/handle_boot.dart';
import 'package:clock_app/system/logic/initialize_isolate_ports.dart';
import 'package:clock_app/timer/logic/update_timers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boot_receiver/flutter_boot_receiver.dart';
import 'package:flutter_show_when_locked/flutter_show_when_locked.dart';
import 'package:receive_intent/receive_intent.dart' hide Intent;
import 'package:timezone/data/latest_all.dart';

void main() async {
  // FlutterError.onError = (FlutterErrorDetails details) {
  //   logger.e(details.exception.toString(), stackTrace: details.stack,);
  // };

  WidgetsFlutterBinding.ensureInitialized();

  initializeTimeZones();

  // When a notification (including a full-screen alarm intent) launched the
  // app, keep the manifest's show-when-locked / turn-screen-on flags instead
  // of clearing them before the ringing screen has a chance to appear.
  bool launchedFromNotification = false;
  try {
    final initialIntent = await ReceiveIntent.getInitialIntent();
    launchedFromNotification = initialIntent?.action == "SELECT_NOTIFICATION";
  } catch (_) {
    // Not available on this platform; normal startup behavior applies.
  }

  final initializeData = [
    initializePackageInfo(),
    initializeAndroidInfo(),
    initializeAppDataDirectory(),
    initializeNotifications(),
    AndroidAlarmManager.initialize(),
    BootReceiver.initialize(handleBoot),
    RingtonePlayer.initialize(),
    initializeAudioSession(),
    if (!launchedFromNotification) FlutterShowWhenLocked().hide(),
  ];
  await Future.wait(initializeData);

  // These rely on initializeAppDataDirectory
  await initializeStorage();
  await initializeSettings();

  await updateAlarms("Update Alarms on Start");
  await updateTimers("Update Timers on Start");
  AppVisibility.initialize();
  initForegroundTask();
  initBackgroundService();
  initializeIsolatePorts();

  runApp(const App());

  registerHeadlessBackgroundService();
}
