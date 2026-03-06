import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure_data/data.dart';

import '../../../di/providers.dart';
import '../../../routes/route_paths.dart';
import '../../import_center/pages/import_center_page.dart';
import '../controller/library_controller.dart';
import '../controller/library_state.dart';
import '../widgets/book_grid_item.dart';
import '../widgets/book_list_item.dart';
import '../widgets/shelf_toolbar.dart';
import 'library_search_page.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mobileLibraryControllerProvider);
    final controller = ref.read(mobileLibraryControllerProvider.notifier);
    final dataModule = ref.watch(dataModuleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LibrarySearchPage(),
              ),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ImportCenterPage(),
              ),
            ),
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            onPressed: () => context.push(RoutePaths.settingsHome),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: switch (state.status) {
        LibraryPageStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        LibraryPageStatus.error =>
          Center(child: Text(state.errorMessage ?? '加载失败')),
        LibraryPageStatus.empty =>
          const Center(child: Text('暂无书籍，先导入一本书。')),
        LibraryPageStatus.normal => Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ShelfToolbar(
                  sortMode: state.sortMode,
                  viewMode: state.viewMode,
                  onSortChanged: controller.setSortMode,
                  onViewModeChanged: controller.setViewMode,
                  onImport: () => _openImportCenter(context, ref),
                ),
                const SizedBox(height: 8),
                _filterRow(state, controller),
                const SizedBox(height: 8),
                Expanded(
                  child: state.viewMode == LibraryViewMode.grid
                      ? GridView.builder(
                          itemCount: state.items.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.64,
                          ),
                          itemBuilder: (context, index) {
                            final entry = state.items[index];
                            return BookGridItem(
                              entry: entry,
                              coverPath: _coverPath(dataModule, entry),
                              onTap: () =>
                                  context.push(RoutePaths.reader(entry.bookUid)),
                            );
                          },
                        )
                      : ListView.separated(
                          itemCount: state.items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = state.items[index];
                            return BookListItem(
                              entry: entry,
                              coverPath: _coverPath(dataModule, entry),
                              onTap: () =>
                                  context.push(RoutePaths.reader(entry.bookUid)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
      },
    );
  }

  Widget _filterRow(
    MobileLibraryState state,
    MobileLibraryController controller,
  ) {
    final selectedFormat =
        state.filters.formats.isEmpty ? 'ALL' : state.filters.formats.first;
    final selectedCategory =
        state.filters.categoryIds.isEmpty ? 'ALL' : state.filters.categoryIds.first;

    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
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
              const DropdownMenuItem(value: 'ALL', child: Text('全部格式')),
              ...state.availableFormats.map((format) {
                return DropdownMenuItem(
                  value: format,
                  child: Text(format.toUpperCase()),
                );
              }),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<LibraryProgressBucket>(
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
                child: Text('全部进度'),
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
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String>(
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
              const DropdownMenuItem(value: 'ALL', child: Text('全部分类')),
              ...state.availableCategories.map((id) {
                return DropdownMenuItem(value: id, child: Text(id));
              }),
            ],
          ),
        ),
      ],
    );
  }

  String? _coverPath(DataModule dataModule, LibraryIndexEntry entry) {
    final rel = entry.coverRelPath;
    if (rel == null || rel.isEmpty) {
      return null;
    }
    return '${dataModule.storagePaths.libraryRoot.path}/${entry.bookUid}/$rel';
  }

  Future<void> _openImportCenter(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ImportCenterPage(),
      ),
    );
    await ref.read(mobileLibraryControllerProvider.notifier).refresh();
  }
}
