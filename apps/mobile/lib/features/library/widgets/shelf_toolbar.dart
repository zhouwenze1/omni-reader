import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

class ShelfToolbar extends StatelessWidget {
  const ShelfToolbar({
    super.key,
    required this.sortMode,
    required this.viewMode,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onImport,
  });

  final LibrarySortMode sortMode;
  final LibraryViewMode viewMode;
  final ValueChanged<LibrarySortMode> onSortChanged;
  final ValueChanged<LibraryViewMode> onViewModeChanged;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DropdownButton<LibrarySortMode>(
          value: sortMode,
          onChanged: (next) {
            if (next != null) {
              onSortChanged(next);
            }
          },
          items: const [
            DropdownMenuItem(value: LibrarySortMode.recentRead, child: Text('最近阅读')),
            DropdownMenuItem(value: LibrarySortMode.importedAt, child: Text('最近导入')),
            DropdownMenuItem(value: LibrarySortMode.name, child: Text('名称 A-Z')),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => onViewModeChanged(LibraryViewMode.grid),
          icon: Icon(
            Icons.grid_view,
            color: viewMode == LibraryViewMode.grid
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
        IconButton(
          onPressed: () => onViewModeChanged(LibraryViewMode.list),
          icon: Icon(
            Icons.view_list,
            color: viewMode == LibraryViewMode.list
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('导入'),
        ),
      ],
    );
  }
}
