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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(l10n.selectedBooksCount(selectedCount)),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onSelectAll,
            child: Text(l10n.selectAll),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onClear,
            child: Text(l10n.clear),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : onAddToCollection,
            icon: const Icon(Icons.playlist_add),
            label: Text(l10n.addToCollection),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : onMoveToCollection,
            icon: const Icon(Icons.drive_file_move_outline),
            label: Text(l10n.moveToCollection),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: selectedCount == 0 ? null : onDeleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.deleteSelected),
          ),
          const Spacer(),
          TextButton(
            onPressed: onExit,
            child: Text(l10n.exit),
          ),
        ],
      ),
    );
  }
}
