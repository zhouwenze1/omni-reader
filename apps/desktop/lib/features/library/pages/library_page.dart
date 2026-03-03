import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure_data/data.dart';
import 'package:intl/intl.dart';

import '../../../di/providers.dart';
import '../../../di/repositories_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routes/route_paths.dart';
import '../../settings/controller/settings_controller.dart';
import '../controller/library_controller.dart';
import '../controller/library_state.dart';
import '../widgets/book_cover.dart';
import '../widgets/book_grid_item.dart';
import '../widgets/book_list_item.dart';
import '../widgets/book_meta_row.dart';
import '../widgets/shelf_toolbar.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(desktopLibraryControllerProvider);
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
    final dataModule = ref.watch(dataModuleProvider);
    final currentCollectionLabel = _currentCollectionLabel(context, state);

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: () => _importBook(context, ref),
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(l10n.importBook),
            ),
          ),
        ],
      ),
      body: switch (state.status) {
        LibraryPageStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        LibraryPageStatus.error => Center(
            child: Text(state.errorMessage ?? l10n.loadingFailed),
          ),
        LibraryPageStatus.empty || LibraryPageStatus.normal => Row(
            children: [
              if (state.isFilterPanelVisible)
                SizedBox(
                  width: 240,
                  child: _buildFilterPanel(context, state, controller),
                ),
              _buildFilterEdgeHandle(context, state, controller),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ShelfToolbar(
                        sortMode: state.sortMode,
                        viewMode: state.viewMode,
                        onSortChanged: (mode) => controller.setSortMode(mode),
                        onViewModeChanged: (mode) =>
                            controller.setViewMode(mode),
                        onImport: () => _importBook(context, ref),
                        onRefresh: () => controller.refresh(),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: state.filteredItems.isEmpty
                            ? Center(child: Text(l10n.emptyLibrary))
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
                child: _buildDetailPanel(context, ref, state, dataModule),
              ),
            ],
          ),
      },
    );
  }

  Widget _buildFilterEdgeHandle(
    BuildContext context,
    DesktopLibraryState state,
    DesktopLibraryController controller,
  ) {
    final l10n = context.l10n;
    final visible = state.isFilterPanelVisible;
    return SizedBox(
      width: 20,
      child: Center(
        child: Tooltip(
          message: visible ? l10n.collapseFilterPanel : l10n.expandFilterPanel,
          child: Material(
            elevation: 1,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: controller.toggleFilterPanel,
              child: SizedBox(
                width: 16,
                height: 64,
                child: Icon(
                  visible ? Icons.chevron_left : Icons.chevron_right,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel(
    BuildContext context,
    DesktopLibraryState state,
    DesktopLibraryController controller,
  ) {
    final l10n = context.l10n;
    final selectedFormat =
        state.filters.formats.isEmpty ? 'ALL' : state.filters.formats.first;
    final selectedCategory = state.filters.categoryIds.isEmpty
        ? 'ALL'
        : state.filters.categoryIds.first;
    final selectedCollectionId = state.selectedCollectionId;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.filter, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Text(l10n.format),
        const SizedBox(height: 6),
        _compactDropdown<String>(
          value: selectedFormat,
          items: [
            DropdownMenuItem(value: 'ALL', child: Text(l10n.all)),
            ...state.availableFormats.map(
              (format) => DropdownMenuItem(
                value: format,
                child: Text(format.toUpperCase()),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == 'ALL') {
              controller.setFormats(<String>{});
              return;
            }
            controller.setFormats(<String>{value});
          },
        ),
        const SizedBox(height: 10),
        Text(l10n.progress),
        const SizedBox(height: 6),
        _compactDropdown<LibraryProgressBucket>(
          value: state.filters.progress,
          items: [
            DropdownMenuItem(
              value: LibraryProgressBucket.all,
              child: Text(l10n.all),
            ),
            DropdownMenuItem(
              value: LibraryProgressBucket.notStarted,
              child: Text(l10n.notStarted),
            ),
            DropdownMenuItem(
              value: LibraryProgressBucket.inProgress,
              child: Text(l10n.inProgress),
            ),
            DropdownMenuItem(
              value: LibraryProgressBucket.completed,
              child: Text(l10n.completed),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              controller.setProgressBucket(value);
            }
          },
        ),
        const SizedBox(height: 10),
        Text(l10n.category),
        const SizedBox(height: 6),
        _compactDropdown<String>(
          value: selectedCategory,
          items: [
            DropdownMenuItem(value: 'ALL', child: Text(l10n.all)),
            ...state.availableCategories.map(
              (category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == 'ALL') {
              controller.setCategories(<String>{});
              return;
            }
            controller.setCategories(<String>{value});
          },
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 6),
        Text(l10n.collection),
        const SizedBox(height: 6),
        _compactDropdown<int?>(
          value: selectedCollectionId,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(l10n.allCollections),
            ),
            ...state.collections.map(
              (collection) => DropdownMenuItem<int?>(
                value: collection.id,
                child: Text(collection.name),
              ),
            ),
          ],
          onChanged: (value) => controller.setCollectionFilter(value),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showCreateCollectionDialog(context, controller),
          icon: const Icon(Icons.add),
          label: Text(l10n.newCollection),
        ),
        OutlinedButton.icon(
          onPressed: () => _showManageCollectionsDialog(context, controller),
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(l10n.manageCollection),
        ),
      ],
    );
  }

  Widget _compactDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                itemHeight: kMinInteractiveDimension,
                menuMaxHeight: 260,
                menuWidth: width,
                borderRadius: BorderRadius.circular(8),
                onChanged: onChanged,
                items: items,
              ),
            ),
          ),
        );
      },
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
        mainAxisExtent: 236,
      ),
      itemBuilder: (context, index) {
        final entry = state.filteredItems[index];
        return BookGridItem(
          entry: entry,
          coverPath: _resolveCoverPath(dataModule, entry),
          selected: state.selectedBookUid == entry.bookUid,
          onTap: () => controller.selectBook(entry.bookUid),
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
          coverPath: _resolveCoverPath(dataModule, entry),
          selected: state.selectedBookUid == entry.bookUid,
          onTap: () => controller.selectBook(entry.bookUid),
        );
      },
    );
  }

  Widget _buildDetailPanel(
    BuildContext context,
    WidgetRef ref,
    DesktopLibraryState state,
    DataModule dataModule,
  ) {
    final l10n = context.l10n;
    final entry = state.selectedItem;
    if (entry == null) {
      return Center(child: Text(l10n.selectBookToViewDetail));
    }

    final progress = ((entry.cachedProgress ?? 0) * 100).toStringAsFixed(1);
    final lastOpened = entry.lastOpenedAt;
    final controller = ref.read(desktopLibraryControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: BookCover(
              filePath: _resolveCoverPath(dataModule, entry),
              width: 140,
              height: 200,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            entry.title,
            style: Theme.of(context).textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          BookMetaRow(label: l10n.author, value: entry.authors.join(' · ')),
          BookMetaRow(label: l10n.format, value: entry.format.toUpperCase()),
          BookMetaRow(label: l10n.progress, value: '$progress%'),
          BookMetaRow(
              label: l10n.category,
              value: entry.categoryId ?? l10n.uncategorized),
          BookMetaRow(
            label: l10n.importedAt,
            value: _formatDate(context, entry.importedAt),
          ),
          BookMetaRow(
            label: l10n.lastOpened,
            value: lastOpened == null ? '-' : _formatDate(context, lastOpened),
          ),
          const SizedBox(height: 10),
          Text(l10n.collection, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _buildCollectionChips(state, entry, controller, l10n),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _showBookCollectionsDialog(
                context,
                controller,
                entry,
                state,
              ),
              icon: const Icon(Icons.playlist_add),
              label: Text(l10n.addOrRemoveCollection),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      context.push(RoutePaths.reader(entry.bookUid)),
                  child: Text(l10n.continueReading),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(RoutePaths.toc(entry.bookUid)),
                  child: Text(l10n.openToc),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteBook(context, controller, entry.bookUid),
              label: Text(l10n.deleteBook),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCollectionChips(
    DesktopLibraryState state,
    LibraryIndexEntry entry,
    DesktopLibraryController controller,
    AppLocalizations l10n,
  ) {
    final belongedIds = state.collectionsOfBook(entry.bookUid);
    if (belongedIds.isEmpty) {
      return [Text(l10n.noCollectionAdded)];
    }
    return state.collections
        .where((collection) => belongedIds.contains(collection.id))
        .map(
          (collection) => InputChip(
            label: Text(collection.name),
            onDeleted: () async {
              await controller.removeBookFromCollection(
                collection.id,
                entry.bookUid,
              );
            },
          ),
        )
        .toList();
  }

  Future<void> _showCreateCollectionDialog(
    BuildContext context,
    DesktopLibraryController controller,
  ) async {
    final l10n = context.l10n;
    final input = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newCollection),
        content: TextField(
          controller: input,
          decoration: InputDecoration(hintText: l10n.inputCollectionName),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.create),
          ),
        ],
      ),
    );
    if (created == true) {
      await controller.createCollection(input.text);
    }
  }

  Future<void> _showRenameCollectionDialog(
    BuildContext context,
    DesktopLibraryController controller,
    Collection collection,
  ) async {
    final l10n = context.l10n;
    final input = TextEditingController(text: collection.name);
    final rename = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameCollection),
        content: TextField(
          controller: input,
          decoration: InputDecoration(hintText: l10n.inputCollectionNewName),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (rename == true) {
      await controller.renameCollection(collection.id, input.text);
    }
  }

  Future<void> _showManageCollectionsDialog(
    BuildContext context,
    DesktopLibraryController controller,
  ) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, __) {
          final state = ref.watch(desktopLibraryControllerProvider);
          return AlertDialog(
            title: Text(l10n.manageCollection),
            content: SizedBox(
              width: 420,
              child: state.collections.isEmpty
                  ? Center(child: Text(l10n.noCollectionYet))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: state.collections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final collection = state.collections[index];
                        final count =
                            state.collectionBookUids[collection.id]?.length ??
                                0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(collection.name),
                          subtitle: Text(l10n.booksCount(count)),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: l10n.renameCollection,
                                onPressed: () => _showRenameCollectionDialog(
                                  context,
                                  controller,
                                  collection,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                onPressed: () async {
                                  await controller
                                      .deleteCollection(collection.id);
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    _showCreateCollectionDialog(context, controller),
                child: Text(l10n.newCollection),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showBookCollectionsDialog(
    BuildContext context,
    DesktopLibraryController controller,
    LibraryIndexEntry entry,
    DesktopLibraryState state,
  ) async {
    final l10n = context.l10n;
    final localSelected = {...state.collectionsOfBook(entry.bookUid)};

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.collectionsForBookTitle(entry.title)),
            content: SizedBox(
              width: 380,
              child: state.collections.isEmpty
                  ? Text(l10n.noCollectionCreateFirst)
                  : ListView(
                      shrinkWrap: true,
                      children: state.collections.map((collection) {
                        final selected = localSelected.contains(collection.id);
                        return CheckboxListTile(
                          value: selected,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(collection.name),
                          onChanged: (value) async {
                            final shouldContain = value ?? false;
                            setDialogState(() {
                              if (shouldContain) {
                                localSelected.add(collection.id);
                              } else {
                                localSelected.remove(collection.id);
                              }
                            });
                            await controller.toggleBookInCollection(
                              collectionId: collection.id,
                              bookUid: entry.bookUid,
                              shouldContain: shouldContain,
                            );
                          },
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    _showCreateCollectionDialog(context, controller),
                child: Text(l10n.newCollection),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.done),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _resolveCoverPath(DataModule dataModule, LibraryIndexEntry entry) {
    final rel = entry.coverRelPath;
    if (rel == null || rel.isEmpty) {
      return null;
    }
    return '${dataModule.storagePaths.libraryRoot.path}/${entry.bookUid}/$rel';
  }

  String _formatDate(BuildContext context, DateTime value) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('yyyy-MM-dd', localeTag).format(value);
  }

  String _currentCollectionLabel(
    BuildContext context,
    DesktopLibraryState state,
  ) {
    final l10n = context.l10n;
    final selectedId = state.selectedCollectionId;
    if (selectedId == null) {
      return l10n.allCollections;
    }
    for (final collection in state.collections) {
      if (collection.id == selectedId) {
        return collection.name;
      }
    }
    return l10n.unknownCollection;
  }

  Future<void> _deleteBook(
    BuildContext context,
    DesktopLibraryController controller,
    String bookUid,
  ) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.deleteBook(bookUid);
    }
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const [
        'epub',
        'pdf',
        'ldf',
        'zip',
        'cbz',
        'webpub',
        'lpf',
        'mp3',
        'm4b',
      ],
    );

    final path = picked?.files.single.path;
    if (path == null) {
      return;
    }

    final appSettings = ref.read(settingsControllerProvider).app;
    final result = await ref.read(importRepositoryProvider).importBookFromFile(
          path,
          debugMode: appSettings.debugImport,
        );

    await ref.read(desktopLibraryControllerProvider.notifier).refresh();
    if (!context.mounted) {
      return;
    }

    final message = result.alreadyImported
        ? '${l10n.alreadyImported}: ${result.bookUid}'
        : result.task.status == ImportTaskStatus.success
            ? '${l10n.imported}: ${result.bookUid}'
            : '${l10n.importFailed}: ${result.task.errorMessage}';

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
