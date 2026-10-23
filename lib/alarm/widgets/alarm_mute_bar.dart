import 'dart:async';

import 'package:clock_app/alarm/logic/alarm_mute.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// The thickness of the mute progress line.
const double _barThickness = 7.0;

/// A thick solid line pinned to the very top edge of the alarm ringing screen.
///
/// Its width directly mirrors [AlarmMuteController.remainingFraction], which is
/// repainted every frame by a [Ticker] while the alarm is muted, so the line
/// drains smoothly and restarts at full width on every mission interaction.
/// Shows no countdown numbers.
class AlarmMuteBar extends StatefulWidget {
  const AlarmMuteBar({super.key});

  @override
  State<AlarmMuteBar> createState() => _AlarmMuteBarState();
}

class _AlarmMuteBarState extends State<AlarmMuteBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    AlarmMuteController.instance.addListener(_onMuteChanged);
    // The mute might already be active when this widget is mounted.
    if (AlarmMuteController.instance.isMuted) _ticker.start();
  }

  void _onMuteChanged() {
    if (!mounted) return;
    if (!AlarmMuteController.instance.isMuted) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
    setState(() {});
  }

  void _onFrame(Duration elapsed) {
    if (!AlarmMuteController.instance.isMuted) {
      _ticker.stop();
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AlarmMuteController.instance.removeListener(_onMuteChanged);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ColorScheme colorScheme = theme.colorScheme;

    if (!AlarmMuteController.instance.isMuted) {
      return const SizedBox.shrink();
    }
    // Clamp guards against going negative right at the countdown's end.
    double fraction =
        AlarmMuteController.instance.remainingFraction.clamp(0.01, 1.0);
    return SizedBox(
      height: _barThickness,
      width: double.infinity,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: Container(
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

/// The persistent mute button shown on the alarm ringing screen and under
/// every mission. While muted, it shows "Muted · <seconds left>s" and ticking;
/// tapping it again restarts the 30 second countdown.
class AlarmMuteButton extends StatefulWidget {
  const AlarmMuteButton({super.key});

  @override
  State<AlarmMuteButton> createState() => _AlarmMuteButtonState();
}

class _AlarmMuteButtonState extends State<AlarmMuteButton> {
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    // Ticks twice a second so the remaining seconds on the button stay live.
    _uiTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (AlarmMuteController.instance.isMuted && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AlarmMuteController.instance,
      builder: (context, _) {
        AlarmMuteController controller = AlarmMuteController.instance;
        bool muted = controller.isMuted;
        return TextButton.icon(
          onPressed: () => controller.start(),
          icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
          label: Text(muted
              ? "${AppLocalizations.of(context)!.mutedAlarmButton}"
                  " · ${controller.remainingSeconds} s"
              : AppLocalizations.of(context)!.muteAlarmButton),
        );
      },
    );
  }
}
