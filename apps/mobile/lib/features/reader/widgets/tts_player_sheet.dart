import 'package:flutter/material.dart';

class TtsPlayerSheet extends StatelessWidget {
  const TtsPlayerSheet({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('朗读', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(text.isEmpty ? '暂无朗读内容' : 'TTS 服务待接入。\n\n$text'),
        ],
      ),
    );
  }
}
