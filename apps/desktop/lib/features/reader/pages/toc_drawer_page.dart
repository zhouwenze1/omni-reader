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
    final currentHref = ref.watch(readerCurrentHrefProvider(bookUid));

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

          return ReaderTocList(
            items: items,
            currentHref: currentHref,
            onSelect: (item) => Navigator.of(context).pop(item),
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
