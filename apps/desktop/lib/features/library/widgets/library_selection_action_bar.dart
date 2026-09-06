import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class LibrarySelectionActionBar extends StatelessWidget {
  const LibrarySelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClear,
    required this.onAddToCollection,
    required this.onMoveToCollection,
    required this.onDeleteSelected,
    required this.onExit,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onAddToCollection;
  final VoidCallback onMoveToCollection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Wrap 而非 Row:窄窗口/高 DPI 下按钮放不下时会自动换行,避免互相叠压。
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(l10n.selectedBooksCount(selectedCount)),
          ),
          OutlinedButton(
            onPressed: onSelectAll,
            child: Text(l10n.selectAll),
          ),
          OutlinedButton(
            onPressed: onClear,
            child: Text(l10n.clear),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : onAddToCollection,
            icon: const Icon(Icons.playlist_add),
            label: Text(l10n.addToCollection),
          ),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : onMoveToCollection,
            icon: const Icon(Icons.drive_file_move_outline),
            label: Text(l10n.moveToCollection),
          ),
          FilledButton.tonalIcon(
            onPressed: selectedCount == 0 ? null : onDeleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.deleteSelected),
          ),
          TextButton(
            onPressed: onExit,
            child: Text(l10n.exit),
          ),
        ],
      ),
    );
  }
}
