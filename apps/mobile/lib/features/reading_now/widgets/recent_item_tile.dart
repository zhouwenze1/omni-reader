import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../utils/formatters.dart';

class RecentItemTile extends StatelessWidget {
  const RecentItemTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final LibraryIndexEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = entry.lastOpenedAt ?? entry.updatedAt;
    return Card(
      child: ListTile(
        title: Text(entry.title),
        subtitle: Text('最近活跃 ${AppFormatters.dateTime(date)}'),
        trailing: Text(AppFormatters.percent(entry.cachedProgress ?? 0)),
        onTap: onTap,
      ),
    );
  }
}
