import 'package:flutter/material.dart';

class ReaderProgressSlider extends StatelessWidget {
  const ReaderProgressSlider({
    super.key,
    required this.value,
    this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = SliderTheme.of(context);
    return SliderTheme(
      data: theme.copyWith(
        trackHeight: 6,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      child: Slider(
        min: 0,
        max: 1,
        value: value.clamp(0.0, 1.0),
        onChangeStart: onChangeStart,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}
