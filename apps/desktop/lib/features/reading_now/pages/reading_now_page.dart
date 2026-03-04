import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../routes/route_paths.dart';
import '../../../shared_ui/widgets/empty_view.dart';
import '../../../shared_ui/widgets/error_view.dart';
import '../../../shared_ui/widgets/loading_view.dart';

class ReadingNowPage extends ConsumerWidget {
  const ReadingNowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLibrary = ref.watch(libraryIndexProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabReadingNow)),
      body: asyncLibrary.when(
        loading: () => LoadingView(label: l10n.loadingReadingHistory),
        error: (error, _) => ErrorView(
          title: l10n.loadingFailed,
          message: '$error',
          onRetry: () => ref.invalidate(libraryIndexProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              title: l10n.emptyReadingNowTitle,
              message: l10n.emptyReadingNowMessage,
            );
          }

          final sorted = [...items]..sort(
              (a, b) => (b.lastOpenedAt ?? b.updatedAt).compareTo(
                a.lastOpenedAt ?? a.updatedAt,
              ),
            );

          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final item = sorted[index];
              final progress =
                  ((item.cachedProgress ?? 0) * 100).toStringAsFixed(0);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text(l10n.recentReadingProgress(progress)),
                  trailing: FilledButton(
                    onPressed: () =>
                        context.push(RoutePaths.reader(item.bookUid)),
                    child: Text(l10n.continueReading),
                  ),
                  onTap: () => context.push(RoutePaths.reader(item.bookUid)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
