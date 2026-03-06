import 'package:flutter/material.dart';

class ReaderProgressSlider extends StatelessWidget {
  const ReaderProgressSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Slider(
      min: 0,
      max: 1,
      value: value.clamp(0.0, 1.0),
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}
