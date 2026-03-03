import 'package:flutter/material.dart';

class LibrarySelectionActionBar extends StatelessWidget {
  const LibrarySelectionActionBar({
    super.key,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClear,
    required this.onMoveToCollection,
    required this.onDeleteSelected,
    required this.onExit,
  });

  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onMoveToCollection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text('Selected $selectedCount'),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onSelectAll,
            child: const Text('Select all'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: selectedCount == 0 ? null : onMoveToCollection,
            icon: const Icon(Icons.drive_file_move_outline),
            label: const Text('Move to collection'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: selectedCount == 0 ? null : onDeleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete selected'),
          ),
          const Spacer(),
          TextButton(
            onPressed: onExit,
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
