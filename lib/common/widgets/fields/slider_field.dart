import 'package:clock_app/common/utils/text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SliderField extends StatefulWidget {
  const SliderField(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.min,
      required this.max,
      required this.title,
      this.unit = '',
      this.snapLength,
      this.integerDisplay = false,
      this.description = '',
      this.trailing});

  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final String unit;
  final double? snapLength;

  /// Shows and accepts whole numbers only, for sliders whose steps are whole
  /// numbers anyway (e.g. Android's alarm volume, whose steps are shown as
  /// 14, 29, 43... instead of 14.3, 28.6...).
  final bool integerDisplay;

  final void Function(double value) onChanged;

  /// Optional widget (e.g. a preview play button) placed at the end of the
  /// slider row.
  final Widget? trailing;

  @override
  State<SliderField> createState() => _SliderFieldState();
}

class _SliderFieldState extends State<SliderField> {
  late final TextEditingController _textController =
      TextEditingController(text: valueToString(widget.value));

  // double _value = 0;

  void changeValue(double value) {
    setState(() {
      // _value = value;
    });
    widget.onChanged(value);
  }

  @override
  void initState() {
    super.initState();
    // _value = widget.value;
    // _textController
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String valueToString(double value) {
    // if (value.isInfinite) return '∞';
    return _showsWholeNumbers
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  /// Whole numbers are shown without decimals, either because the setting
  /// asked for it explicitly, or because its snap length already is one
  /// (such sliders only ever hold whole numbers anyway).
  bool get _showsWholeNumbers =>
      widget.integerDisplay ||
      ((widget.snapLength != null) && (widget.snapLength! % 1 <= 0.001));

  @override
  void didUpdateWidget(SliderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _textController.text = valueToString(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    final Size textSize =
        calcTextSize('000.0 ${widget.unit}', textTheme.bodyMedium!);
    final int? divisions = widget.snapLength != null
        ? ((widget.max - widget.min) / widget.snapLength!).round()
        : null;

    final bool isIntegerOnly = _showsWholeNumbers;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: textTheme.headlineMedium,
          ),
          if (widget.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(widget.description, style: textTheme.bodyMedium)
          ],
          const SizedBox(height: 8.0),
          Row(
            children: [
              SizedBox(
                width: textSize.width,
                // height: textSize.height,
                // width: 50,
                child: Row(
                  // crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IntrinsicWidth(
                      child: TextField(
                        autofocus: false,
                        onTapOutside: ((event) {
                          FocusScope.of(context).unfocus();
                        }),
                        onChanged: (textValue) {
                          if (textValue.isEmpty) {
                            textValue = valueToString(widget.min);
                          }
                          changeValue(double.parse(textValue));
                        },
                        onSubmitted: (textValue) {
                          if (textValue.isEmpty) {
                            _textController.text =
                                textValue = valueToString(widget.min);
                          }
                          changeValue(double.parse(textValue));
                        },
                        controller: _textController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          focusedBorder:
                              OutlineInputBorder(borderSide: BorderSide.none),
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        maxLines: 1,
                        textAlignVertical: TextAlignVertical.bottom,
                        style: textTheme.bodyMedium,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          if (isIntegerOnly)
                            FilteringTextInputFormatter.digitsOnly
                          else
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,1}'),
                            ),
                          NumericalRangeFormatter(
                            min: widget.min,
                            max: widget.max,
                            valueToString: valueToString,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      widget.unit,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              // const SizedBox(width: 4),
              Expanded(
                flex: 7,
                child: Slider(
                  value: widget.value,
                  onChanged: (double value) {
                    _textController.text = valueToString(value);
                    changeValue(value);
                  },
                  min: widget.min,
                  max: widget.max,
                  divisions: divisions,
                ),
              ),
              const SizedBox(width: 10),
              if (widget.trailing != null) widget.trailing!,
              // const Spacer(),
            ],
          )
        ],
      ),
    );
  }
}

class NumericalRangeFormatter extends TextInputFormatter {
  final double min;
  final double max;
  final String Function(double value) valueToString;

  NumericalRangeFormatter(
      {required this.valueToString, required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text == '') {
      return newValue;
    } else if (double.parse(newValue.text) < min) {
      return const TextEditingValue().copyWith(text: valueToString(min));
    } else {
      return double.parse(newValue.text) > max ? oldValue : newValue;
    }
  }
}
