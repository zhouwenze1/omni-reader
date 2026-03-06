import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../utils/formatters.dart';

class ReadingNowCard extends StatelessWidget {
  const ReadingNowCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final LibraryIndexEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(entry.title),
        subtitle: Text('进度 ${AppFormatters.percent(entry.cachedProgress ?? 0)}'),
        trailing: FilledButton(
          onPressed: onTap,
          child: const Text('继续'),
        ),
        onTap: onTap,
      ),
    );
  }
}
