import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure_data/data.dart';

import '../../../di/providers.dart';
import '../../../routes/route_paths.dart';
import '../../../shared_ui/widgets/empty_view.dart';
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

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => _openImportCenter(context),
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            onPressed: () => context.push(RoutePaths.settingsHome),
            icon: const Icon(Icons.settings_outlined),
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
            Center(child: Text(state.errorMessage ?? '加载失败')),
          LibraryPageStatus.empty => const Center(child: Text('暂无书籍，先导入一本书。')),
          LibraryPageStatus.normal => Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
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
                            title: '当前筛选下没有书籍',
                            message: '试试切换排序，或者展开筛选后恢复为全部。',
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
                              child: const Text('清除筛选'),
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
                                    onTap: () => context.push(
                                      RoutePaths.reader(entry.bookUid),
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
                                    onTap: () => context.push(
                                      RoutePaths.reader(entry.bookUid),
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
                '筛选',
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
                  child: const Text('清除'),
                ),
            ],
          ),
          _FilterGroup(
            title: '格式',
            children: [
              ChoiceChip(
                label: const Text('全部'),
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
            title: '进度',
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
              title: '分类',
              children: [
                ChoiceChip(
                  label: const Text('全部'),
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
    if (filters.hasFormatFilter) count += 1;
    if (filters.hasProgressFilter) count += 1;
    if (filters.hasCategoryFilter) count += 1;
    return count;
  }

  String _progressLabel(LibraryProgressBucket bucket) {
    return switch (bucket) {
      LibraryProgressBucket.all => '全部进度',
      LibraryProgressBucket.notStarted => '未开始',
      LibraryProgressBucket.inProgress => '阅读中',
      LibraryProgressBucket.completed => '已读完',
    };
  }

  String? _coverPath(DataModule dataModule, LibraryIndexEntry entry) {
    final rel = entry.coverRelPath;
    if (rel == null || rel.isEmpty) {
      return null;
    }
    return '${dataModule.storagePaths.libraryRoot.path}/${entry.bookUid}/$rel';
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
