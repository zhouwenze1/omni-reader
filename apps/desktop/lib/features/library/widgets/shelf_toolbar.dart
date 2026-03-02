import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import 'sort_menu.dart';

class ShelfToolbar extends StatelessWidget {
  const ShelfToolbar({
    super.key,
    required this.sortMode,
    required this.viewMode,
    required this.filterPanelVisible,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onToggleFilterPanel,
    required this.onImport,
    required this.onRefresh,
  });

  final LibrarySortMode sortMode;
  final LibraryViewMode viewMode;
  final bool filterPanelVisible;
  final ValueChanged<LibrarySortMode> onSortChanged;
  final ValueChanged<LibraryViewMode> onViewModeChanged;
  final VoidCallback onToggleFilterPanel;
  final VoidCallback onImport;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('排序:'),
        const SizedBox(width: 8),
        SortMenu(value: sortMode, onChanged: onSortChanged),
        const SizedBox(width: 12),
        SegmentedButton<LibraryViewMode>(
          segments: const [
            ButtonSegment(
              value: LibraryViewMode.grid,
              icon: Icon(Icons.grid_view),
              label: Text('网格'),
            ),
            ButtonSegment(
              value: LibraryViewMode.list,
              icon: Icon(Icons.view_list),
              label: Text('列表'),
            ),
          ],
          selected: {viewMode},
          onSelectionChanged: (next) => onViewModeChanged(next.first),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: filterPanelVisible ? '收起筛选栏' : '展开筛选栏',
          onPressed: onToggleFilterPanel,
          icon: Icon(
            filterPanelVisible ? Icons.tune : Icons.tune_outlined,
          ),
        ),
        const Spacer(),
        IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
        FilledButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('导入'),
        ),
      ],
    );
  }
}
