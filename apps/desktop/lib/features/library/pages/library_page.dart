import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure_data/data.dart';

import '../../../di/providers.dart';
import '../../../di/repositories_providers.dart';
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
    final state = ref.watch(desktopLibraryControllerProvider);
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
    final dataModule = ref.watch(dataModuleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            onPressed: () => context.push(RoutePaths.settingsHome),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: switch (state.status) {
        LibraryPageStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        LibraryPageStatus.error => Center(
            child: Text(state.errorMessage ?? '加载失败'),
          ),
        LibraryPageStatus.empty => const Center(
            child: Text('暂无书籍，先导入一本书。'),
          ),
        LibraryPageStatus.normal => Row(
            children: [
              if (state.isFilterPanelVisible)
                SizedBox(
                  width: 240,
                  child: _buildFilterPanel(context, ref, state, controller),
                ),
              if (state.isFilterPanelVisible) const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ShelfToolbar(
                        sortMode: state.sortMode,
                        viewMode: state.viewMode,
                        filterPanelVisible: state.isFilterPanelVisible,
                        onSortChanged: (m) => controller.setSortMode(m),
                        onViewModeChanged: (m) => controller.setViewMode(m),
                        onToggleFilterPanel: controller.toggleFilterPanel,
                        onImport: () => _importBook(context, ref),
                        onRefresh: () => controller.refresh(),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: state.viewMode == LibraryViewMode.grid
                            ? _buildGrid(state, controller, dataModule)
                            : _buildList(state, controller, dataModule),
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

  Widget _buildFilterPanel(
    BuildContext context,
    WidgetRef ref,
    DesktopLibraryState state,
    DesktopLibraryController controller,
  ) {
    final selectedFormat =
        state.filters.formats.isEmpty ? 'ALL' : state.filters.formats.first;
    final selectedCategory = state.filters.categoryIds.isEmpty
        ? 'ALL'
        : state.filters.categoryIds.first;
    final selectedCollectionId = state.selectedCollectionId;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('筛选', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        const Text('格式'),
        DropdownButton<String>(
          value: selectedFormat,
          isExpanded: true,
          onChanged: (value) {
            if (value == null || value == 'ALL') {
              controller.setFormats(<String>{});
            } else {
              controller.setFormats(<String>{value});
            }
          },
          items: [
            const DropdownMenuItem(value: 'ALL', child: Text('全部')),
            ...state.availableFormats.map(
              (format) => DropdownMenuItem(
                value: format,
                child: Text(format.toUpperCase()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text('进度'),
        DropdownButton<LibraryProgressBucket>(
          value: state.filters.progress,
          isExpanded: true,
          onChanged: (value) {
            if (value != null) {
              controller.setProgressBucket(value);
            }
          },
          items: const [
            DropdownMenuItem(
              value: LibraryProgressBucket.all,
              child: Text('全部'),
            ),
            DropdownMenuItem(
              value: LibraryProgressBucket.notStarted,
              child: Text('未开始'),
            ),
            DropdownMenuItem(
              value: LibraryProgressBucket.inProgress,
              child: Text('阅读中'),
            ),
            DropdownMenuItem(
              value: LibraryProgressBucket.completed,
              child: Text('已完成'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text('分类'),
        DropdownButton<String>(
          value: selectedCategory,
          isExpanded: true,
          onChanged: (value) {
            if (value == null || value == 'ALL') {
              controller.setCategories(<String>{});
            } else {
              controller.setCategories(<String>{value});
            }
          },
          items: [
            const DropdownMenuItem(value: 'ALL', child: Text('全部')),
            ...state.availableCategories.map(
              (category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 6),
        const Text('合集'),
        DropdownButton<int?>(
          value: selectedCollectionId,
          isExpanded: true,
          onChanged: (value) => controller.setCollectionFilter(value),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('全部合集'),
            ),
            ...state.collections.map(
              (collection) => DropdownMenuItem<int?>(
                value: collection.id,
                child: Text(collection.name),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showCreateCollectionDialog(context, controller),
          icon: const Icon(Icons.add),
          label: const Text('新建合集'),
        ),
        OutlinedButton.icon(
          onPressed: () => _showManageCollectionsDialog(context, ref),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('管理合集'),
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
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 286,
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
    final entry = state.selectedItem;
    if (entry == null) {
      return const Center(child: Text('选择一本书查看详情'));
    }

    final progress = ((entry.cachedProgress ?? 0) * 100).toStringAsFixed(1);
    final lastOpened = entry.lastOpenedAt;

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
          BookMetaRow(label: '作者', value: entry.authors.join(' · ')),
          BookMetaRow(label: '格式', value: entry.format.toUpperCase()),
          BookMetaRow(label: '进度', value: '$progress%'),
          BookMetaRow(label: '分类', value: entry.categoryId ?? '未分类'),
          BookMetaRow(
            label: '导入时间',
            value: _formatDate(entry.importedAt),
          ),
          BookMetaRow(
            label: '最近阅读',
            value: lastOpened == null ? '-' : _formatDate(lastOpened),
          ),
          const SizedBox(height: 10),
          Text('合集', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _buildCollectionChips(state, entry, ref),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showBookCollectionsDialog(context, ref, entry, state),
              icon: const Icon(Icons.playlist_add),
              label: const Text('加入/移出合集'),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      context.push(RoutePaths.reader(entry.bookUid)),
                  child: const Text('继续阅读'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(RoutePaths.toc(entry.bookUid)),
                  child: const Text('打开目录'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteBook(context, ref, entry.bookUid),
              label: const Text('删除书籍'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCollectionChips(
    DesktopLibraryState state,
    LibraryIndexEntry entry,
    WidgetRef ref,
  ) {
    final belongedIds = state.collectionsOfBook(entry.bookUid);
    if (belongedIds.isEmpty) {
      return const [Text('未加入合集')];
    }
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
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
    final input = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建合集'),
        content: TextField(
          controller: input,
          decoration: const InputDecoration(
            hintText: '输入合集名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('创建'),
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
    final input = TextEditingController(text: collection.name);
    final rename = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名合集'),
        content: TextField(
          controller: input,
          decoration: const InputDecoration(
            hintText: '输入新名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
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
    WidgetRef ref,
  ) async {
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (_) => Consumer(
        builder: (context, ref, __) {
          final state = ref.watch(desktopLibraryControllerProvider);
          return AlertDialog(
            title: const Text('管理合集'),
            content: SizedBox(
              width: 420,
              child: state.collections.isEmpty
                  ? const Center(child: Text('还没有合集'))
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
                          subtitle: Text('$count 本书'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: '重命名',
                                onPressed: () => _showRenameCollectionDialog(
                                  context,
                                  controller,
                                  collection,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: '删除',
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
                child: const Text('新建合集'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showBookCollectionsDialog(
    BuildContext context,
    WidgetRef ref,
    LibraryIndexEntry entry,
    DesktopLibraryState state,
  ) async {
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
    final localSelected = {...state.collectionsOfBook(entry.bookUid)};

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('合集 · ${entry.title}'),
            content: SizedBox(
              width: 380,
              child: state.collections.isEmpty
                  ? const Text('还没有合集，请先创建。')
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
                child: const Text('新建合集'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
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

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _deleteBook(
      BuildContext context, WidgetRef ref, String bookUid) async {
    final controller = ref.read(desktopLibraryControllerProvider.notifier);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: const Text('删除后不可恢复，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.deleteBook(bookUid);
    }
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
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
        ? 'Already imported: ${result.bookUid}'
        : result.task.status == ImportTaskStatus.success
            ? 'Imported: ${result.bookUid}'
            : 'Import failed: ${result.task.errorMessage}';

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
