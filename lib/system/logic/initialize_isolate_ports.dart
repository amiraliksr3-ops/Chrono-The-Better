import 'dart:isolate';
import 'dart:ui';

import 'package:clock_app/alarm/logic/alarm_isolate.dart';
import 'package:clock_app/common/types/notification_type.dart';
import 'package:clock_app/developer/logic/logger.dart';
import 'package:clock_app/notifications/data/fullscreen_notification_data.dart';
import 'package:clock_app/notifications/logic/alarm_notifications.dart';
import 'package:clock_app/settings/types/listener_manager.dart';

void initializeIsolatePorts(){
    ReceivePort receivePort = ReceivePort();
  IsolateNameServer.removePortNameMapping(updatePortName);
  IsolateNameServer.registerPortWithName(receivePort.sendPort, updatePortName);
  printIsolateInfo();
  receivePort.listen((message) {
    if (message == "updateAlarms") {
      ListenerManager.notifyListeners("alarms");
    } else if (message == "updateTimers") {
      ListenerManager.notifyListeners("timers");
    } else if (message == "updateStopwatches") {
      ListenerManager.notifyListeners("stopwatch");
    } else if (message is String &&
        message.startsWith(alarmRingingPortMessagePrefix)) {
      final int? scheduleId = int.tryParse(
          message.substring(alarmRingingPortMessagePrefix.length));
      if (scheduleId != null) {
        // The app is already running: show the alarm screen now instead of
        // waiting for the user to tap the notification.
        openAlarmNotificationScreen(
          alarmNotificationData[ScheduledNotificationType.alarm]!,
          [scheduleId],
        );
      }
    }
  });
}
