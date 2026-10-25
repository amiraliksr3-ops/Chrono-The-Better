import 'package:clock_app/audio/logic/ringtones.dart';
import 'package:clock_app/audio/types/ringtone_player.dart';
import 'package:clock_app/common/types/file_item.dart';
import 'package:clock_app/developer/logic/logger.dart';
import 'package:clock_app/settings/types/setting.dart';
import 'package:flutter/material.dart';

/// A play/stop button shown next to the alarm volume slider. It previews the
/// alarm sound of the currently selected melody, so the user can hear exactly
/// how the alarm will ring: at full player volume (the volume itself comes
/// from Android's alarm stream, which the slider moves), or silent while the
/// alarm is muted, in which case it still vibrates if the alarm vibrates.
class VolumePreviewButton extends StatefulWidget {
  const VolumePreviewButton({
    super.key,
    required this.volumeSetting,
  });

  /// The alarm volume slider this button previews, used to read the current
  /// volume and to find the sibling "Melody" setting through its parent group.
  final SliderSetting volumeSetting;

  @override
  State<VolumePreviewButton> createState() => _VolumePreviewButtonState();
}

class _VolumePreviewButtonState extends State<VolumePreviewButton> {
  bool _playing = false;

  @override
  void dispose() {
    // Don't leave the sound looping when the settings page is closed.
    if (_playing) RingtonePlayer.stop();
    super.dispose();
  }

  /// Reads a switch setting that sits next to the volume slider: "Mute" is in
  /// the same group as the slider, "Vibration" one level up (see
  /// alarm_settings_schema.dart). A setting that can't be found counts as off.
  bool _siblingSwitchValue(String name, {bool oneLevelUp = false}) {
    try {
      final group = oneLevelUp
          ? widget.volumeSetting.parent!.parent!
          : widget.volumeSetting.parent!;
      return group.getSetting(name).value as bool;
    } catch (e) {
      logger.e("Could not read the $name setting while previewing: $e");
      return false;
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await RingtonePlayer.stop();
      setState(() {
        _playing = false;
      });
      return;
    }
    try {
      // The sibling "Melody" setting lives in the same settings group as the
      // volume slider (see alarm_settings_schema.dart).
      DynamicSelectSetting melodySetting = widget.volumeSetting.parent!
          .getSetting("Melody") as DynamicSelectSetting;
      FileItem melody = melodySetting.value as FileItem;
      String uri = await getRingtoneUri(melody);
      // Pass the volume before playback starts. Setting it afterwards let the
      // first moments of the preview play at 100% and could be missed entirely
      // on slow devices. Android's alarm stream holds the real volume, so the
      // player itself only has to decide between full volume and silence.
      final bool muted = _siblingSwitchValue("Mute");
      final bool vibrate =
          _siblingSwitchValue("Vibration", oneLevelUp: true);
      await RingtonePlayer.playUri(
        uri,
        vibrate: muted && vibrate,
        volume: muted ? 0.0 : 1.0,
      );
      if (mounted) {
        setState(() {
          _playing = true;
        });
      }
    } catch (e) {
      logger.e("Error previewing alarm volume: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Match the color of the volume slider this button sits next to: the
    // slider uses its thumb/active-track color when the theme defines one,
    // otherwise the theme's primary color (which the slider defaults to).
    final SliderThemeData sliderTheme = SliderTheme.of(context);
    final Color sliderColor = sliderTheme.thumbColor ??
        sliderTheme.activeTrackColor ??
        Theme.of(context).colorScheme.primary;
    return IconButton(
      onPressed: _toggle,
      icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
      color: sliderColor,
      tooltip: null,
      splashRadius: 20.0,
    );
  }
}
