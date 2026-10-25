import 'dart:async';

import 'package:clock_app/common/widgets/card_container.dart';
import 'package:clock_app/common/widgets/fields/slider_field.dart';
import 'package:clock_app/developer/logic/logger.dart';
import 'package:clock_app/settings/types/setting.dart';
import 'package:flutter/material.dart';

class SliderSettingCard extends StatefulWidget {
  final SliderSetting setting;
  final bool showAsCard;
  final void Function(double)? onChanged;

  const SliderSettingCard({
    super.key,
    required this.setting,
    this.showAsCard = false,
    this.onChanged,
  });

  @override
  State<SliderSettingCard> createState() => _SliderSettingCardState();
}

class _SliderSettingCardState extends State<SliderSettingCard> {
  /// How long the input has to be still before the value is read back from
  /// the system, so the read never fights a drag in progress.
  static const Duration _readBackDelay = Duration(milliseconds: 300);

  /// The system's current value and step range, when the setting mirrors one.
  ({double? percent, int min, int max})? _systemValue;
  Timer? _readBackTimer;

  @override
  void initState() {
    super.initState();
    _mirrorSystemValue();
  }

  @override
  void didUpdateWidget(covariant SliderSettingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.setting, widget.setting)) {
      _systemValue = null;
      _mirrorSystemValue();
    }
  }

  @override
  void dispose() {
    _readBackTimer?.cancel();
    super.dispose();
  }

  bool get _mirrorsSystem => widget.setting.systemValue != null;

  /// The lowest value the slider can show. For a mirrored slider that is the
  /// system's own lowest step: Android's alarm volume starts at its first
  /// step (14% on a 7-step phone) and has no 0% below it.
  double get _min {
    if (!_mirrorsSystem) return widget.setting.min;
    final system = _systemValue;
    if (system == null || system.max <= system.min) return widget.setting.min;
    return system.min * 100.0 / system.max;
  }

  /// How many positions the slider snaps to — one per system step — so every
  /// value it can land on is a value the system actually has.
  int? get _divisions {
    if (!_mirrorsSystem) return null;
    final system = _systemValue;
    if (system == null || system.max <= system.min) return null;
    return system.max - system.min;
  }

  /// The distance between two positions: one system step when the slider
  /// mirrors a system, otherwise whatever the setting itself asked for.
  double? get _snapLength {
    final divisions = _divisions;
    if (divisions == null || divisions <= 0) return widget.setting.snapLength;
    return (widget.setting.max - _min) / divisions;
  }

  /// Reads the system's value and steps and shows them, so the slider mirrors
  /// what the system really holds — after the volume was changed with the
  /// phone's own keys, or after Android rounded a typed value down to its
  /// steps. When the value couldn't be read, only the steps are applied and
  /// the stored value is left alone.
  Future<void> _mirrorSystemValue() async {
    final read = widget.setting.systemValue;
    if (read == null) return;
    try {
      final system = await read();
      if (!mounted || system == null) return;
      setState(() {
        _systemValue = system;
        final percent = system.percent;
        if (percent != null) {
          widget.setting.setValueWithoutNotify(
              percent.clamp(_min, widget.setting.max).toDouble());
        }
      });
    } catch (e) {
      logger.e("Error mirroring the system value of ${widget.setting.name}: $e");
    }
  }

  /// Reads the value back once the input has settled, to show the value the
  /// system stored. The delay keeps it from overwriting a drag in progress.
  void _scheduleReadBack() {
    if (!_mirrorsSystem) return;
    _readBackTimer?.cancel();
    _readBackTimer = Timer(_readBackDelay, () {
      if (mounted) _mirrorSystemValue();
    });
  }

  @override
  Widget build(BuildContext context) {
    SliderField sliderCard = SliderField(
      title: widget.setting.displayName(context),
      description: widget.setting.displayDescription(context),
      // Clamped to the slider's own range, so a value stored before the
      // slider started mirroring the system (0% in old alarms) can never sit
      // outside the system's steps.
      value: widget.setting.value.clamp(_min, widget.setting.max).toDouble(),
      min: _min,
      max: widget.setting.max,
      unit: widget.setting.unit,
      snapLength: _snapLength,
      integerDisplay: widget.setting.integerDisplay,
      trailing:
          widget.setting.previewActionBuilder?.call(context, widget.setting),
      onChanged: (value) {
        setState(() {
          widget.setting.setValue(context, value);
        });
        widget.onChanged?.call(widget.setting.value);
        _scheduleReadBack();
      },
    );

    return widget.showAsCard
        ? CardContainer(
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: sliderCard,
          ))
        : sliderCard;
  }
}
