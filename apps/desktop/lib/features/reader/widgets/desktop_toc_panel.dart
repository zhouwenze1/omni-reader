import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../di/repositories_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared_ui/widgets/error_view.dart';

final tocPanelItemsProvider =
    FutureProvider.family<List<TocItem>, String>((ref, bookUid) {
  return ref.watch(tocRepositoryProvider).getToc(bookUid);
});

/// 右侧目录面板:贴阅读器右缘滑入,深色半透明背景与 chrome 浮层同风格。
class DesktopTocPanel extends ConsumerWidget {
  const DesktopTocPanel({
    super.key,
    required this.bookUid,
    required this.onSelect,
    required this.onClose,
  });

  final String bookUid;
  final ValueChanged<TocItem> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tocFuture = ref.watch(tocPanelItemsProvider(bookUid));

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 320,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F2126),
            border: Border(left: BorderSide(color: Colors.white24)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          l10n.tocTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: onClose,
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: tocFuture.when(
                  loading: () => LoadingView(label: l10n.tocLoading),
                  error: (error, _) => ErrorView(
                    title: l10n.tocLoadFailed,
                    message: '$error',
                    onRetry: () =>
                        ref.invalidate(tocPanelItemsProvider(bookUid)),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return EmptyView(
                        title: l10n.tocEmpty,
                        message: l10n.tocEmptyMessage,
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final enabled = item.href != null;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.only(
                            left: 16 + (item.level * 16),
                            right: 12,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: enabled ? Colors.white : Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          trailing: enabled
                              ? const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white38,
                                  size: 18,
                                )
                              : null,
                          onTap: enabled ? () => onSelect(item) : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
