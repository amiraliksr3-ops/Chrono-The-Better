import 'package:clock_app/alarm/logic/alarm_mute.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// The thickness of the mute progress line.
const double _barThickness = 7.0;

/// Duration it takes for the line to smoothly re-animate from its current
/// position back to full width after a countdown restart.
const Duration _refillDuration = Duration(milliseconds: 500);

/// A thick solid line pinned to the very top edge of the alarm ringing screen.
///
/// Its width equals the remaining mute time fraction and is driven by an
/// [AnimationController], so that a mid-animation restart (mission interaction)
/// smoothly re-animates the line from empty back to full. Shows no countdown
/// numbers.
class AlarmMuteBar extends StatefulWidget {
  const AlarmMuteBar({super.key});

  @override
  State<AlarmMuteBar> createState() => _AlarmMuteBarState();
}

class _AlarmMuteBarState extends State<AlarmMuteBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drainController;
  int _lastGeneration = -1;

  @override
  void initState() {
    super.initState();
    _drainController = AnimationController(
      vsync: this,
      duration: AlarmMuteController.muteDuration,
    );
    AlarmMuteController.instance.addListener(_onMuteChanged);
    _lastGeneration = AlarmMuteController.instance.generation;
    if (AlarmMuteController.instance.isMuted) {
      _startDrainAnimation();
    }
  }

  void _onMuteChanged() {
    if (!mounted) return;
    if (!AlarmMuteController.instance.isMuted) {
      // The mute ended: quickly drain the line to empty.
      _drainController.stop();
      _drainController.animateTo(1.0,
          duration: const Duration(milliseconds: 300));
      return;
    }
    if (AlarmMuteController.instance.generation != _lastGeneration) {
      _lastGeneration = AlarmMuteController.instance.generation;
      _startDrainAnimation();
    }
  }

  Future<void> _startDrainAnimation() async {
    _drainController.stop();
    // Smoothly re-animate from the current position back to full width.
    await _drainController.animateTo(0.0,
        duration: _refillDuration, curve: Curves.easeOutCubic);
    if (!mounted || !AlarmMuteController.instance.isMuted) return;
    double remainingFraction = AlarmMuteController.instance.remainingFraction;
    if (remainingFraction <= 0) return;
    _drainController.duration = AlarmMuteController.muteDuration * remainingFraction;
    _drainController.forward(from: 1.0 - remainingFraction);
  }

  @override
  void dispose() {
    AlarmMuteController.instance.removeListener(_onMuteChanged);
    _drainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ColorScheme colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: AlarmMuteController.instance,
      builder: (context, child) {
        bool muted = AlarmMuteController.instance.isMuted;
        return AnimatedOpacity(
          opacity: muted ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: child!,
        );
      },
      child: SizedBox(
        height: _barThickness,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _drainController,
          builder: (context, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0 - _drainController.value,
            child: Container(
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The persistent mute button shown on the alarm ringing screen and under
/// every mission. While muted, it reflects the muted state; tapping it again
/// restarts the 30 second countdown.
class AlarmMuteButton extends StatelessWidget {
  const AlarmMuteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AlarmMuteController.instance,
      builder: (context, _) {
        bool muted = AlarmMuteController.instance.isMuted;
        return TextButton.icon(
          onPressed: () => AlarmMuteController.instance.start(),
          icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
          label: Text(muted
              ? AppLocalizations.of(context)!.mutedAlarmButton
              : AppLocalizations.of(context)!.muteAlarmButton),
        );
      },
    );
  }
}
