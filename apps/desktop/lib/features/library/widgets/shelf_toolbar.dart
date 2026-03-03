import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

import '../../../l10n/app_localizations.dart';
import 'sort_menu.dart';

class ShelfToolbar extends StatelessWidget {
  const ShelfToolbar({
    super.key,
    required this.sortMode,
    required this.viewMode,
    required this.onSortChanged,
    required this.onViewModeChanged,
    required this.onImport,
    required this.onRefresh,
  });

  final LibrarySortMode sortMode;
  final LibraryViewMode viewMode;
  final ValueChanged<LibrarySortMode> onSortChanged;
  final ValueChanged<LibraryViewMode> onViewModeChanged;
  final VoidCallback onImport;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${l10n.sort}:'),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: SortMenu(value: sortMode, onChanged: onSortChanged),
        ),
        const SizedBox(width: 12),
        SegmentedButton<LibraryViewMode>(
          segments: [
            ButtonSegment(
              value: LibraryViewMode.grid,
              icon: const Icon(Icons.grid_view),
              label: Text(l10n.grid),
            ),
            ButtonSegment(
              value: LibraryViewMode.list,
              icon: const Icon(Icons.view_list),
              label: Text(l10n.list),
            ),
          ],
          selected: {viewMode},
          onSelectionChanged: (next) => onViewModeChanged(next.first),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          tooltip: l10n.refresh,
        ),
        FilledButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.file_upload_outlined),
          label: Text(l10n.importBook),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1080) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: controls,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: actions,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: controls,
              ),
            ),
            const SizedBox(width: 8),
            actions,
          ],
        );
      },
    );
  }
}
