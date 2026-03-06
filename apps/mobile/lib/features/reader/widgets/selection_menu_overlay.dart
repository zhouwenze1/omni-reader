import 'package:flutter/material.dart';

class SelectionMenuOverlay extends StatelessWidget {
  const SelectionMenuOverlay({
    super.key,
    required this.onDictionary,
    required this.onTranslate,
    required this.onSpeak,
  });

  final VoidCallback onDictionary;
  final VoidCallback onTranslate;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ActionChip(label: const Text('词典'), onPressed: onDictionary),
        ActionChip(label: const Text('翻译'), onPressed: onTranslate),
        ActionChip(label: const Text('朗读'), onPressed: onSpeak),
      ],
    );
  }
}
