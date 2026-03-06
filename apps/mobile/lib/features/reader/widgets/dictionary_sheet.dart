import 'package:flutter/material.dart';

class DictionarySheet extends StatelessWidget {
  const DictionarySheet({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('词典', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(text.isEmpty ? '暂无词条' : '当前版本未接词典引擎。\n\n$text'),
        ],
      ),
    );
  }
}
