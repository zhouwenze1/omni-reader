import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:services_search/services_search.dart';

import '../../../di/services_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared_ui/widgets/error_view.dart';

/// 右侧全文搜索面板:输入防抖 300ms,正文命中按 snippet 高亮展示,
/// 选中后由宿主(reader_page)关闭面板并跳转。
class DesktopSearchPanel extends ConsumerStatefulWidget {
  const DesktopSearchPanel({
    super.key,
    required this.bookUid,
    required this.format,
    required this.onSelect,
    required this.onClose,
  });

  final String bookUid;

  /// 当前书格式;非 EPUB 直接显示不支持提示,不发起搜索。
  final String? format;

  final ValueChanged<SearchHit> onSelect;
  final VoidCallback onClose;

  @override
  ConsumerState<DesktopSearchPanel> createState() => _DesktopSearchPanelState();
}

class _DesktopSearchPanelState extends ConsumerState<DesktopSearchPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _searching = false;
  Object? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _searching = query.isNotEmpty;
      _error = null;
      if (query.isEmpty) {
        _result = const <SearchHit>[];
      }
    });
    if (query.isEmpty) {
      return;
    }

    try {
      final result = await ref.read(bookSearchServiceProvider).search(
            bookUid: widget.bookUid,
            format: widget.format,
            query: query,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 360,
        height: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            border: Border(left: BorderSide(color: Colors.white12)),
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
                          l10n.searchInBookTitle,
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
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: _onChanged,
                ),
              ),
              Expanded(child: _buildResults(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final l10n = context.l10n;

    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    if (_error != null) {
      return ErrorView(title: l10n.searchFailed, message: _error!);
    }

    final result = _result;
    if (result is BookSearchUnsupported) {
      return _Message(
        title: l10n.searchUnsupportedTitle,
        message: result.reason == 'format'
            ? l10n.searchUnsupportedFormat
            : l10n.searchUnsupportedFile,
      );
    }
    if (result is! List<SearchHit>) {
      return _Message(
          title: l10n.searchBodySection, message: l10n.searchInputPrompt);
    }

    if (result.isEmpty) {
      return _Message(
        title: l10n.searchBodySection,
        message: _controller.text.isEmpty
            ? l10n.searchInputPrompt
            : l10n.searchNoMatches,
      );
    }

    final query = _controller.text.trim().toLowerCase();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: result.length,
      itemBuilder: (context, index) {
        final hit = result[index];
        return ListTile(
          dense: true,
          title: _snippetText(context, hit.snippet, query),
          subtitle: Text(
            hit.href ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          onTap: () => widget.onSelect(hit),
          trailing:
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
        );
      },
    );
  }

  /// snippet 内高亮第一次出现的命中词(显示近似;跳转由 CFI 精确定位)。
  Widget _snippetText(BuildContext context, String snippet, String query) {
    final style = const TextStyle(color: Colors.white, fontSize: 13);
    if (query.isEmpty) {
      return Text(snippet, style: style);
    }
    final index = snippet.toLowerCase().indexOf(query);
    if (index < 0) {
      return Text(snippet, style: style);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: snippet.substring(0, index)),
          TextSpan(
            text: snippet.substring(index, index + query.length),
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (index + query.length < snippet.length)
            TextSpan(text: snippet.substring(index + query.length)),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_outlined,
                color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
