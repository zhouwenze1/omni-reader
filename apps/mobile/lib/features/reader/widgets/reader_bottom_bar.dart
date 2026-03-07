import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import 'reader_progress_slider.dart';

class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.progress,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.progressActiveColor,
    required this.progressInactiveColor,
    this.onProgressChangeStart,
    required this.onProgressChanged,
    required this.onProgressChangeEnd,
    required this.onPrev,
    required this.onNext,
    required this.onOpenToc,
    required this.onOpenAnnotations,
    required this.onOpenSettings,
    this.onOpenMore,
  });

  final double progress;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final Color progressActiveColor;
  final Color progressInactiveColor;
  final ValueChanged<double>? onProgressChangeStart;
  final ValueChanged<double> onProgressChanged;
  final ValueChanged<double> onProgressChangeEnd;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onOpenToc;
  final VoidCallback onOpenAnnotations;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = <Widget>[
      _ReaderActionButton(
        icon: Icons.chevron_left,
        label: l10n.previousPage,
        onPressed: onPrev,
        foregroundColor: foregroundColor,
      ),
      _ReaderActionButton(
        icon: Icons.menu_book_outlined,
        label: l10n.toc,
        onPressed: onOpenToc,
        foregroundColor: foregroundColor,
      ),
      _ReaderActionButton(
        icon: Icons.collections_bookmark_outlined,
        label: l10n.annotations,
        onPressed: onOpenAnnotations,
        foregroundColor: foregroundColor,
      ),
      _ReaderActionButton(
        icon: Icons.tune,
        label: l10n.readerSettings,
        onPressed: onOpenSettings,
        foregroundColor: foregroundColor,
      ),
      if (onOpenMore != null)
        _ReaderActionButton(
          icon: Icons.more_horiz,
          label: l10n.more,
          onPressed: onOpenMore!,
          foregroundColor: foregroundColor,
        ),
      _ReaderActionButton(
        icon: Icons.chevron_right,
        label: l10n.nextPage,
        onPressed: onNext,
        foregroundColor: foregroundColor,
      ),
    ];

    return SafeArea(
      top: false,
      child: Material(
        color: backgroundColor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: borderColor),
            ),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReaderProgressSlider(
                  value: progress,
                  activeColor: progressActiveColor,
                  inactiveColor: progressInactiveColor,
                  onChangeStart: onProgressChangeStart,
                  onChanged: onProgressChanged,
                  onChangeEnd: onProgressChangeEnd,
                ),
                const SizedBox(height: 4),
                Row(
                  children: actions
                      .map((action) => Expanded(child: action))
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderActionButton extends StatelessWidget {
  const _ReaderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
