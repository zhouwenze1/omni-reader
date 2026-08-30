import 'dart:async';
import 'dart:ui' as ui;

import 'package:foundation_application/application.dart';
import 'package:kernel/kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:foundation_domain/domain.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shared_ui/shared_ui.dart';
import '../../../di/repositories_providers.dart';
import '../../../di/services_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../me/controller/me_controller.dart';
import '../../settings/controller/settings_controller.dart';
import '../widgets/desktop_reader_settings_dialog.dart';
import 'package:services_search/services_search.dart';
import '../widgets/desktop_search_panel.dart';
import '../widgets/desktop_toc_panel.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  ReaderSession? _session;
  StreamSubscription<ReaderEvent>? _subscription;
  ProgressRepository? _progressRepository;
  ProviderContainer? _providerContainer;
  AnnotationsStore? _annotationsStore;
  Book? _book;
  ReadingProgress? _progress;
  String? _error;
  bool _loading = true;
  bool _chromeVisible = false;
  bool _tocPanelOpen = false;
  bool _searchPanelOpen = false;
  bool _searchHighlightActive = false;
  String? _searchHighlightPageKey;
  String? _searchHighlightTargetHref;
  String? _lastRelocatedPageKey;
  String? _lastRelocatedHref;
  int _searchHighlightRequestToken = 0;
  String _searchQuery = '';
  Object? _searchResult;
  bool _disposed = false;
  late final DebouncedAsyncWriter<ReadingProgress> _progressWriteQueue;
  late final DebouncedAsyncWriter<ReaderSettings> _readerSettingsWriteQueue;

  String _rendererTheme = 'day';
  double _fontSize = 20;
  double _lineHeight = 1.6;
  double _pageGap = 24;
  double _paddingLeftRight = 36;
  double _paddingTopBottom = 16;
  bool _textIndentEnabled = true;
  double _textIndentEm = 2;
  bool _textIndentSkipFirst = false;
  String _layoutMode = ReaderLayoutMode.pagedAuto;
  String? _appliedRendererLayoutMode;
  bool _layoutSyncScheduled = false;
  ReaderSettings? _pendingReaderSettings;
  bool _styleApplyInFlight = false;
  ReadingSessionRecorder? _readingRecorder;
  bool _selectionMenuVisible = false;
  String? _selectionText;
  ui.Rect? _selectionRect;
  ReaderSelectionQuote? _selectionQuote;
  Future<ReaderSelectionQuote?>? _selectionQuoteFuture;
  Annotation? _editingAnnotation;
  int _selectionGeneration = 0;
  bool _annotationActionInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progressWriteQueue = DebouncedAsyncWriter<ReadingProgress>(
      debounce: const Duration(milliseconds: 280),
      writer: (progress) async {
        final repository = _progressRepository;
        if (repository == null) {
          return;
        }
        try {
          await repository.saveProgress(progress);
        } catch (error) {
          debugPrint('[desktop-reader][saveProgress.error] $error');
        }
      },
    );
    _readerSettingsWriteQueue = DebouncedAsyncWriter<ReaderSettings>(
      debounce: const Duration(milliseconds: 420),
      writer: (settings) async {
        try {
          await ref
              .read(settingsControllerProvider.notifier)
              .updateReader(settings);
        } catch (error) {
          debugPrint('[desktop-reader][saveReaderSettings.error] $error');
        }
      },
    );
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerContainer ??= ProviderScope.containerOf(context, listen: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_progressWriteQueue.flush());
      unawaited(_readerSettingsWriteQueue.flush());
      _readingRecorder?.pause();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _readingRecorder?.resume();
    }
  }

  Future<void> _init() async {
    try {
      final settingsState = await _waitSettingsLoaded();
      _bootstrapReaderStyleFromSettings(settingsState);

      final bookRepository = ref.read(bookRepositoryProvider);
      final progressRepository = ref.read(progressRepositoryProvider);
      _progressRepository = progressRepository;
      final registry = ref.read(engineRegistryProvider);

      final book = await bookRepository.getBook(widget.bookUid);
      if (book == null) {
        setState(() {
          _error = 'Book not found: ${widget.bookUid}';
          _loading = false;
        });
        return;
      }

      final progress = await progressRepository.getProgress(widget.bookUid);
      final annotationsStore = AnnotationsStore(
        repository: ref.read(annotationRepositoryProvider),
        bookUid: book.uid,
      );
      await annotationsStore.load();
      final engine = registry.findByFormat(book.format);
      if (engine == null) {
        setState(() {
          _error = 'No engine for format: ${book.format}';
          _loading = false;
        });
        return;
      }

      final initialLayoutMode = _resolveRendererLayoutMode();
      final session = await engine.createSession(
        book: book,
        initialProgress: progress,
        initialStyle: _rendererStyleFor(_currentReaderSettings()),
        initialLayoutMode: initialLayoutMode,
      );
      await session.setActiveHighlights(annotationsStore.readerHighlights);

      _subscription = session.events.listen((event) async {
        if (_disposed) {
          return;
        }
        if (event.type == ReaderEventType.log ||
            event.type == ReaderEventType.error ||
            event.type == ReaderEventType.ready) {
          debugPrint(
            '[desktop-reader][${event.type.name}] payload=${event.payload}',
          );
        }

        if (event.type == ReaderEventType.tapIntent) {
          _handleTapIntent(event.asData<ReaderTapIntentData>(), event.payload);
        }

        if (event.type == ReaderEventType.link) {
          await _handleLinkEvent(event.asData<ReaderLinkData>(), event.payload);
        }

        if (event.type == ReaderEventType.mediaTap) {
          await _handleMediaTapEvent(
            event.asData<ReaderMediaTapData>(),
            event.payload,
          );
        }

        if (event.type == ReaderEventType.selection) {
          _handleSelectionEvent(
            event.asData<ReaderSelectionData>(),
            event.payload,
          );
        }

        if (event.type == ReaderEventType.highlightTapped) {
          _handleHighlightTapped(
            event.asData<ReaderHighlightTappedData>(),
            event.payload,
          );
        }

        if (event.type == ReaderEventType.relocated) {
          _handleSearchRelocated(event);
        }

        if (event.type == ReaderEventType.relocated && event.locator != null) {
          final progression = ReaderEventParser.resolveProgression(
            payload: event.payload,
            locatorLocations: event.locator!.locations,
          );

          final nextProgress = ReadingProgress(
            bookUid: book.uid,
            locator: event.locator!,
            progression: progression,
            updatedAt: DateTime.now(),
            lastReadAt: DateTime.now(),
          );
          _progress = nextProgress;
          _scheduleProgressSave(nextProgress);
          if (mounted) {
            setState(() {});
          }
        }
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _book = book;
        _progress = progress;
        _annotationsStore = annotationsStore;
        _appliedRendererLayoutMode = initialLayoutMode;
        _session = session;
        _loading = false;
      });

      // 阅读会话就绪后开始计时(阅读时长埋点,见 docs/specs 统计中心方案)。
      _readingRecorder = ReadingSessionRecorder(
        bookUid: widget.bookUid,
        onSegment: (startedAt, endedAt) {
          ref
              .read(readingStatsRepositoryProvider)
              .recordSession(
                bookUid: widget.bookUid,
                startedAt: startedAt,
                endedAt: endedAt,
              )
              .ignore();
        },
      )..start();

      await _applyReaderStyle();
      unawaited(_openSession(session));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<SettingsState> _waitSettingsLoaded() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    var current = ref.read(settingsControllerProvider);
    while (current.isLoading && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      current = ref.read(settingsControllerProvider);
    }
    return current;
  }

  void _bootstrapReaderStyleFromSettings(SettingsState settingsState) {
    _setReaderSettingsFields(settingsState.reader);
  }

  void _setReaderSettingsFields(ReaderSettings reader) {
    _rendererTheme = reader.rendererTheme;
    _fontSize = reader.fontSize;
    _lineHeight = reader.lineHeight;
    _pageGap = reader.pageGap;
    _paddingLeftRight = reader.paddingHorizontal;
    _paddingTopBottom = reader.paddingVertical;
    _textIndentEnabled = reader.textIndentEnabled;
    _textIndentEm = reader.textIndentEm;
    _textIndentSkipFirst = reader.textIndentSkipFirstParagraph;
    _layoutMode = ReaderLayoutMode.normalize(reader.layoutMode);
  }

  ReaderSettings _currentReaderSettings() {
    final current = ref.read(settingsControllerProvider).reader;
    return current.copyWith(
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageGap: _pageGap,
      paddingHorizontal: _paddingLeftRight,
      paddingVertical: _paddingTopBottom,
      textIndentEnabled: _textIndentEnabled,
      textIndentEm: _textIndentEm,
      textIndentSkipFirstParagraph: _textIndentSkipFirst,
      rendererTheme: _rendererTheme,
      layoutMode: _layoutMode,
    );
  }

  String _resolveRendererLayoutMode() {
    return _resolveRendererLayoutModeFor(_layoutMode);
  }

  String _resolveRendererLayoutModeFor(String layoutMode) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return ReaderLayoutMode.normalizeRendererMode(layoutMode);
    }
    return ReaderLayoutMode.resolveAdaptive(
      layoutMode,
      shortestSide: mediaQuery.size.shortestSide,
    );
  }

  Future<void> _syncLayoutMode({bool force = false}) async {
    final session = _session;
    if (session == null) {
      return;
    }
    final nextLayoutMode = _resolveRendererLayoutMode();
    if (!force && nextLayoutMode == _appliedRendererLayoutMode) {
      return;
    }
    try {
      await session.setLayoutMode(nextLayoutMode);
      _appliedRendererLayoutMode = nextLayoutMode;
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('[desktop-reader][setLayoutMode.error] $error');
    }
  }

  void _scheduleViewportLayoutSync() {
    final session = _session;
    if (session == null || _layoutSyncScheduled) {
      return;
    }
    if (_resolveRendererLayoutMode() == _appliedRendererLayoutMode) {
      return;
    }
    _layoutSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutSyncScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_syncLayoutMode());
    });
  }

  Future<void> _openSession(ReaderSession session) async {
    try {
      await session.open();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to open session: $error';
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _readingRecorder?.dispose();
    // 与移动端对齐:退出阅读后让“我的”页/统计相关 provider 立即重算。
    final providerContainer = _providerContainer;
    if (providerContainer != null) {
      providerContainer.invalidate(meControllerProvider);
      providerContainer.invalidate(weeklyReadingSummaryProvider);
    }
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_progressWriteQueue.close());
    unawaited(_readerSettingsWriteQueue.close());
    final subscription = _subscription;
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((_) {}));
    }
    final session = _session;
    if (session != null) {
      unawaited(session.dispose().catchError((_) {}));
    }
    super.dispose();
  }

  void _handleSelectionEvent(
    ReaderSelectionData? data,
    Map<String, dynamic>? payload,
  ) {
    final selection = data;
    if (selection == null) {
      return;
    }
    if (selection.phase == 'clear') {
      _dismissSelectionMenu();
      return;
    }

    final text = selection.text?.trim();
    final rect = _rectFromJson(
      selection.focusRect ?? selection.anchorRect ?? selection.rect,
    );
    if (text == null || text.isEmpty || rect == null || _disposed) {
      return;
    }

    final sameSelection = _selectionText == text && _editingAnnotation == null;
    setState(() {
      _selectionMenuVisible = true;
      _selectionText = text;
      _selectionRect = rect;
      _editingAnnotation = null;
    });

    if (!sameSelection || _selectionQuote == null) {
      _selectionQuote = null;
      final generation = ++_selectionGeneration;
      final session = _session;
      if (session == null) {
        return;
      }
      final future = session.getSelectionQuote();
      _selectionQuoteFuture = future;
      unawaited(
        future.then((quote) {
          if (_disposed || generation != _selectionGeneration) {
            return;
          }
          _selectionQuoteFuture = null;
          _selectionQuote = quote;
        }).catchError((_) {
          if (generation == _selectionGeneration) {
            _selectionQuoteFuture = null;
          }
          return null;
        }),
      );
    }
  }

  void _handleHighlightTapped(
    ReaderHighlightTappedData? data,
    Map<String, dynamic>? payload,
  ) {
    final uid = data?.uid;
    final store = _annotationsStore;
    if (uid == null || store == null) {
      return;
    }
    final annotation = store.find(uid);
    if (annotation == null) {
      return;
    }
    final rect =
        unionRects(data!.rects.map(_rectFromJson).whereType<ui.Rect>());
    if (rect == ui.Rect.zero || _disposed) {
      return;
    }
    _selectionGeneration += 1;
    _selectionQuoteFuture = null;
    setState(() {
      _selectionMenuVisible = true;
      _selectionText = annotation.text;
      _selectionRect = rect;
      _selectionQuote = null;
      _editingAnnotation = annotation;
    });
  }

  ui.Rect? _rectFromJson(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }
    final left = _number(value['left']);
    final top = _number(value['top']);
    if (left == null || top == null) {
      return null;
    }
    final width = _number(value['width']);
    final height = _number(value['height']);
    final right = _number(value['right']) ?? left + (width ?? 0);
    final bottom = _number(value['bottom']) ?? top + (height ?? 0);
    return ui.Rect.fromLTRB(left, top, right, bottom);
  }

  double? _number(dynamic value) => value is num ? value.toDouble() : null;

  Offset _selectionMenuOffset(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final menuWidth = (viewport.width - 16).clamp(360.0, 620.0);
    return computeMenuOffset(
      selectionRect: _selectionRect ?? ui.Rect.zero,
      viewport: viewport,
      menuSize: Size(menuWidth, 64),
    );
  }

  void _dismissSelectionMenu() {
    if (!mounted) {
      return;
    }
    _selectionGeneration += 1;
    setState(() {
      _selectionMenuVisible = false;
      _selectionRect = null;
      _selectionText = null;
      _selectionQuote = null;
      _editingAnnotation = null;
    });
  }

  Future<ReaderSelectionQuote?> _selectionQuoteForAction() async {
    if (_selectionQuote != null) {
      return _selectionQuote;
    }
    if (_selectionQuoteFuture != null) {
      return _selectionQuoteFuture;
    }
    return _session?.getSelectionQuote();
  }

  Future<void> _createHighlight({
    required String color,
    String? note,
  }) async {
    if (_annotationActionInFlight || _annotationsStore == null) {
      return;
    }
    final l10n = context.l10n;
    _annotationActionInFlight = true;
    try {
      final selection = await _selectionQuoteForAction();
      final session = _session;
      final store = _annotationsStore;
      if (selection == null || session == null || store == null) {
        _showAnnotationMessage(l10n.highlightFailed);
        return;
      }
      final uid = store.newHighlightId();
      final applied = await session.applyUserHighlight(
        ReaderHighlight(
          uid: uid,
          href: selection.href,
          color: color,
          quote: selection.quote,
          cfi: selection.cfi,
        ),
      );
      if (!applied) {
        _showAnnotationMessage(l10n.highlightFailed);
        return;
      }
      try {
        await store.createHighlight(
          selection: selection,
          color: color,
          note: note,
          id: uid,
        );
      } catch (_) {
        await session.removeUserHighlight(uid);
        _showAnnotationMessage(l10n.highlightFailed);
        return;
      }
      _dismissSelectionMenu();
      _showAnnotationMessage(l10n.highlightAdded);
    } finally {
      _annotationActionInFlight = false;
    }
  }

  Future<void> _changeHighlightColor(String color) async {
    final annotation = _editingAnnotation;
    final session = _session;
    final store = _annotationsStore;
    if (annotation == null || session == null || store == null) {
      await _createHighlight(color: color);
      return;
    }
    if (_annotationActionInFlight) {
      return;
    }
    _annotationActionInFlight = true;
    try {
      if (await session.updateUserHighlightColor(
        uid: annotation.id,
        color: color,
      )) {
        await store.changeColor(annotation.id, color);
        if (mounted) {
          setState(() => _editingAnnotation = store.find(annotation.id));
        }
      }
    } finally {
      _annotationActionInFlight = false;
    }
  }

  Future<void> _handleNoteAction() async {
    final note = await _showNoteEditor(_editingAnnotation?.note);
    if (note == null) {
      return;
    }
    final annotation = _editingAnnotation;
    final store = _annotationsStore;
    if (annotation == null || store == null) {
      await _createHighlight(color: AnnotationPalette.defaultColor, note: note);
      return;
    }
    await store.setNote(annotation.id, note);
    if (mounted) {
      setState(() => _editingAnnotation = store.find(annotation.id));
    }
  }

  Future<String?> _showNoteEditor(String? initial) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.annotationNote),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 6,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _copySelectionText() async {
    final text = _selectionText?.trim();
    if (text == null || text.isEmpty) {
      return;
    }
    final message = context.l10n.copied;
    await Clipboard.setData(ClipboardData(text: text));
    _showAnnotationMessage(message);
  }

  Future<void> _deleteHighlight() async {
    final annotation = _editingAnnotation;
    final session = _session;
    final store = _annotationsStore;
    if (annotation == null || session == null || store == null) {
      return;
    }
    if (await session.removeUserHighlight(annotation.id)) {
      await store.remove(annotation.id);
      _dismissSelectionMenu();
    }
  }

  void _showAnnotationMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleProgressSave(ReadingProgress progress) {
    if (_disposed) {
      return;
    }
    _progressWriteQueue.schedule(progress);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reader)),
        body: Center(child: Text(_error!)),
      );
    }

    _scheduleViewportLayoutSync();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _session!.buildView(),
          _buildTopToolbar(context),
          _buildBottomToolbar(context),
          if (_tocPanelOpen)
            DesktopTocPanel(
              bookUid: widget.bookUid,
              onSelect: _onTocSelect,
              onClose: () => setState(() => _tocPanelOpen = false),
            ),
          if (_searchPanelOpen)
            DesktopSearchPanel(
              bookUid: widget.bookUid,
              format: _book?.format,
              initialQuery: _searchQuery,
              initialResult: _searchResult,
              onStateChanged: (query, result) {
                _searchQuery = query;
                _searchResult = result;
              },
              onSelect: _onSearchSelect,
              onClose: () => setState(() => _searchPanelOpen = false),
            ),
          if (_selectionMenuVisible && _selectionRect != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissSelectionMenu,
              ),
            ),
          if (_selectionMenuVisible && _selectionRect != null)
            Positioned(
              left: _selectionMenuOffset(context).dx,
              top: _selectionMenuOffset(context).dy,
              right: 8,
              child: GestureDetector(
                onTap: () {},
                child: SelectionActionMenu(
                  selectedColor: _editingAnnotation?.color,
                  onColor: (color) => unawaited(_changeHighlightColor(color)),
                  onNote: () => unawaited(_handleNoteAction()),
                  onCopy: () => unawaited(_copySelectionText()),
                  onDelete: _editingAnnotation == null
                      ? null
                      : () => unawaited(_deleteHighlight()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onTocSelect(TocItem item) {
    setState(() => _tocPanelOpen = false);
    final href = item.href;
    if (href == null || _session == null) {
      return;
    }
    _session!.goTo(Locator(href: href));
  }

  void _onSearchSelect(SearchHit hit) {
    // 面板保持打开,便于连续比对多个结果;可用顶栏按钮或 X 隐藏。
    if (_session == null || hit.href == null) {
      return;
    }
    final token = ++_searchHighlightRequestToken;
    _searchHighlightActive = false;
    _searchHighlightPageKey = null;
    _searchHighlightTargetHref = _normalizeHrefKey(hit.href);
    unawaited(_selectSearchHit(hit, token));
  }

  Future<void> _selectSearchHit(SearchHit hit, int token) async {
    final session = _session;
    if (session == null || hit.href == null) return;
    try {
      await session.goTo(Locator(href: hit.href, cfi: hit.cfi));
      await _highlightSearchHit(hit, token);
    } catch (error) {
      if (token == _searchHighlightRequestToken && !_disposed) {
        debugPrint('[desktop-reader][search-highlight.error] $error');
      }
    }
  }

  Future<void> _highlightSearchHit(SearchHit hit, int token) async {
    final quote = hit.textQuote();
    if (quote == null || hit.href == null) {
      return;
    }
    final applied = await _session?.applySearchHighlight(
      href: hit.href!,
      prefix: quote.prefix,
      exact: quote.exact,
      suffix: quote.suffix,
      requestToken: token,
    );
    if (token != _searchHighlightRequestToken || _disposed || applied != true) {
      return;
    }
    _searchHighlightPageKey = null;
    _searchHighlightActive = true;
    if (_sameHref(_lastRelocatedHref, _searchHighlightTargetHref)) {
      _searchHighlightPageKey = _lastRelocatedPageKey;
    }
  }

  void _handleSearchRelocated(ReaderEvent event) {
    final key = _pageKeyOf(event);
    final href = _hrefOf(event);
    if (key.isNotEmpty) _lastRelocatedPageKey = key;
    if (href.isNotEmpty) _lastRelocatedHref = href;

    if (!_searchHighlightActive || key.isEmpty) return;
    if (_searchHighlightPageKey == null) {
      // Ignore a late event from the chapter that was visible before the
      // search jump. The first event from the target chapter establishes the
      // baseline instead of clearing the newly applied mark.
      if (_sameHref(href, _searchHighlightTargetHref)) {
        _searchHighlightPageKey = key;
      }
      return;
    }
    if (_searchHighlightPageKey == key) return;

    final token = _searchHighlightRequestToken;
    _searchHighlightActive = false;
    _searchHighlightPageKey = null;
    _searchHighlightTargetHref = null;
    unawaited(_clearSearchHighlightIfCurrent(token));
  }

  Future<void> _clearSearchHighlightIfCurrent(int token) async {
    await Future<void>.delayed(Duration.zero);
    if (_disposed || token != _searchHighlightRequestToken) return;
    await _session?.clearSearchHighlight(requestToken: token);
  }

  String _hrefOf(ReaderEvent event) {
    final locatorHref = event.locator?.href;
    if (locatorHref != null && locatorHref.trim().isNotEmpty) {
      return _normalizeHrefKey(locatorHref);
    }
    final payload = event.payload is Map ? event.payload as Map : const {};
    final locator = payload['locator'];
    if (locator is Map && locator['href'] != null) {
      return _normalizeHrefKey('${locator['href']}');
    }
    return _normalizeHrefKey('${payload['url'] ?? ''}');
  }

  String _normalizeHrefKey(String? raw) {
    final value = raw?.trim().replaceAll('\\', '/');
    if (value == null || value.isEmpty) return '';
    final parsed = Uri.tryParse(value);
    final path = parsed != null &&
            (parsed.scheme == 'http' ||
                parsed.scheme == 'https' ||
                parsed.scheme == 'book')
        ? parsed.path
        : value.split('#').first.split('?').first;
    return path
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'/+$'), '');
  }

  bool _sameHref(String? left, String? right) {
    final a = _normalizeHrefKey(left);
    final b = _normalizeHrefKey(right);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.endsWith('/$b') || b.endsWith('/$a');
  }

  /// relocated 的页标识:章节 href + 页码(缺页码时用 progression 量化)。
  String _pageKeyOf(ReaderEvent event) {
    final payload = event.payload is Map ? event.payload as Map : const {};
    final href = _hrefOf(event);
    final page = payload['pageIndex'];
    if (page != null) {
      return '$href#$page';
    }
    final progression =
        payload['progression'] ?? event.locator?.locations?['progression'];
    final quantized = progression is num ? (progression * 100000).round() : 'x';
    return '$href#$quantized';
  }

  void _handleTapIntent(
    ReaderTapIntentData? data,
    Map<String, dynamic>? payload,
  ) {
    final source = ReaderEventParser.selectPayload(
      typed: data?.toJson(),
      payload: payload,
    );
    if (source == null) {
      return;
    }
    final zone = '${source['zone'] ?? ''}'.toLowerCase();
    final mode = '${source['mode'] ?? ''}'.toLowerCase();
    if (zone == 'center' && mode == 'reading' && mounted) {
      setState(() {
        _chromeVisible = !_chromeVisible;
      });
    }
  }

  Future<void> _handleLinkEvent(
    ReaderLinkData? data,
    Map<String, dynamic>? payload,
  ) async {
    final source = ReaderEventParser.selectPayload(
      typed: data?.toJson(),
      payload: payload,
    );
    if (source == null) {
      return;
    }

    final decision = ReaderEventParser.resolveLink(source);
    switch (decision.action) {
      case ReaderLinkAction.blocked:
        debugPrint('[desktop-reader][link.blocked] payload=$source');
        return;
      case ReaderLinkAction.renderer:
        debugPrint('[desktop-reader][link.renderer] payload=$source');
        return;
      case ReaderLinkAction.ignore:
        return;
      case ReaderLinkAction.openExternal:
        break;
    }
    final externalUri = decision.externalUri;
    if (externalUri == null) {
      return;
    }

    final launched = await launchUrl(
      externalUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint(
        '[desktop-reader][link.open_external.failed] uri=$externalUri payload=$source',
      );
    }
  }

  Future<void> _handleMediaTapEvent(
    ReaderMediaTapData? data,
    Map<String, dynamic>? payload,
  ) async {
    final source = ReaderEventParser.selectPayload(
      typed: data?.toJson(),
      payload: payload,
    );
    if (source == null || !mounted) {
      return;
    }

    final src = ReaderEventParser.resolveMediaSource(source);
    if (src == null || src.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        final l10n = context.l10n;
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    src,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        l10n.imageLoadFailed,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopToolbar(BuildContext context) {
    final l10n = context.l10n;
    final title = _book?.title ?? '';
    final format = _book?.format.toUpperCase() ?? '';
    final progressPercent =
        ((_progress?.progression ?? 0) * 100).clamp(0, 100).toStringAsFixed(1);

    return IgnorePointer(
      ignoring: !_chromeVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _chromeVisible ? 1 : 0,
        child: Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 56,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.back,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      '$title  ·  $format  ·  $progressPercent%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.readerSettings,
                    onPressed: _openReaderSettings,
                    icon: const Icon(Icons.tune, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: l10n.searchInBookTitle,
                    onPressed: () =>
                        setState(() => _searchPanelOpen = !_searchPanelOpen),
                    icon: Icon(
                      _searchPanelOpen ? Icons.search_off : Icons.search,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.tocTitle,
                    onPressed: () => setState(() => _tocPanelOpen = true),
                    icon: const Icon(Icons.menu_book, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: l10n.statsAnnotationsTotal,
                    onPressed: _openAnnotationHub,
                    icon: const Icon(Icons.format_paint_outlined,
                        color: Colors.white),
                  ),
                  IconButton(
                    tooltip: _rendererTheme == 'day'
                        ? l10n.switchToNight
                        : l10n.switchToDay,
                    onPressed: _toggleTheme,
                    icon: Icon(
                      _rendererTheme == 'day'
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    final l10n = context.l10n;
    final progressPercent =
        ((_progress?.progression ?? 0) * 100).clamp(0, 100).toStringAsFixed(1);

    return IgnorePointer(
      ignoring: !_chromeVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _chromeVisible ? 1 : 0,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              height: 64,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.previous,
                    onPressed: () => _session?.navigatePrev(),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      l10n.readingProgress(progressPercent),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.next,
                    onPressed: () => _session?.navigateNext(),
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAnnotationHub() async {
    final store = _annotationsStore;
    if (store == null) {
      return;
    }
    final annotations = store.items
        .where(
          (item) =>
              item.type == AnnotationType.highlight ||
              (item.note?.trim().isNotEmpty ?? false),
        )
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.statsAnnotationsTotal),
          content: SizedBox(
            width: 520,
            height: 420,
            child: annotations.isEmpty
                ? Center(child: Text(l10n.noCollectionYet))
                : ListView.separated(
                    itemCount: annotations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final annotation = annotations[index];
                      return ListTile(
                        leading: Icon(
                          annotation.note?.trim().isNotEmpty ?? false
                              ? Icons.edit_note_outlined
                              : Icons.format_paint_outlined,
                        ),
                        title: Text(
                          annotation.text ??
                              annotation.note ??
                              l10n.statsHighlights,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(annotation.locator.href ?? ''),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          final href = annotation.locator.href;
                          if (href != null && href.isNotEmpty) {
                            unawaited(_session?.goTo(annotation.locator));
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleTheme() async {
    final next = _rendererTheme == 'day' ? 'night' : 'day';
    await _commitReaderSettings(
      _currentReaderSettings().copyWith(rendererTheme: next),
    );
  }

  ReaderStyle _rendererStyleFor(ReaderSettings settings) {
    return ReaderStyle(
      theme: settings.rendererTheme,
      columnCount: 1,
      pageGap: settings.pageGap.round(),
      fontSize: settings.fontSize.round(),
      lineHeight: settings.lineHeight,
      paddingTop: settings.paddingVertical.round(),
      paddingRight: settings.paddingHorizontal.round(),
      paddingBottom: settings.paddingVertical.round(),
      paddingLeft: settings.paddingHorizontal.round(),
      textIndentEnabled: settings.textIndentEnabled,
      textIndentEm: settings.textIndentEm,
      textIndentSkipFirstParagraph: settings.textIndentSkipFirstParagraph,
    );
  }

  Future<void> _applyReaderStyle() async {
    await _applyReaderStyleSnapshot(_currentReaderSettings());
  }

  Future<void> _applyReaderStyleSnapshot(ReaderSettings settings) async {
    final session = _session;
    if (session == null) {
      return;
    }
    try {
      final nextLayoutMode = _resolveRendererLayoutModeFor(settings.layoutMode);
      await session.setLayoutMode(nextLayoutMode);
      _appliedRendererLayoutMode = nextLayoutMode;
      await session.setStyle(_rendererStyleFor(settings));
    } catch (error) {
      debugPrint('[desktop-reader][setStyle.error] $error');
    }
  }

  Future<void> _commitReaderSettings(ReaderSettings settings) async {
    if (_disposed || !mounted) {
      return;
    }

    setState(() {
      _setReaderSettingsFields(settings);
    });
    _scheduleReaderSettingsSave(settings);
    _pendingReaderSettings = settings;
    await _drainReaderStyleApplies();
  }

  Future<void> _drainReaderStyleApplies() async {
    if (_styleApplyInFlight || _disposed) {
      return;
    }

    _styleApplyInFlight = true;
    try {
      while (_pendingReaderSettings != null && !_disposed) {
        final settings = _pendingReaderSettings!;
        _pendingReaderSettings = null;
        await _applyReaderStyleSnapshot(settings);
      }
    } finally {
      _styleApplyInFlight = false;
      if (_pendingReaderSettings != null && !_disposed) {
        unawaited(_drainReaderStyleApplies());
      }
    }
  }

  void _scheduleReaderSettingsSave(ReaderSettings settings) {
    _readerSettingsWriteQueue.schedule(settings);
  }

  Future<void> _openReaderSettings() async {
    await showDialog<void>(
      context: context,
      builder: (_) => DesktopReaderSettingsDialog(
        initialSettings: _currentReaderSettings(),
        onCommit: (settings) {
          unawaited(_commitReaderSettings(settings));
        },
      ),
    );
  }
}
