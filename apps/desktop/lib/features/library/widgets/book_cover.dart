import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

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
    final imageFile = path == null || path.isEmpty ? null : File(path);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = math.max(1, (width * devicePixelRatio).round());
    final cacheHeight = math.max(1, (height * devicePixelRatio).round());

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: imageFile != null
            ? Image.file(
                imageFile,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.medium,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame == null && !wasSynchronouslyLoaded) {
                    return _placeholder(context);
                  }
                  return child;
                },
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
          context.l10n.noCover,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
