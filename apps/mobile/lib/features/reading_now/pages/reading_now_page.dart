import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure_data/data.dart';

import '../../../di/providers.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../../shared_ui/widgets/error_view.dart';
import 'reading_history_page.dart';
import '../widgets/reading_now_card.dart';
import '../widgets/recent_item_tile.dart';

class ReadingNowPage extends ConsumerWidget {
  const ReadingNowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLibrary = ref.watch(libraryIndexProvider);
    final dataModule = ref.watch(dataModuleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          child: asyncLibrary.when(
            loading: () => const LoadingView(label: '正在加载阅读记录'),
            error: (error, _) => ErrorView(
              title: '加载失败',
              message: '$error',
              onRetry: () => ref.invalidate(libraryIndexProvider),
            ),
            data: (items) {
              final activeItems = items.where(_hasReadingActivity).toList();
              if (activeItems.isEmpty) {
                return const EmptyView(
                  title: '还没有阅读记录',
                  message: '去书架打开一本书，下一次这里会优先展示你的最近阅读。',
                );
              }

              final sorted = [...activeItems]..sort(
                  (a, b) => (b.lastOpenedAt ?? b.updatedAt).compareTo(
                    a.lastOpenedAt ?? a.updatedAt,
                  ),
                );
              final featured = sorted.first;
              final recentItems = sorted.skip(1).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '阅读中',
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '继续你上次停下的地方，再往下读一点。',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ReadingHistoryPage(),
                              ),
                            ),
                            icon: const Icon(Icons.history_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: ReadingNowCard(
                        entry: featured,
                        coverPath: _coverPath(dataModule, featured),
                        onTap: () => context.push(
                          RoutePaths.reader(featured.bookUid),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            '最近阅读',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${sorted.length} 本',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (recentItems.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: EmptyView(
                          title: '已经追到最新了',
                          message: '再读几本书，这里会继续累积最近阅读记录。',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = recentItems[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    index == recentItems.length - 1 ? 0 : 12,
                              ),
                              child: RecentItemTile(
                                entry: item,
                                coverPath: _coverPath(dataModule, item),
                                onTap: () => context.push(
                                  RoutePaths.reader(item.bookUid),
                                ),
                              ),
                            );
                          },
                          childCount: recentItems.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String? _coverPath(DataModule dataModule, LibraryIndexEntry entry) {
    final rel = entry.coverRelPath;
    if (rel == null || rel.isEmpty) {
      return null;
    }
    return '${dataModule.storagePaths.libraryRoot.path}/${entry.bookUid}/$rel';
  }

  bool _hasReadingActivity(LibraryIndexEntry entry) {
    final progress = (entry.cachedProgress ?? 0).clamp(0.0, 1.0);
    return entry.lastOpenedAt != null ||
        progress > libraryProgressStartedThreshold;
  }
}
