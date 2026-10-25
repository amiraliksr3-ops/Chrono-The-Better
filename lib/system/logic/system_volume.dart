import 'package:clock_app/developer/logic/logger.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('com.vicolo.chrono/alarm');

/// The alarm audio stream as Android reports it: its current value in
/// percent (null when it couldn't be read) plus the raw step range Android
/// accepts for it. The alarm stream only holds a handful of steps — 7 on
/// most phones, which Android shows as 14% through 100% — so these steps,
/// not invented percentages, are the only values the volume slider shows.
typedef SystemVolume = ({double? percent, int min, int max});

/// Used when the platform can't be read: Android's default alarm steps,
/// with the current value left unknown so nothing overwrites what the
/// slider already has.
const SystemVolume defaultSystemVolume = (percent: null, min: 1, max: 7);

/// Asks Android to move its alarm volume to [percent]. Android snaps the
/// value to the nearest step it has, so the value that actually got stored
/// is read back afterwards with [getSystemVolume].
Future<double?> setSystemVolume(double percent) async {
  try {
    return await _channel
        .invokeMethod<double>('setSystemVolume', {'percent': percent});
  } catch (e) {
    logger.e("Error setting the system alarm volume to $percent%: $e");
    return null;
  }
}

/// Reads Android's alarm volume and the step range it accepts, falling back
/// to Android's default steps (with an unknown value) when the platform
/// doesn't answer.
Future<SystemVolume> getSystemVolume() async {
  try {
    final result = await _channel.invokeMethod<dynamic>('getSystemVolume');
    if (result is Map) {
      final percent = (result['percent'] as num?)?.toDouble();
      final min = (result['min'] as num?)?.toInt();
      final max = (result['max'] as num?)?.toInt();
      if (min != null && max != null && max > 0 && min <= max) {
        return (percent: percent, min: min, max: max);
      }
    }
    logger.e("Unexpected response while reading the system alarm volume: $result");
  } catch (e) {
    logger.e("Error reading the system alarm volume: $e");
  }
  return defaultSystemVolume;
}
