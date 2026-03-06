import 'package:flutter/material.dart';

class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.leading,
    this.valueText,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final Widget? leading;
  final String? valueText;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: leading,
      title: Text(title),
      subtitle: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
      trailing: Text(valueText ?? value.toStringAsFixed(1)),
    );
  }
}
