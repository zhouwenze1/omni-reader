import 'package:flutter/material.dart';

import 'reader_progress_slider.dart';

class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.progress,
    required this.onProgressChanged,
    required this.onProgressChangeEnd,
    required this.onPrev,
    required this.onNext,
  });

  final double progress;
  final ValueChanged<double> onProgressChanged;
  final ValueChanged<double> onProgressChangeEnd;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReaderProgressSlider(
                value: progress,
                onChanged: onProgressChanged,
                onChangeEnd: onProgressChangeEnd,
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onPrev,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '进度 ${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
