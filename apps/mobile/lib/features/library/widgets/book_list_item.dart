import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import 'book_cover.dart';
import 'progress_badge.dart';

class BookListItem extends StatelessWidget {
  const BookListItem({
    super.key,
    required this.entry,
    required this.coverPath,
    required this.onTap,
  });

  final LibraryIndexEntry entry;
  final String? coverPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: BookCover(filePath: coverPath, width: 44, height: 62),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(entry.authors.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ProgressBadge(progress: entry.cachedProgress ?? 0),
    );
  }
}
