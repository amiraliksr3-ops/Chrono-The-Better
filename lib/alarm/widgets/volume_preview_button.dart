import 'package:clock_app/audio/logic/ringtones.dart';
import 'package:clock_app/audio/types/ringtone_player.dart';
import 'package:clock_app/common/types/file_item.dart';
import 'package:clock_app/developer/logic/logger.dart';
import 'package:clock_app/settings/types/setting.dart';
import 'package:flutter/material.dart';

/// A play/stop button shown next to the alarm volume slider. It previews the
/// alarm sound of the currently selected melody at the slider's current
/// volume, so the user can hear exactly how loud the alarm will ring.
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
      // on slow devices.
      await RingtonePlayer.playUri(
        uri,
        vibrate: false,
        volume: widget.volumeSetting.value / 100,
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
    return IconButton(
      onPressed: _toggle,
      icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
      color: Colors.redAccent,
      tooltip: null,
      splashRadius: 20.0,
    );
  }
}
