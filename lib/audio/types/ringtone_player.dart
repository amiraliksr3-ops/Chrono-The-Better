import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:clock_app/alarm/types/alarm.dart';
import 'package:clock_app/audio/logic/ringtones.dart';
import 'package:clock_app/audio/types/ringtone_manager.dart';
import 'package:clock_app/developer/logic/logger.dart';
import 'package:clock_app/timer/types/timer.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

Random random = Random();

class RingtonePlayer {
  static AudioPlayer? _alarmPlayer;
  static AudioPlayer? _timerPlayer;
  static AudioPlayer? _mediaPlayer;
  static AudioPlayer? activePlayer;
  static bool _vibratorIsAvailable = false;
  static bool _stopRisingVolume = false;
  static bool _stopFadeIn = false;
  static bool _vibrateOn = false;

  static Future<void> initialize() async {
    _alarmPlayer ??= AudioPlayer(handleInterruptions: true);
    _timerPlayer ??= AudioPlayer(handleInterruptions: true);
    _mediaPlayer ??= AudioPlayer(handleInterruptions: true);
    _mediaPlayer?.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
    );
    _vibratorIsAvailable = (await Vibration.hasVibrator()) ?? false;
  }

  static Future<void> playUri(String ringtoneUri,
      {bool vibrate = false,
      LoopMode loopMode = LoopMode.one,
      AndroidAudioUsage channel = AndroidAudioUsage.alarm,
      double volume = 1.0}) async {
    activePlayer = _mediaPlayer;
    // Preview the file on the alarm stream, so the preview sounds like the
    // actual alarm (and obeys the same system stream).
    await activePlayer?.setAndroidAudioAttributes(AndroidAudioAttributes(
      usage: channel,
      contentType: AndroidAudioContentType.music,
    ));
    await _play(
      ringtoneUri,
      vibrate: vibrate,
      loopMode: loopMode,
      volume: volume,
    );
  }

  static Future<void> playAlarm(Alarm alarm,
      {LoopMode loopMode = LoopMode.one}) async {
    await activePlayer?.stop();
    _alarmPlayer = AudioPlayer(handleInterruptions: false);
    await _alarmPlayer?.setAndroidAudioAttributes(AndroidAudioAttributes(
      usage: alarm.audioChannel,
      contentType: AndroidAudioContentType.music,
    ));
    activePlayer = _alarmPlayer;
    String uri = await getRingtoneUri(alarm.ringtone);

    logger.t("Playing alarm with uri: $uri");

    await _play(uri,
        vibrate: alarm.vibrate,
        loopMode: LoopMode.one,
        volume: alarm.playbackVolume / 100,
        secondsToMaxVolume: alarm.risingVolumeDuration.inSeconds,
        startAtRandomPos: alarm.shouldStartMelodyAtRandomPos);
  }

  static Future<void> playTimer(ClockTimer timer,
      {LoopMode loopMode = LoopMode.one}) async {
    await _timerPlayer?.setAndroidAudioAttributes(AndroidAudioAttributes(
      usage: timer.audioChannel,
      contentType: AndroidAudioContentType.music,
    ));
    activePlayer = _timerPlayer;
    await _play(
      timer.ringtone.uri,
      vibrate: timer.vibrate,
      loopMode: LoopMode.one,
      volume: timer.volume / 100,
      secondsToMaxVolume: timer.risingVolumeDuration.inSeconds,
    );
  }

  static Future<void> setVolume(double volume) async {
    logger.t("Setting volume to $volume");
    _stopRisingVolume = true;
    await activePlayer?.setVolume(volume);
  }

  static Future<void> _play(
    String ringtoneUri, {
    bool vibrate = false,
    LoopMode loopMode = LoopMode.one,
    double volume = 1.0,
    int secondsToMaxVolume = 0,
    bool startAtRandomPos = false,
    // double duration = double.infinity,
  }) async {
    try {
      _stopRisingVolume = false;
      _vibrateOn = vibrate;

      RingtoneManager.lastPlayedRingtoneUri = ringtoneUri;
      if (_vibratorIsAvailable && vibrate) {
        Vibration.vibrate(pattern: [500, 1000], repeat: 0);
      }
      // activePlayer?.
      await activePlayer?.stop();
      await activePlayer?.setLoopMode(loopMode);
      Duration? duration = await activePlayer
          ?.setAudioSource(AudioSource.uri(Uri.parse(ringtoneUri)));
      logger.t("Duration: $duration");

      if (duration != null && startAtRandomPos) {
        double randomNumber = random.nextInt(100) / 100.0;
        logger.t("Starting at random position: $randomNumber");
        activePlayer?.seek(duration * randomNumber);
      }
      await setVolume(volume);

      // Gradually increase the volume
      if (secondsToMaxVolume > 0) {
        for (int i = 0; i <= 10; i++) {
          Future.delayed(
            Duration(milliseconds: i * (secondsToMaxVolume * 100)),
            () {
              if (!_stopRisingVolume) {
                setVolume((i / 10) * volume);
              }
            },
          );
        }
      }
      // Future.delayed(
      //   Duration(seconds: duration.toInt()),
      //   () async {
      //     await stop();
      //   },
      // );

      // Don't use await here as this will only return after the audio is done
      activePlayer?.play();
    } catch (e) {
      logger.e("Error playing $ringtoneUri: $e");
    }
  }

  /// Silences the alarm sound and vibration. Keeps the player running at zero
  /// volume instead of pausing it: resuming a paused player is not reliable on
  /// every device/audio stream, so the alarm may never come back. Playing
  /// silently and restoring the volume later always works.
  static Future<void> mute() async {
    _stopRisingVolume = true;
    _stopFadeIn = true;
    await activePlayer?.setVolume(0);
    if (_vibratorIsAvailable) {
      await Vibration.cancel();
    }
  }

  /// Fades the alarm sound back in from silence to [targetVolume] (0.0 - 1.0)
  /// over [seconds] seconds and restarts the vibration pattern if the alarm
  /// vibrates.
  static Future<void> unmuteFade(double targetVolume, int seconds) async {
    try {
      _stopFadeIn = false;
      AudioPlayer? player = activePlayer;
      if (player == null) return;
      // Defensive recovery: if the player got paused or stopped in the
      // meantime, restart it. During a normal mute the player keeps playing
      // at zero volume, so this is usually a no-op.
      if (player.processingState == ProcessingState.idle &&
          RingtoneManager.lastPlayedRingtoneUri.isNotEmpty) {
        await player.setAudioSource(
            AudioSource.uri(Uri.parse(RingtoneManager.lastPlayedRingtoneUri)));
      }
      if (!player.playing) {
        await player.play();
      }
      await player.setVolume(0);
      if (_vibratorIsAvailable && _vibrateOn) {
        Vibration.vibrate(pattern: [500, 1000], repeat: 0);
      }
      // Gradually increase the volume from silence to the target volume
      for (int i = 0; i <= 10; i++) {
        Future.delayed(
          Duration(milliseconds: i * (seconds * 100)),
          () {
            if (!_stopFadeIn) {
              setVolume((i / 10) * targetVolume);
            }
          },
        );
      }
    } catch (e) {
      logger.e("Error fading in alarm volume: $e");
    }
  }

  static Future<void> pause() async {
    await activePlayer?.pause();
    if (_vibratorIsAvailable) {
      await Vibration.cancel();
    }
  }

  static Future<void> stop() async {
    await activePlayer?.stop();
    final session = await AudioSession.instance;
    await session.setActive(false);
    if (_vibratorIsAvailable) {
      await Vibration.cancel();
    }
    RingtoneManager.lastPlayedRingtoneUri = "";
    _stopRisingVolume = false;
    _stopFadeIn = false;
    _vibrateOn = false;
  }
}
