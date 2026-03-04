import 'dart:io';

import 'package:flutter/material.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.filePath,
    this.width = 82,
    this.height = 116,
    this.radius = 10,
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
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.menu_book_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 6),
        Text(
          'No Cover',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
