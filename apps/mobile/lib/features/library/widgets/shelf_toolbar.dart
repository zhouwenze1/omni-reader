import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

class ShelfToolbar extends StatelessWidget {
  const ShelfToolbar({
    super.key,
    required this.sortMode,
    required this.viewMode,
    required this.filtersExpanded,
    required this.activeFilterCount,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onToggleFilters,
  });

  final LibrarySortMode sortMode;
  final LibraryViewMode viewMode;
  final bool filtersExpanded;
  final int activeFilterCount;
  final ValueChanged<LibrarySortMode> onSortChanged;
  final ValueChanged<LibraryViewMode> onViewModeChanged;
  final VoidCallback onToggleFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<LibrarySortMode>(
              tooltip: '排序',
              initialValue: sortMode,
              onSelected: onSortChanged,
              itemBuilder: (context) {
                return LibrarySortMode.values.map((mode) {
                  return PopupMenuItem<LibrarySortMode>(
                    value: mode,
                    child: Text(_sortLabel(mode)),
                  );
                }).toList(growable: false);
              },
              child: _ToolbarPill(
                icon: Icons.swap_vert_rounded,
                label: _sortLabel(sortMode),
                foregroundColor: colorScheme.onSurface,
                backgroundColor: colorScheme.surface,
                borderColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 94,
            child: SegmentedButton<LibraryViewMode>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              segments: const [
                ButtonSegment<LibraryViewMode>(
                  value: LibraryViewMode.grid,
                  icon: Icon(Icons.grid_view_rounded, size: 18),
                ),
                ButtonSegment<LibraryViewMode>(
                  value: LibraryViewMode.list,
                  icon: Icon(Icons.view_agenda_outlined, size: 18),
                ),
              ],
              selected: <LibraryViewMode>{viewMode},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }
                onViewModeChanged(selection.first);
              },
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onToggleFilters,
            icon: Icon(
              filtersExpanded
                  ? Icons.filter_alt_off_outlined
                  : Icons.filter_alt_outlined,
              size: 18,
            ),
            label: Text(
              activeFilterCount > 0 ? '筛选 $activeFilterCount' : '筛选',
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(LibrarySortMode mode) {
    return switch (mode) {
      LibrarySortMode.recentRead => '最近阅读',
      LibrarySortMode.importedAt => '最近导入',
      LibrarySortMode.name => '名称 A-Z',
    };
  }
}

class _ToolbarPill extends StatelessWidget {
  const _ToolbarPill({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: foregroundColor,
          ),
        ],
      ),
    );
  }
}
