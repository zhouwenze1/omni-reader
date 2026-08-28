import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../di/repositories_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared_ui/widgets/error_view.dart';

class TocDrawerPage extends ConsumerWidget {
  const TocDrawerPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tocFuture = ref.watch(_tocProvider(bookUid));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tocTitle)),
      body: tocFuture.when(
        loading: () => LoadingView(label: l10n.tocLoading),
        error: (error, _) => ErrorView(
          title: l10n.tocLoadFailed,
          message: '$error',
          onRetry: () => ref.invalidate(_tocProvider(bookUid)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              title: l10n.tocEmpty,
              message: l10n.tocEmptyMessage,
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: EdgeInsets.only(
                  left: 16 + (item.level * 16),
                  right: 16,
                ),
                title: Text(item.title),
                trailing:
                    item.href == null ? null : const Icon(Icons.chevron_right),
                onTap: item.href == null
                    ? null
                    : () => Navigator.of(context).pop(item),
              );
            },
          );
        },
      ),
    );
  }
}

final _tocProvider =
    FutureProvider.family<List<TocItem>, String>((ref, bookUid) {
  return ref.watch(tocRepositoryProvider).getToc(bookUid);
});
