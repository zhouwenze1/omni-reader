import 'package:flutter/material.dart';

class TranslationSheet extends StatelessWidget {
  const TranslationSheet({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('翻译', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(text.isEmpty ? '暂无待翻译内容' : '翻译服务待接入。\n\n$text'),
        ],
      ),
    );
  }
}
