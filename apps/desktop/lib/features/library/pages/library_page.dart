import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure_data/data.dart';

import '../../../di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routes/route_paths.dart';
import '../controller/library_controller.dart';
import '../controller/library_state.dart';
import '../widgets/book_grid_item.dart';
import '../widgets/book_list_item.dart';
import '../widgets/library_detail_panel.dart';
import '../widgets/library_filter_edge_handle.dart';
import '../widgets/library_filter_panel.dart';
import '../widgets/library_selection_action_bar.dart';
import '../widgets/shelf_toolbar.dart';
import 'library_page_actions.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(desktopLibraryControllerProvider);
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
    final dataModule = ref.watch(dataModuleProvider);
    final currentCollectionLabel =
        LibraryPageActions.currentCollectionLabel(context, state);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(l10n.libraryTitle),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                currentCollectionLabel,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
      body: switch (state.status) {
        LibraryPageStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        LibraryPageStatus.error =>
          Center(child: Text(state.errorMessage ?? l10n.loadingFailed)),
        LibraryPageStatus.empty ||
        LibraryPageStatus.normal =>
          _buildMainLayout(context, ref, state, controller, dataModule),
      },
    );
  }

  Widget _buildMainLayout(
    BuildContext context,
    WidgetRef ref,
    DesktopLibraryState state,
    DesktopLibraryController controller,
    DataModule dataModule,
  ) {
    return Row(
      children: [
        if (state.isFilterPanelVisible)
          SizedBox(
            width: 248,
            child: LibraryFilterPanel(
              state: state,
              controller: controller,
              onCreateCollection: () =>
                  LibraryPageActions.showCreateCollectionDialog(
                      context, controller),
              onManageCollections: () =>
                  LibraryPageActions.showManageCollectionsDialog(
                      context, controller),
            ),
          ),
        LibraryFilterEdgeHandle(
          isVisible: state.isFilterPanelVisible,
          onToggle: controller.toggleFilterPanel,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ShelfToolbar(
                  sortMode: state.sortMode,
                  viewMode: state.viewMode,
                  selectionMode: state.isSelectionMode,
                  selectedCount: state.selectedBookUids.length,
                  onSortChanged: controller.setSortMode,
                  onViewModeChanged: controller.setViewMode,
                  onToggleSelectionMode: () {
                    if (state.isSelectionMode) {
                      controller.exitSelectionMode();
                    } else {
                      controller.enterSelectionMode();
                    }
                  },
                  onImport: () => LibraryPageActions.importBooks(context, ref),
                  onRefresh: controller.refresh,
                ),
                if (state.isSelectionMode) ...[
                  const SizedBox(height: 8),
                  LibrarySelectionActionBar(
                    selectedCount: state.selectedBookUids.length,
                    onSelectAll: controller.selectAllVisible,
                    onClear: controller.clearSelectedBooks,
                    onMoveToCollection: () =>
                        LibraryPageActions.showMoveSelectedDialog(
                            context, controller, state),
                    onDeleteSelected: () =>
                        LibraryPageActions.deleteSelectedBooks(
                            context, controller, state),
                    onExit: controller.exitSelectionMode,
                  ),
                ],
                const SizedBox(height: 10),
                Expanded(
                  child: state.filteredItems.isEmpty
                      ? Center(child: Text(context.l10n.emptyLibrary))
                      : (state.viewMode == LibraryViewMode.grid
                          ? _buildGrid(state, controller, dataModule)
                          : _buildList(state, controller, dataModule)),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 320,
          child: LibraryDetailPanel(
            state: state,
            coverPathResolver: (entry) =>
                LibraryPageActions.resolveCoverPath(dataModule, entry),
            formatDate: (value) =>
                LibraryPageActions.formatDate(context, value),
            onContinueReading: (uid) => context.push(RoutePaths.reader(uid)),
            onOpenToc: (uid) => context.push(RoutePaths.toc(uid)),
            onDeleteBook: (uid) =>
                LibraryPageActions.deleteBook(context, controller, uid),
            onShowBookCollections: (entry) =>
                LibraryPageActions.showBookCollectionsDialog(
                    context, controller, entry, state),
            onRemoveBookFromCollection: controller.removeBookFromCollection,
            onMoveSelected: () => LibraryPageActions.showMoveSelectedDialog(
              context,
              controller,
              state,
            ),
            onDeleteSelected: () => LibraryPageActions.deleteSelectedBooks(
              context,
              controller,
              state,
            ),
            onExitSelectionMode: controller.exitSelectionMode,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(
    DesktopLibraryState state,
    DesktopLibraryController controller,
    DataModule dataModule,
  ) {
    return GridView.builder(
      itemCount: state.filteredItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 216,
      ),
      itemBuilder: (context, index) {
        final entry = state.filteredItems[index];
        return BookGridItem(
          entry: entry,
          coverPath: LibraryPageActions.resolveCoverPath(dataModule, entry),
          selected: state.selectedBookUid == entry.bookUid,
          selectionMode: state.isSelectionMode,
          multiSelected: state.selectedBookUids.contains(entry.bookUid),
          onTap: () {
            if (state.isSelectionMode) {
              controller.toggleSelectedBook(entry.bookUid);
              return;
            }
            controller.selectBook(entry.bookUid);
          },
          onLongPress: () =>
              controller.enterSelectionMode(seedBookUid: entry.bookUid),
        );
      },
    );
  }

  Widget _buildList(
    DesktopLibraryState state,
    DesktopLibraryController controller,
    DataModule dataModule,
  ) {
    return ListView.separated(
      itemCount: state.filteredItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = state.filteredItems[index];
        return BookListItem(
          entry: entry,
          coverPath: LibraryPageActions.resolveCoverPath(dataModule, entry),
          selected: state.selectedBookUid == entry.bookUid,
          selectionMode: state.isSelectionMode,
          multiSelected: state.selectedBookUids.contains(entry.bookUid),
          onTap: () {
            if (state.isSelectionMode) {
              controller.toggleSelectedBook(entry.bookUid);
              return;
            }
            controller.selectBook(entry.bookUid);
          },
          onLongPress: () =>
              controller.enterSelectionMode(seedBookUid: entry.bookUid),
        );
      },
    );
  }
}
