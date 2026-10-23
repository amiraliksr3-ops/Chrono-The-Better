import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('com.vicolo.chrono/alarm');

Future<void> setSystemVolume(double percent) async {
  try {
    await _channel.invokeMethod('setSystemVolume', {'percent': percent});
  } catch (_) {}
}
