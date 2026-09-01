import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:infrastructure_data/data.dart';

import '../../../di/providers.dart';
import '../../../l10n/app_localizations.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../../shared_ui/widgets/error_view.dart';
import '../widgets/reading_now_card.dart';
import '../widgets/recent_item_tile.dart';

class ReadingNowPage extends ConsumerWidget {
  const ReadingNowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLibrary = ref.watch(libraryIndexProvider);
    final dataModule = ref.watch(dataModuleProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

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
            loading: () => LoadingView(label: l10n.loadingReadingHistory),
            error: (error, _) => ErrorView(
              title: l10n.loadingFailed,
              message: '$error',
              onRetry: () => ref.invalidate(libraryIndexProvider),
            ),
            data: (items) {
              final activeItems = items.where(_hasReadingActivity).toList();
              if (activeItems.isEmpty) {
                return EmptyView(
                  title: l10n.emptyReadingNowTitle,
                  message: l10n.emptyReadingNowMessage,
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
                                  l10n.tabReadingNow,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.readingNowSubtitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
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
                            l10n.recentReadingTitle,
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
