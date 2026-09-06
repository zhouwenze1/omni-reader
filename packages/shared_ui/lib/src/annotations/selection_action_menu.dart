import 'package:flutter/material.dart';

import 'annotation_palette.dart';

class SelectionActionMenu extends StatelessWidget {
  const SelectionActionMenu({
    super.key,
    required this.onColor,
    required this.onNote,
    required this.onCopy,
    this.onDelete,
    this.selectedColor,
  });

  final ValueChanged<String> onColor;
  final VoidCallback onNote;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;
  final String? selectedColor;

  @override
  Widget build(BuildContext context) {
    final isChinese = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('zh');
    final colorLabels = <String, String>{
      AnnotationPalette.yellow:
          isChinese ? '黄色高亮' : 'Yellow highlight',
      AnnotationPalette.green: isChinese ? '绿色高亮' : 'Green highlight',
      AnnotationPalette.blue: isChinese ? '蓝色高亮' : 'Blue highlight',
      AnnotationPalette.pink: isChinese ? '粉色高亮' : 'Pink highlight',
      AnnotationPalette.purple: isChinese ? '紫色高亮' : 'Purple highlight',
    };
    final colors = AnnotationPalette.colors.map((color) {
      final selected = color == selectedColor;
      return IconButton(
        tooltip: colorLabels[color] ?? color,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
        onPressed: () => onColor(color),
        icon: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AnnotationPalette.toColor(color),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.black26,
              width: selected ? 2.5 : 1,
            ),
          ),
        ),
      );
    }).toList();

    final noteLabel = isChinese ? '添加笔记' : 'Add note';
    final copyLabel = isChinese ? '复制' : 'Copy';
    final deleteLabel = isChinese ? '删除高亮' : 'Delete highlight';

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...colors,
              const SizedBox(width: 4),
              IconButton(
                tooltip: noteLabel,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: onNote,
                icon: const Icon(Icons.edit_note_outlined),
              ),
              IconButton(
                tooltip: copyLabel,
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: deleteLabel,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  splashRadius: 18,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Offset computeMenuOffset({
  required Rect selectionRect,
  required Size viewport,
  required Size menuSize,
  double margin = 8,
}) {
  final maxX =
      (viewport.width - menuSize.width - margin).clamp(margin, double.infinity);
  final x = (selectionRect.center.dx - menuSize.width / 2).clamp(margin, maxX);
  final above = selectionRect.top - menuSize.height - margin;
  final below = selectionRect.bottom + margin;
  final maxY = (viewport.height - menuSize.height - margin)
      .clamp(margin, double.infinity);
  final y = above >= margin
      ? above
      : below + menuSize.height <= viewport.height - margin
          ? below
          : maxY;
  return Offset(x.toDouble(), y.toDouble());
}

Rect unionRects(Iterable<Rect> rects) {
  final values = rects.toList(growable: false);
  if (values.isEmpty) {
    return Rect.zero;
  }
  var left = values.first.left;
  var top = values.first.top;
  var right = values.first.right;
  var bottom = values.first.bottom;
  for (final value in values.skip(1)) {
    left = left < value.left ? left : value.left;
    top = top < value.top ? top : value.top;
    right = right > value.right ? right : value.right;
    bottom = bottom > value.bottom ? bottom : value.bottom;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}
