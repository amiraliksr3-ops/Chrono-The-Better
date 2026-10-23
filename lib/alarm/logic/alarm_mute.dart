import 'dart:async';
import 'dart:ui';

import 'package:clock_app/alarm/logic/alarm_isolate.dart';
import 'package:flutter/foundation.dart';

/// Controls muting of the alarm audio and vibration for 30 seconds.
///
/// The audio player lives in the alarm isolate, while this controller lives in
/// the main isolate (the alarm ringing screen). Communication happens over the
/// [alarmMutePortName] isolate port, which is registered when the alarm
/// triggers.
///
/// While muted, any interaction with a mission (typing, tapping, dragging)
/// restarts the 30 second countdown via [interact]. When the countdown expires,
/// the alarm fades back in over [unmuteFadeDuration] at the last stored target
/// volume (see [setTargetVolume]).
class AlarmMuteController extends ChangeNotifier {
  AlarmMuteController._();

  /// Shared instance used by the ringing screen and the mission widgets.
  static final AlarmMuteController instance = AlarmMuteController._();

  /// How long the alarm stays muted after muting or interacting with a mission.
  static const Duration muteDuration = Duration(seconds: 30);

  /// How long the fade back to the target volume takes after the mute expires.
  static const Duration unmuteFadeDuration = Duration(seconds: 5);

  bool _isMuted = false;
  double _targetVolume = 100;
  DateTime _muteEndTime = DateTime.now();
  Timer? _countdownTimer;
  int _generation = 0;

  /// Whether the alarm is currently muted.
  bool get isMuted => _isMuted;

  /// Incremented every time the mute starts or the countdown is restarted.
  /// Used by the mute progress bar to detect countdown restarts without
  /// requiring continuous notifications.
  int get generation => _generation;

  /// The fraction of the mute countdown that is still remaining (0.0 to 1.0).
  double get remainingFraction {
    if (!_isMuted) return 0.0;
    double remaining = _muteEndTime.difference(DateTime.now()).inMilliseconds /
        muteDuration.inMilliseconds;
    return remaining.clamp(0.0, 1.0);
  }

  /// Silences the alarm sound and vibration. If the alarm is already muted,
  /// restarts the 30 second countdown instead.
  void start() {
    if (_isMuted) {
      _restartCountdown();
      return;
    }
    _isMuted = true;
    IsolateNameServer.lookupPortByName(alarmMutePortName)?.send(["mute"]);
    _restartCountdown();
  }

  /// Called on any interaction with a mission (a typed character, a tap, a
  /// slider drag). If muted, restarts the countdown at a fresh 30 seconds.
  /// If not muted, does nothing: interactions only matter while muted.
  void interact() {
    if (!_isMuted) return;
    _restartCountdown();
  }

  /// Stores the volume the alarm should play at. While muted, only stores the
  /// value so that mission transitions don't break the mute. While unmuted,
  /// forwards it through the existing volume port like before.
  void setTargetVolume(double volume) {
    _targetVolume = volume;
    if (!_isMuted) {
      IsolateNameServer.lookupPortByName(setAlarmVolumePortName)
          ?.send([volume]);
    }
  }

  /// Ends the mute and tells the alarm isolate to fade the alarm back in over
  /// [unmuteFadeDuration] to the last stored target volume.
  void _unmute() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (!_isMuted) return;
    _isMuted = false;
    IsolateNameServer.lookupPortByName(alarmMutePortName)?.send(
        ["unmute", _targetVolume, unmuteFadeDuration.inSeconds]);
    notifyListeners();
  }

  void _restartCountdown() {
    _muteEndTime = DateTime.now().add(muteDuration);
    _generation++;
    _countdownTimer?.cancel();
    Timer? timer;
    timer = Timer(muteDuration, () {
      // Ignore stale timers that fired after the countdown was restarted.
      if (_countdownTimer == timer) _unmute();
    });
    _countdownTimer = timer;
    notifyListeners();
  }

  /// Cancels the countdown without sending an unmute. Called when the alarm is
  /// dismissed, snoozed or the ringing screen is closed, so that a mute that
  /// expires later doesn't restart a stopped alarm.
  void cancel() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isMuted = false;
    notifyListeners();
  }

  /// Fully resets the controller for a new ringing session and applies
  /// [initialVolume] as the target volume.
  void reset(double initialVolume) {
    cancel();
    setTargetVolume(initialVolume);
  }
}
