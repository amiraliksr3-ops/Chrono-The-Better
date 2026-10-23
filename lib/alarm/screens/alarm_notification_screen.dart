import 'dart:async';

import 'package:clock_app/alarm/logic/alarm_mute.dart';
import 'package:clock_app/alarm/utils/alarm_id.dart';
import 'package:clock_app/alarm/types/alarm.dart';
import 'package:clock_app/alarm/widgets/alarm_mute_bar.dart';
import 'package:clock_app/common/types/notification_type.dart';
import 'package:clock_app/common/widgets/clock/digital_clock.dart';
import 'package:clock_app/developer/logic/logger.dart';
import 'package:clock_app/navigation/types/routes.dart';
import 'package:clock_app/notifications/logic/alarm_notifications.dart';
import 'package:clock_app/notifications/types/alarm_notification_arguments.dart';
import 'package:clock_app/navigation/types/alignment.dart';
import 'package:clock_app/notifications/widgets/notification_actions/slide_notification_action.dart';
import 'package:clock_app/settings/data/settings_schema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_show_when_locked/flutter_show_when_locked.dart';
import 'package:clock_app/system/logic/screen_flags.dart';

class AlarmNotificationScreen extends StatefulWidget {
  const AlarmNotificationScreen({
    super.key,
    required this.scheduleId,
    this.onPop,
    this.initialIndex = -1,
    this.dismissType = AlarmDismissType.dismiss,
  });

  final int scheduleId;
  final int initialIndex;
  final Function? onPop;
  final AlarmDismissType dismissType;

  @override
  State<AlarmNotificationScreen> createState() =>
      _AlarmNotificationScreenState();
}

class _AlarmNotificationScreenState extends State<AlarmNotificationScreen> {
  late Alarm alarm;
  late Widget _currentWidget;
  late int _currentIndex = widget.initialIndex;
  late Widget actionWidget;
  StreamSubscription<FGBGType>? _fgbgSubscription;

  /// Whether the alarm handled by this screen is still ringing. Used to only
  /// pop the screen back up over the home screen while the alarm is active.
  bool _stillRinging = true;

  /// When the user minimizes the app (or turns the screen off) while the alarm
  /// is ringing, re-post the full screen intent notification. Android shows it
  /// as a full screen launch, popping the ringing screen back up over the
  /// home screen.
  void _onAppVisibilityChanged(FGBGType event) {
    if (event != FGBGType.background || !_stillRinging) return;
    DateTime? time = alarm.currentScheduleDateTime;
    String timeString = time == null
        ? ""
        : "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
    showAlarmNotification(
      type: ScheduledNotificationType.alarm,
      scheduleIds: [widget.scheduleId],
      showSnoozeButton: alarm.canBeSnoozed,
      tasksRequired: alarm.tasks.isNotEmpty,
      title: alarm.label.isEmpty ? "Alarm Ringing..." : alarm.label,
      body: timeString,
      snoozeActionLabel: "Snooze",
      dismissActionLabel: "Dismiss",
    );
  }

  void _setNextWidget() {
    setState(() {
      if (_currentIndex < 0) {
        AlarmMuteController.instance.setTargetVolume(alarm.volume);
        _currentWidget = actionWidget;
      } else if (_currentIndex >= alarm.tasks.length) {
        AlarmMuteController.instance.cancel();
        _stillRinging = false;
        if (widget.onPop != null) {
          widget.onPop!();
          Navigator.of(context).pop(true);
        } else {
          dismissAlarmNotification(widget.scheduleId, widget.dismissType,
              ScheduledNotificationType.alarm);
        }
      } else {
        AlarmMuteController.instance
            .setTargetVolume(alarm.volume * alarm.volumeDuringTasks / 100);
        // RingtonePlayer.setVolume(0);
        _currentWidget = alarm.tasks[_currentIndex].builder(_setNextWidget);
      }
      _currentIndex++;
    });
  }

  @override
  void initState() {
    super.initState();

    Alarm? currentAlarm = getAlarmById(widget.scheduleId);
    if (currentAlarm == null) {
      dismissAlarmNotification(widget.scheduleId, widget.dismissType,
          ScheduledNotificationType.alarm);
      return;
    }
    alarm = currentAlarm;

    // Start a fresh mute session for this ringing screen
    AlarmMuteController.instance.reset(alarm.volume);

    // Guarantee lock-screen presentation: the ringing screen must show over
    // the lock screen and keep the display on, no matter which path opened it.
    FlutterShowWhenLocked().show();
    showOverLockScreen();

    // Pop the ringing screen back up over the home screen when minimized
    _fgbgSubscription = FGBGEvents.stream.listen(_onAppVisibilityChanged);

    try {
      actionWidget = appSettings
          .getGroup("Alarm")
          .getSetting("Dismiss Action Type")
          .value
          .builder(_setNextWidget, alarm.canBeSnoozed ? _snoozeAlarm : null,
              "Dismiss", "Snooze");
    } catch (e) {
      actionWidget = SlideNotificationAction(
        onDismiss: _setNextWidget,
        onSnooze: alarm.canBeSnoozed ? _snoozeAlarm : null,
        dismissLabel: "Dismiss",
        snoozeLabel: "Snooze",
      );

      logger.e(e.toString());
    }

    _setNextWidget();
  }

  @override
  void dispose() {
    _fgbgSubscription?.cancel();
    _fgbgSubscription = null;
    super.dispose();
  }

  void _snoozeAlarm() {
    _stillRinging = false;
    AlarmMuteController.instance.cancel();
    dismissAlarmNotification(widget.scheduleId, AlarmDismissType.snooze,
        ScheduledNotificationType.alarm);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AlarmMuteController.instance.interact(),
      onPointerMove: (_) => AlarmMuteController.instance.interact(),
      behavior: HitTestBehavior.opaque,
      child: WillPopScope(
        onWillPop: () async {
          Routes.pop(onlyUpdateRoute: true);
          return true;
        },
        child: Scaffold(
          body: Stack(
            children: [
              SingleChildScrollView(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Mute controls live at the top of the screen, below the
                      // status bar, so they never compete with the dismiss
                      // action at the bottom.
                      const SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            // Full-width mute progress line pinned to the top.
                            const AlarmMuteBar(),
                            const SizedBox(height: 4.0),
                            // Persistent mute button, shown on the ring screen
                            // and under every mission.
                            const AlarmMuteButton(),
                            const SizedBox(height: 4.0),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (_currentIndex <= 0)
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0),
                                  child: Column(
                                    children: [
                                      const Spacer(),
                                      if (alarm.label.isNotEmpty)
                                        Text(
                                          alarm.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .displayMedium,
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 8),
                                      const DigitalClock(
                                        // dateTime: Date,
                                        horizontalAlignment:
                                            ElementAlignment.center,
                                        shouldShowDate: false,
                                        shouldShowSeconds: false,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Alarm",
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _currentWidget,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationUtils {}
