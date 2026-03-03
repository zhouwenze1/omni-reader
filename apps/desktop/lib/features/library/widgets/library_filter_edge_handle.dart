import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class LibraryFilterEdgeHandle extends StatelessWidget {
  const LibraryFilterEdgeHandle({
    super.key,
    required this.isVisible,
    required this.onToggle,
  });

  final bool isVisible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: 20,
      child: Center(
        child: Tooltip(
          message:
              isVisible ? l10n.collapseFilterPanel : l10n.expandFilterPanel,
          child: Material(
            elevation: 1,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onToggle,
              child: SizedBox(
                width: 16,
                height: 64,
                child: Icon(
                  isVisible ? Icons.chevron_left : Icons.chevron_right,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
