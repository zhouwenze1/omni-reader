import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure_data/data.dart';

import '../../../di/providers.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../import_center/pages/import_center_page.dart';
import '../controller/library_controller.dart';
import '../controller/library_state.dart';
import '../widgets/book_grid_item.dart';
import '../widgets/book_list_item.dart';
import '../widgets/shelf_toolbar.dart';
import 'library_search_page.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _filtersExpanded = false;
  final ScrollController _collectionStripController = ScrollController();
  final Map<int, GlobalKey> _collectionChipKeys = <int, GlobalKey>{};

  @override
  void dispose() {
    _collectionStripController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mobileLibraryControllerProvider);
    final controller = ref.read(mobileLibraryControllerProvider.notifier);
    final dataModule = ref.watch(dataModuleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.isSelectionMode
              ? '\u5df2\u9009 ${state.selectedBookUids.length} \u672c'
              : _buildLibraryTitle(state),
        ),
        actions: state.isSelectionMode
            ? <Widget>[
                IconButton(
                  tooltip: '\u5168\u9009',
                  onPressed:
                      state.items.isEmpty ? null : controller.selectAllVisible,
                  icon: const Icon(Icons.select_all_rounded),
                ),
                IconButton(
                  tooltip: '\u52a0\u5165\u5408\u96c6',
                  onPressed: state.selectedBookUids.isEmpty
                      ? null
                      : () => _showAddSelectedSheet(context, state, controller),
                  icon: const Icon(Icons.playlist_add),
                ),
                IconButton(
                  tooltip: '\u79fb\u52a8\u5230\u5408\u96c6',
                  onPressed: state.selectedBookUids.isEmpty
                      ? null
                      : () =>
                          _showMoveSelectedSheet(context, state, controller),
                  icon: const Icon(Icons.drive_file_move_outline),
                ),
                IconButton(
                  tooltip: '\u5220\u9664',
                  onPressed: state.selectedBookUids.isEmpty
                      ? null
                      : () =>
                          _confirmDeleteSelected(context, state, controller),
                  icon: const Icon(Icons.delete_outline),
                ),
                IconButton(
                  tooltip: '\u9000\u51fa',
                  onPressed: controller.exitSelectionMode,
                  icon: const Icon(Icons.close),
                ),
              ]
            : <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LibrarySearchPage(),
                    ),
                  ),
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  onPressed: () => _openImportCenter(context),
                  icon: const Icon(Icons.file_upload_outlined),
                ),
              ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: switch (state.status) {
          LibraryPageStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          LibraryPageStatus.error =>
            Center(child: Text(state.errorMessage ?? 'Load failed')),
          LibraryPageStatus.empty => _buildEmptyState(context, controller),
          LibraryPageStatus.normal => Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  _buildCollectionStrip(context, state, controller),
                  const SizedBox(height: 10),
                  ShelfToolbar(
                    sortMode: state.sortMode,
                    viewMode: state.viewMode,
                    filtersExpanded: _filtersExpanded,
                    activeFilterCount: _activeFilterCount(state.filters),
                    onSortChanged: controller.setSortMode,
                    onViewModeChanged: controller.setViewMode,
                    onToggleFilters: () {
                      setState(() {
                        _filtersExpanded = !_filtersExpanded;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _filtersExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child:
                                _buildFilterPanel(context, state, controller),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: state.items.isEmpty
                        ? EmptyView(
                            title:
                                '\u5f53\u524d\u5408\u96c6\u6ca1\u6709\u7b26\u5408\u6761\u4ef6\u7684\u4e66',
                            message:
                                '\u53ef\u4ee5\u5207\u6362\u5408\u96c6\uff0c\u6216\u6e05\u7a7a\u5f53\u524d\u7b5b\u9009\u6761\u4ef6\u3002',
                            action: TextButton(
                              onPressed: () async {
                                await controller.setFormats(const <String>{});
                                await controller.setProgressBucket(
                                  LibraryProgressBucket.all,
                                );
                                await controller.setCategories(
                                  const <String>{},
                                );
                              },
                              child: const Text('\u6e05\u7a7a\u7b5b\u9009'),
                            ),
                          )
                        : state.viewMode == LibraryViewMode.grid
                            ? GridView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: state.items.length,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.58,
                                ),
                                itemBuilder: (context, index) {
                                  final entry = state.items[index];
                                  return BookGridItem(
                                    entry: entry,
                                    coverPath: _coverPath(dataModule, entry),
                                    selectionMode: state.isSelectionMode,
                                    multiSelected: state.selectedBookUids
                                        .contains(entry.bookUid),
                                    onTap: () => _openBook(context, state, controller, entry.bookUid),
                                    onLongPress: () =>
                                        controller.enterSelectionMode(
                                      seedBookUid: entry.bookUid,
                                    ),
                                  );
                                },
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: state.items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final entry = state.items[index];
                                  return BookListItem(
                                    entry: entry,
                                    coverPath: _coverPath(dataModule, entry),
                                    selectionMode: state.isSelectionMode,
                                    multiSelected: state.selectedBookUids
                                        .contains(entry.bookUid),
                                    onTap: () => _openBook(context, state, controller, entry.bookUid),
                                    onLongPress: () =>
                                        controller.enterSelectionMode(
                                      seedBookUid: entry.bookUid,
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    MobileLibraryController controller,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              '\u6682\u65e0\u4e66\u7c4d\uff0c\u5148\u5bfc\u5165\u4e00\u672c\u4e66\u5427\u3002'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openImportCenter(context),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('\u5bfc\u5165\u4e66\u7c4d'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showCreateCollectionDialog(context, controller),
            child: const Text('\u65b0\u5efa\u5408\u96c6'),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionStrip(
    BuildContext context,
    MobileLibraryState state,
    MobileLibraryController controller,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: SingleChildScrollView(
        controller: _collectionStripController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...state.collections.map((collection) {
              final selected = collection.id == state.selectedCollectionId;
              final count =
                  state.collectionBookUids[collection.id]?.length ?? 0;
              final isDefault = collection.id == state.defaultCollectionId;
              final chipKey = _collectionChipKeys.putIfAbsent(
                collection.id,
                GlobalKey.new,
              );
              if (selected) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || !_collectionChipKeys.containsKey(collection.id)) {
                    return;
                  }
                  final key = _collectionChipKeys[collection.id];
                  final box = key?.currentContext?.findRenderObject();
                  if (box is! RenderBox) {
                    return;
                  }
                  final scrollable = Scrollable.of(key!.currentContext!);
                  final position = scrollable.position;
                  final renderBox = scrollable.context.findRenderObject() as RenderBox;
                  final viewportWidth = renderBox.size.width;
                  final chipOffset = box.localToGlobal(Offset.zero, ancestor: renderBox).dx;
                  final chipWidth = box.size.width;
                  if (chipOffset < 0 ||
                      chipOffset + chipWidth > viewportWidth) {
                    position.animateTo(
                      position.pixels +
                          chipOffset -
                          (viewportWidth - chipWidth) / 2,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                    );
                  }
                });
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onLongPress: isDefault
                      ? null
                      : () => _showCollectionLongPressMenu(
                            context,
                            controller,
                            collection,
                            count,
                          ),
                  child: ChoiceChip(
                    key: chipKey,
                    label: Text('${collection.name} ($count)'),
                    selected: selected,
                    onSelected: (_) =>
                        controller.setCollectionFilter(collection.id),
                  ),
                ),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('\u65b0\u5efa'),
              onPressed: () => _showCreateCollectionDialog(context, controller),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('\u7ba1\u7406'),
              onPressed: () => _showManageCollectionsSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCollectionLongPressMenu(
    BuildContext context,
    MobileLibraryController controller,
    Collection collection,
    int count,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  collection.name,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                subtitle: Text('\u5171 $count \u672c\u4e66'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('\u91cd\u547d\u540d'),
                onTap: () => Navigator.of(sheetContext).pop('rename'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('\u5220\u9664'),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) {
      return;
    }
    if (action == 'rename') {
      await _showRenameCollectionDialog(context, controller, collection);
    } else if (action == 'delete') {
      final confirmed = await _confirmDeleteCollection(
        context,
        collection,
        count,
      );
      if (confirmed == true) {
        await controller.deleteCollection(collection.id);
      }
    }
  }

  Widget _buildFilterPanel(
    BuildContext context,
    MobileLibraryState state,
    MobileLibraryController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formats = state.availableFormats.toList()..sort();
    final categories = state.availableCategories.toList()..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '\u7b5b\u9009',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (state.filters.hasAnyFilter)
                TextButton(
                  onPressed: () async {
                    await controller.setFormats(const <String>{});
                    await controller
                        .setProgressBucket(LibraryProgressBucket.all);
                    await controller.setCategories(const <String>{});
                  },
                  child: const Text('\u6e05\u7a7a'),
                ),
            ],
          ),
          _FilterGroup(
            title: '\u683c\u5f0f',
            children: [
              ChoiceChip(
                label: const Text('\u5168\u90e8'),
                selected: !state.filters.hasFormatFilter,
                onSelected: (_) => controller.setFormats(const <String>{}),
              ),
              ...formats.map((format) {
                final selected = state.filters.formats.contains(format);
                return ChoiceChip(
                  label: Text(format.toUpperCase()),
                  selected: selected,
                  onSelected: (_) => controller.setFormats(<String>{format}),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          _FilterGroup(
            title: '\u8fdb\u5ea6',
            children: LibraryProgressBucket.values.map((bucket) {
              return ChoiceChip(
                label: Text(_progressLabel(bucket)),
                selected: state.filters.progress == bucket,
                onSelected: (_) => controller.setProgressBucket(bucket),
              );
            }).toList(),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FilterGroup(
              title: '\u5206\u7c7b',
              children: [
                ChoiceChip(
                  label: const Text('\u5168\u90e8'),
                  selected: !state.filters.hasCategoryFilter,
                  onSelected: (_) => controller.setCategories(const <String>{}),
                ),
                ...categories.map((category) {
                  final selected = state.filters.categoryIds.contains(category);
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) =>
                        controller.setCategories(<String>{category}),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  int _activeFilterCount(LibraryFilters filters) {
    var count = 0;
    if (filters.hasFormatFilter) {
      count += 1;
    }
    if (filters.hasProgressFilter) {
      count += 1;
    }
    if (filters.hasCategoryFilter) {
      count += 1;
    }
    return count;
  }

  String _progressLabel(LibraryProgressBucket bucket) {
    return switch (bucket) {
      LibraryProgressBucket.all => '\u5168\u90e8\u8fdb\u5ea6',
      LibraryProgressBucket.notStarted => '\u672a\u5f00\u59cb',
      LibraryProgressBucket.inProgress => '\u9605\u8bfb\u4e2d',
      LibraryProgressBucket.completed => '\u5df2\u8bfb\u5b8c',
    };
  }

  String _buildLibraryTitle(MobileLibraryState state) {
    final selectedId = state.selectedCollectionId;
    for (final collection in state.collections) {
      if (collection.id == selectedId) {
        return '\u4e66\u67b6 \u00b7 ${collection.name}';
      }
    }
    return '\u4e66\u67b6';
  }

  String? _coverPath(DataModule dataModule, LibraryIndexEntry entry) {
    final rel = entry.coverRelPath;
    if (rel == null || rel.isEmpty) {
      return null;
    }
    return '${dataModule.storagePaths.libraryRoot.path}/${entry.bookUid}/$rel';
  }

  Future<void> _showCreateCollectionDialog(
    BuildContext context,
    MobileLibraryController controller,
  ) async {
    final input = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u65b0\u5efa\u5408\u96c6'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '\u8f93\u5165\u5408\u96c6\u540d\u79f0',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('\u521b\u5efa'),
          ),
        ],
      ),
    );
    if (created == true) {
      final name = input.text.trim();
      if (name.isEmpty) {
        return;
      }
      final collection = await controller.ensureCollection(name);
      await controller.setCollectionFilter(collection.id);
    }
  }

  Future<void> _showManageCollectionsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(mobileLibraryControllerProvider);
          final controller = ref.read(mobileLibraryControllerProvider.notifier);
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('\u7ba1\u7406\u5408\u96c6'),
                  subtitle: Text(
                      '\u53ef\u4ee5\u91cd\u547d\u540d\u6216\u5220\u9664\u81ea\u5b9a\u4e49\u5408\u96c6'),
                ),
                ...state.collections.map((collection) {
                  final isDefault = collection.id == state.defaultCollectionId;
                  final count =
                      state.collectionBookUids[collection.id]?.length ?? 0;
                  return ListTile(
                    leading: Icon(
                      isDefault
                          ? Icons.inbox_outlined
                          : Icons.folder_copy_outlined,
                    ),
                    title: Text(collection.name),
                    subtitle: Text('\u5171 $count \u672c\u4e66'),
                    trailing: isDefault
                        ? const Chip(label: Text('\u7cfb\u7edf'))
                        : PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'rename') {
                                await _showRenameCollectionDialog(
                                  context,
                                  controller,
                                  collection,
                                );
                              } else if (action == 'delete') {
                                final confirmed =
                                    await _confirmDeleteCollection(
                                  context,
                                  collection,
                                  count,
                                );
                                if (confirmed == true) {
                                  await controller
                                      .deleteCollection(collection.id);
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('\u91cd\u547d\u540d'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('\u5220\u9664'),
                              ),
                            ],
                          ),
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('\u65b0\u5efa\u5408\u96c6'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showCreateCollectionDialog(context, controller);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRenameCollectionDialog(
    BuildContext context,
    MobileLibraryController controller,
    Collection collection,
  ) async {
    final input = TextEditingController(text: collection.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u91cd\u547d\u540d\u5408\u96c6'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: '\u8f93\u5165\u65b0\u540d\u79f0'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('\u4fdd\u5b58'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await controller.renameCollection(collection.id, input.text);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        }
      }
    }
  }

  Future<bool?> _confirmDeleteCollection(
    BuildContext context,
    Collection collection,
    int count,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u5220\u9664\u5408\u96c6'),
        content: Text(
          '\u786e\u5b9a\u5220\u9664\u201c${collection.name}\u201d\u5417\uff1f\u4ec5\u5220\u9664\u5408\u96c6\u548c\u5f52\u5c5e\u5173\u7cfb\uff0c\u4e0d\u4f1a\u5220\u9664\u4e66\u7c4d\u3002\u5f53\u524d $count \u672c\u4e66\u3002',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('\u5220\u9664'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSelectedSheet(
    BuildContext context,
    MobileLibraryState state,
    MobileLibraryController controller,
  ) async {
    final collections = state.collections
        .where((collection) => collection.id != state.defaultCollectionId)
        .toList();
    if (state.selectedBookUids.isEmpty || collections.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('\u52a0\u5165\u5408\u96c6'),
              subtitle: Text('\u9009\u62e9\u76ee\u6807\u5408\u96c6'),
            ),
            ...collections.map(
              (collection) => ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: Text(collection.name),
                onTap: () async {
                  await controller.addBooksToCollection(
                    collection.id,
                    state.selectedBookUids,
                  );
                  controller.exitSelectionMode();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoveSelectedSheet(
    BuildContext context,
    MobileLibraryState state,
    MobileLibraryController controller,
  ) async {
    if (state.selectedBookUids.isEmpty || state.collections.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('\u79fb\u52a8\u5230\u5408\u96c6'),
                subtitle: Text('\u9009\u62e9\u76ee\u6807\u5408\u96c6'),
              ),
              ...state.collections.map((collection) {
                return ListTile(
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: Text(collection.name),
                  trailing: collection.id == state.selectedCollectionId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    await controller.moveBooksToCollection(
                      bookUids: state.selectedBookUids,
                      collectionId: collection.id,
                    );
                    controller.exitSelectionMode();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                );
              }),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('\u65b0\u5efa\u5408\u96c6'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _showCreateCollectionDialog(context, controller);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSelected(
    BuildContext context,
    MobileLibraryState state,
    MobileLibraryController controller,
  ) async {
    if (state.selectedBookUids.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u786e\u8ba4\u5220\u9664'),
        content: Text(
          '\u786e\u5b9a\u5220\u9664 ${state.selectedBookUids.length} \u672c\u4e66\u5417\uff1f\n\u8fd9\u4f1a\u540c\u65f6\u5220\u9664\u672c\u5730\u6587\u4ef6\u548c\u89e3\u6790\u7f13\u5b58\u3002',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('\u5220\u9664'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteBooks(state.selectedBookUids);
      controller.exitSelectionMode();
    }
  }

  Future<void> _openBook(
    BuildContext context,
    MobileLibraryState state,
    MobileLibraryController controller,
    String bookUid,
  ) async {
    if (state.isSelectionMode) {
      controller.toggleSelectedBook(bookUid);
      return;
    }
    await context.push(RoutePaths.reader(bookUid));
    if (!mounted) {
      return;
    }
    // 从阅读返回后刷新书库(进度变化),但不重置用户选中的合集。
    await controller.refresh();
  }

  Future<void> _openImportCenter(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ImportCenterPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await ref.read(mobileLibraryControllerProvider.notifier).refresh();
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }
}
