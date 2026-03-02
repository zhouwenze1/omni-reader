import 'dart:io';

import 'package:flutter/material.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.filePath,
    this.width = 70,
    this.height = 100,
    this.radius = 8,
  });

  final String? filePath;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = filePath;
    final hasCover = path != null && path.isNotEmpty && File(path).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: hasCover
            ? Image.file(File(path), fit: BoxFit.cover)
            : const Icon(Icons.menu_book_outlined),
      ),
    );
  }
}
