import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:foundation_application/application.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:kernel/kernel.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shared_ui/shared_ui.dart';
import 'package:services_search/services_search.dart';
import '../../../di/providers.dart';
import '../../../di/repositories_providers.dart';
import '../../../di/services_providers.dart';
import '../../../l10n/l10n.dart';
import '../../me/controller/me_controller.dart';
import '../../settings/controller/settings_controller.dart';
import '../widgets/dictionary_sheet.dart';
import '../widgets/reader_bottom_bar.dart';
import '../widgets/reader_immersive_hud.dart';
import '../widgets/reader_settings_panel.dart';
import '../widgets/reader_shell.dart';
import '../widgets/reader_top_bar.dart';
import '../widgets/selection_menu_overlay.dart';
import '../widgets/translation_sheet.dart';
import '../widgets/tts_player_sheet.dart';
import 'audio_player_page.dart';
import 'bookmarks_page.dart';
import 'comic_reader_page.dart';
import 'highlights_page.dart';
import 'notes_page.dart';
import 'pdf_outline_page.dart';
import 'pdf_thumbnail_page.dart';
import 'reader_debug_page.dart';
import 'search_in_book_page.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  static const MethodChannel _deviceStatusChannel = MethodChannel(
    'reader_mobile/device_status',
  );
  static const double _immersiveHudReserveHeight = 44;
  static const Duration _deviceStatusPollInterval = Duration(seconds: 30);

  ReaderSession? _session;
  StreamSubscription<ReaderEvent>? _subscription;
  Timer? _deviceStatusTimer;
  ProviderContainer? _providerContainer;
  ProgressRepository? _progressRepository;
  AnnotationsStore? _annotationsStore;
  Book? _book;
  ReadingProgress? _progress;
  String? _error;
  bool _loading = true;
  bool _chromeVisible = true;
  bool _isProgressDragging = false;
  bool _exitInFlight = false;
  bool _disposed = false;
  bool _searchHighlightActive = false;
  String? _searchHighlightPageKey;
  String? _searchHighlightTargetHref;
  String? _lastRelocatedPageKey;
  String? _lastRelocatedHref;
  int _searchHighlightRequestToken = 0;
  bool _systemUiRestored = false;
  double _sliderProgress = 0;
  DateTime _deviceNow = DateTime.now();
  int? _batteryLevel;
  bool _batteryCharging = false;
  SystemUiOverlayStyle _restoreOverlayStyle = SystemUiOverlayStyle.dark;

  late final DebouncedAsyncWriter<ReadingProgress> _progressWriteQueue;
  late final DebouncedAsyncWriter<ReaderSettings> _readerSettingsWriteQueue;

  String _rendererTheme = 'day';
  double _fontSize = 18;
  double _lineHeight = 1.6;
  double _pageGap = 24;
  double _paddingHorizontal = 36;
  double _paddingVertical = 16;
  bool _textIndentEnabled = true;
  double _textIndentEm = 2;
  bool _textIndentSkipFirstParagraph = false;
  String _layoutMode = ReaderLayoutMode.pagedAuto;
  String? _appliedRendererLayoutMode;
  String? _appliedReaderStyleSignature;
  bool _layoutSyncScheduled = false;
  bool _readerStyleSyncScheduled = false;
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
    _startDeviceStatusRefresh();
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
          debugPrint('[mobile-reader][saveProgress.error] $error');
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
          debugPrint('[mobile-reader][saveReaderSettings.error] $error');
        }
      },
    );
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerContainer ??= ProviderScope.containerOf(context, listen: false);
    _restoreOverlayStyle = _overlayStyleForBrightness(
      Theme.of(context).brightness,
    );
  }

  Future<void> _init() async {
    try {
      final settings =
          await ref.read(settingsRepositoryProvider).getReaderSettings();
      _bootstrapReaderStyleFromSettings(settings);

      final bookRepository = ref.read(bookRepositoryProvider);
      final progressRepository = ref.read(progressRepositoryProvider);
      _progressRepository = progressRepository;
      final registry = ref.read(engineRegistryProvider);

      final book = await bookRepository.getBook(widget.bookUid);
      if (!mounted) {
        return;
      }
      if (book == null) {
        setState(() {
          _error = 'Book not found: ${widget.bookUid}';
          _loading = false;
        });
        return;
      }

      var progress = await progressRepository.getProgress(widget.bookUid);
      if (!mounted) {
        return;
      }
      // 打开图书时按需同步这一本书:远端 updatedAt 更新则接上上次阅读位置。
      final remoteProgress = await ref
          .read(syncServiceProvider)
          .pullBookOnOpen(widget.bookUid);
      if (remoteProgress != null) {
        progress = remoteProgress;
      }
      if (!mounted) {
        return;
      }
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
        initialStyle: _currentReaderStyle(),
        initialLayoutMode: initialLayoutMode,
      );
      await session.setActiveHighlights(annotationsStore.readerHighlights);

      _subscription = session.events.listen((event) async {
        if (_disposed) {
          return;
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
          _scheduleProgressSave(nextProgress);
          _progress = nextProgress;
          if (!_isProgressDragging) {
            _sliderProgress = progression;
          }
          if (mounted) {
            setState(() {});
          }
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
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _book = book;
        _progress = progress;
        _annotationsStore = annotationsStore;
        _sliderProgress = progress?.progression ?? 0;
        _appliedReaderStyleSignature = _readerStyleSignature(
          _currentReaderStyle(),
        );
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

      unawaited(_openSession(session));
      unawaited(_enterImmersiveMode());
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

  void _bootstrapReaderStyleFromSettings(ReaderSettings settings) {
    _rendererTheme = settings.rendererTheme;
    _fontSize = settings.fontSize;
    _lineHeight = settings.lineHeight;
    _pageGap = settings.pageGap;
    _paddingHorizontal = settings.paddingHorizontal;
    _paddingVertical = settings.paddingVertical;
    _textIndentEnabled = settings.textIndentEnabled;
    _textIndentEm = settings.textIndentEm;
    _textIndentSkipFirstParagraph = settings.textIndentSkipFirstParagraph;
    _layoutMode = ReaderLayoutMode.normalize(settings.layoutMode);
  }

  ReaderSettings _currentReaderSettings() {
    final current = ref.read(settingsControllerProvider).reader;
    return current.copyWith(
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageGap: _pageGap,
      paddingHorizontal: _paddingHorizontal,
      paddingVertical: _paddingVertical,
      textIndentEnabled: _textIndentEnabled,
      textIndentEm: _textIndentEm,
      textIndentSkipFirstParagraph: _textIndentSkipFirstParagraph,
      rendererTheme: _rendererTheme,
      layoutMode: _layoutMode,
      progressDisplay: 'bar',
    );
  }

  ReaderStyle _readerStyleFor(ReaderSettings settings) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final viewPadding = mediaQuery?.viewPadding ?? EdgeInsets.zero;
    return ReaderStyle(
      theme: settings.rendererTheme,
      columnCount: 1,
      pageGap: settings.pageGap.round(),
      fontSize: settings.fontSize.round(),
      lineHeight: settings.lineHeight,
      paddingTop: (settings.paddingVertical + viewPadding.top).round(),
      paddingRight: (settings.paddingHorizontal + viewPadding.right).round(),
      paddingBottom: (settings.paddingVertical +
              viewPadding.bottom +
              _immersiveHudReserveHeight)
          .round(),
      paddingLeft: (settings.paddingHorizontal + viewPadding.left).round(),
      textIndentEnabled: settings.textIndentEnabled,
      textIndentEm: settings.textIndentEm,
      textIndentSkipFirstParagraph: settings.textIndentSkipFirstParagraph,
    );
  }

  ReaderStyle _currentReaderStyle() {
    return _readerStyleFor(_currentReaderSettings());
  }

  String _readerStyleSignature(ReaderStyle style) {
    return jsonEncode(style.toJson());
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

  String _resolveRendererLayoutMode() {
    return _resolveRendererLayoutModeFor(_layoutMode);
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
      debugPrint('[mobile-reader][setLayoutMode.error] $error');
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

  Future<void> _syncViewportReaderStyle({bool force = false}) async {
    final session = _session;
    if (session == null) {
      return;
    }
    final nextStyle = _currentReaderStyle();
    final nextSignature = _readerStyleSignature(nextStyle);
    if (!force && nextSignature == _appliedReaderStyleSignature) {
      return;
    }
    try {
      await session.setStyle(nextStyle);
      _appliedReaderStyleSignature = nextSignature;
    } catch (error) {
      debugPrint('[mobile-reader][syncViewportReaderStyle.error] $error');
    }
  }

  void _scheduleViewportReaderStyleSync() {
    final session = _session;
    if (session == null || _readerStyleSyncScheduled) {
      return;
    }
    final nextSignature = _readerStyleSignature(_currentReaderStyle());
    if (nextSignature == _appliedReaderStyleSignature) {
      return;
    }
    _readerStyleSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readerStyleSyncScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_syncViewportReaderStyle());
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

  Future<void> _enterImmersiveMode() async {
    _systemUiRestored = false;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  void _startDeviceStatusRefresh() {
    unawaited(_refreshDeviceStatus());
    _scheduleNextDeviceStatusRefresh();
  }

  void _scheduleNextDeviceStatusRefresh() {
    if (!mounted) {
      return;
    }
    _deviceStatusTimer?.cancel();
    _deviceStatusTimer = Timer(_deviceStatusPollInterval, () {
      unawaited(
        _refreshDeviceStatus().whenComplete(_scheduleNextDeviceStatusRefresh),
      );
    });
  }

  Future<void> _refreshDeviceStatus() async {
    final now = DateTime.now();
    final battery = await _readBatteryStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceNow = now;
      _batteryLevel = battery.$1 ?? _batteryLevel;
      _batteryCharging = battery.$2;
    });
  }

  Future<(int?, bool)> _readBatteryStatus() async {
    try {
      final status = await _deviceStatusChannel
          .invokeMethod<Map<Object?, Object?>>('getBatteryStatus');
      if (status == null) {
        return (null, false);
      }
      final level = status['level'];
      final validLevel =
          level is int && level >= 0 && level <= 100 ? level : null;
      final charging = status['charging'] == true;
      return (validLevel, charging);
    } on MissingPluginException {
      return (null, false);
    } on PlatformException {
      return (null, false);
    }
  }

  String _buildImmersiveProgressText() {
    final percent = _sliderProgress.clamp(0.0, 1.0) * 100;
    return '${percent.toStringAsFixed(percent >= 10 ? 0 : 1)}%';
  }

  SystemUiOverlayStyle _overlayStyleForBrightness(Brightness brightness) {
    return brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
  }

  Future<void> _restoreSystemUiIfNeeded() async {
    if (_systemUiRestored) {
      return;
    }
    _systemUiRestored = true;
    SystemChrome.setSystemUIOverlayStyle(_restoreOverlayStyle);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _requestExitReader() async {
    if (_exitInFlight) {
      return;
    }
    _exitInFlight = true;
    try {
      await _restoreSystemUiIfNeeded();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      await navigator.maybePop();
    } finally {
      _exitInFlight = false;
    }
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
      unawaited(_enterImmersiveMode());
      unawaited(_refreshDeviceStatus());
    }
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
      unawaited(_enterImmersiveMode());
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
    if (decision.action != ReaderLinkAction.openExternal) {
      return;
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
      debugPrint('[mobile-reader][link.open_external.failed] uri=$externalUri');
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
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
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
                top: 12,
                right: 12,
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
    await _enterImmersiveMode();
  }

  void _scheduleProgressSave(ReadingProgress progress) {
    if (_disposed) {
      return;
    }
    _progressWriteQueue.schedule(progress);
  }

  Future<void> _jumpToProgress(double value) async {
    final session = _session;
    if (session == null) {
      return;
    }
    await session.goTo(Locator(locations: {'progression': value.clamp(0, 1)}));
  }

  void _handleProgressChangeStart(double value) {
    setState(() {
      _isProgressDragging = true;
      _sliderProgress = value;
    });
  }

  Future<void> _handleProgressChangeEnd(double value) async {
    setState(() {
      _isProgressDragging = false;
      _sliderProgress = value;
    });
    await _jumpToProgress(value);
  }

  Future<void> _toggleTheme() async {
    await _commitReaderSettings(
      _currentReaderSettings().copyWith(
        rendererTheme: _rendererTheme == 'day' ? 'night' : 'day',
      ),
    );
  }

  Future<void> _commitReaderSettings(ReaderSettings settings) async {
    if (_disposed || !mounted) {
      return;
    }
    setState(() {
      _bootstrapReaderStyleFromSettings(settings);
    });
    _readerSettingsWriteQueue.schedule(settings);
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

  Future<void> _applyReaderStyleSnapshot(ReaderSettings settings) async {
    final session = _session;
    if (session == null) {
      return;
    }
    try {
      final previousLayoutMode = _appliedRendererLayoutMode;
      final nextLayoutMode = _resolveRendererLayoutModeFor(settings.layoutMode);
      final layoutChanged = nextLayoutMode != previousLayoutMode;
      if (layoutChanged) {
        await session.setLayoutMode(nextLayoutMode);
        _appliedRendererLayoutMode = nextLayoutMode;
      }
      final nextStyle = _readerStyleFor(settings);
      final styleSignature = _readerStyleSignature(nextStyle);
      if (styleSignature != _appliedReaderStyleSignature) {
        await session.setStyle(nextStyle);
        _appliedReaderStyleSignature = styleSignature;
      }
      if (layoutChanged) {
        // 布局模式切换会触发渲染器重新排版,若不恢复位置会跳回章首。
        // 用当前 relocated locator 重新定位,保持阅读位置。
        final locator = _progress?.locator;
        if (locator != null && mounted) {
          unawaited(session.goTo(locator));
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('[mobile-reader][applyReaderStyle.error] $error');
    }
  }

  Future<void> _openReaderSettings() async {
    final current = _currentReaderSettings();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ReaderSettingsPanel(
          settings: current,
          onChanged: (settings) async {
            await _commitReaderSettings(settings);
          },
        );
      },
    );
    await _enterImmersiveMode();
  }

  Future<void> _openToc() async {
    final book = _book;
    if (book == null) {
      return;
    }
    final tocItem = await context.push<TocItem>(RoutePaths.toc(book.uid));
    if (tocItem?.href != null) {
      await _session?.goTo(Locator(href: tocItem!.href));
    }
    await _enterImmersiveMode();
  }

  Future<void> _selectSearchHit(SearchHit hit, int token) async {
    final session = _session;
    if (session == null || hit.href == null) return;
    try {
      await session.goTo(Locator(href: hit.href, cfi: hit.cfi));
      await _highlightSearchHit(hit, token);
    } catch (error) {
      if (token == _searchHighlightRequestToken && !_disposed) {
        debugPrint('[mobile-reader][search-highlight.error] $error');
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
    final rects = data!.rects.map(_rectFromJson).whereType<ui.Rect>();
    final rect = unionRects(rects);
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

  double? _number(dynamic value) {
    return value is num ? value.toDouble() : null;
  }

  (Offset, double) _selectionMenuLayout(BuildContext context) {
    final rect = _selectionRect ?? ui.Rect.zero;
    final viewport = MediaQuery.sizeOf(context);
    final menuWidth = (viewport.width - 16).clamp(240.0, 460.0);
    final offset = computeMenuOffset(
      selectionRect: rect,
      viewport: viewport,
      menuSize: Size(menuWidth, 64),
    );
    return (offset, menuWidth);
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
    final cached = _selectionQuote;
    if (cached != null) {
      return cached;
    }
    final pending = _selectionQuoteFuture;
    if (pending != null) {
      return pending;
    }
    final session = _session;
    if (session == null) {
      return null;
    }
    return session.getSelectionQuote();
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
      final highlight = ReaderHighlight(
        uid: uid,
        href: selection.href,
        color: color,
        quote: selection.quote,
        cfi: selection.cfi,
      );
      final applied = await session.applyUserHighlight(highlight);
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
    final current = _editingAnnotation?.note;
    final note = await _showNoteEditor(current);
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
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 5,
                decoration: InputDecoration(labelText: l10n.annotationNote),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(controller.text),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
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

  Future<void> _openAnnotationHub() async {
    final l10n = context.l10n;
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.format_paint_outlined),
                title: Text(l10n.highlights),
                onTap: () => Navigator.of(context).pop('highlights'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: Text(l10n.notes),
                onTap: () => Navigator.of(context).pop('notes'),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: Text(l10n.bookmarks),
                onTap: () => Navigator.of(context).pop('bookmarks'),
              ),
            ],
          ),
        );
      },
    );
    if (selection != null) {
      await _openAuxPage(selection);
    }
    await _enterImmersiveMode();
  }

  Future<void> _openMoreActions() async {
    final book = _book;
    if (book == null) {
      return;
    }
    final l10n = context.l10n;
    final actions = <_ReaderSheetAction>[
      _ReaderSheetAction(
        value: 'debug',
        icon: Icons.bug_report_outlined,
        label: l10n.debugInfo,
      ),
    ];
    if (book.format == 'pdf') {
      actions.addAll(<_ReaderSheetAction>[
        _ReaderSheetAction(
          value: 'pdfOutline',
          icon: Icons.account_tree_outlined,
          label: l10n.pdfOutline,
        ),
        _ReaderSheetAction(
          value: 'pdfThumb',
          icon: Icons.grid_view_outlined,
          label: l10n.pdfThumbnails,
        ),
      ]);
    }
    if (book.format == 'audio' || book.format.toLowerCase() == 'w3caudiobook') {
      actions.add(
        _ReaderSheetAction(
          value: 'audio',
          icon: Icons.graphic_eq_outlined,
          label: l10n.audioPlayer,
        ),
      );
    }
    if (book.format == 'comicZip') {
      actions.add(
        _ReaderSheetAction(
          value: 'comic',
          icon: Icons.auto_stories_outlined,
          label: l10n.comicMode,
        ),
      );
    }

    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: actions.map((action) {
              return ListTile(
                leading: Icon(action.icon),
                title: Text(action.label),
                onTap: () => Navigator.of(context).pop(action.value),
              );
            }).toList(),
          ),
        );
      },
    );
    if (selection != null) {
      await _openAuxPage(selection);
    }
    await _enterImmersiveMode();
  }

  Future<void> _openAuxPage(String value) async {
    final book = _book;
    if (book == null) {
      return;
    }
    switch (value) {
      case 'settings':
        await _openReaderSettings();
        return;
      case 'highlights':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HighlightsPage(bookUid: book.uid),
          ),
        );
        await _enterImmersiveMode();
        return;
      case 'notes':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => NotesPage(bookUid: book.uid)),
        );
        await _enterImmersiveMode();
        return;
      case 'bookmarks':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookmarksPage(bookUid: book.uid),
          ),
        );
        await _enterImmersiveMode();
        return;
      case 'debug':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReaderDebugPage(
              bookUid: book.uid,
              bookTitle: book.title,
              format: book.format,
              progress: _progress?.progression ?? 0,
            ),
          ),
        );
        await _enterImmersiveMode();
        return;
      case 'pdfOutline':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfOutlinePage(bookUid: book.uid),
          ),
        );
        await _enterImmersiveMode();
        return;
      case 'pdfThumb':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfThumbnailPage(bookUid: book.uid),
          ),
        );
        await _enterImmersiveMode();
        return;
      case 'audio':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AudioPlayerPage(bookUid: book.uid),
          ),
        );
        await _enterImmersiveMode();
        return;
      case 'comic':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ComicReaderPage(bookUid: book.uid),
          ),
        );
        await _enterImmersiveMode();
        return;
    }
  }

  Future<void> _openSelectionTools() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SelectionMenuOverlay(
            onDictionary: () {
              Navigator.of(context).pop();
              _showToolSheet(
                const DictionarySheet(text: '\u9009\u4e2d\u6587\u672c'),
              );
            },
            onTranslate: () {
              Navigator.of(context).pop();
              _showToolSheet(
                const TranslationSheet(text: '\u9009\u4e2d\u6587\u672c'),
              );
            },
            onSpeak: () {
              Navigator.of(context).pop();
              _showToolSheet(
                const TtsPlayerSheet(text: '\u9009\u4e2d\u6587\u672c'),
              );
            },
          ),
        );
      },
    );
    await _enterImmersiveMode();
  }

  Future<void> _showToolSheet(Widget child) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => child,
    ).whenComplete(_enterImmersiveMode);
  }

  @override
  void dispose() {
    _disposed = true;
    _readingRecorder?.dispose();
    // 与桌面端对齐:书内搜索状态(输入 + 结果)随阅读页销毁,不跨阅读会话保留。
    clearBookSearchSession(widget.bookUid);
    WidgetsBinding.instance.removeObserver(this);
    _deviceStatusTimer?.cancel();
    final providerContainer = _providerContainer;
    if (providerContainer != null) {
      providerContainer.invalidate(libraryIndexProvider);
      // 不 invalidate 书架控制器:重建会丢掉用户当前选中的合集。
      // 书架页在 reader 返回后自行 refresh,进度数据同步由它负责。
      providerContainer.invalidate(meControllerProvider);
      providerContainer.invalidate(weeklyReadingSummaryProvider);
      providerContainer.invalidate(statsCenterProvider);
    }
    unawaited(_progressWriteQueue.close().then((_) {
      // 进度 flush 后推送该书到同步服务器。
      final container = _providerContainer;
      if (container == null) return;
      final syncService = container.read(syncServiceProvider);
      unawaited(syncService.pushBookOnExit(widget.bookUid));
    }));
    unawaited(_readerSettingsWriteQueue.close());
    final subscription = _subscription;
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((_) {}));
    }
    final session = _session;
    if (session != null) {
      unawaited(session.dispose().catchError((_) {}));
    }
    unawaited(_restoreSystemUiIfNeeded());
    super.dispose();
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

    final book = _book!;
    _scheduleViewportLayoutSync();
    _scheduleViewportReaderStyleSync();
    final chromePalette = _ReaderChromePalette.resolve(_rendererTheme);
    final immersiveOverlayHorizontalPadding =
        _paddingHorizontal.clamp(20, 44).toDouble();

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_requestExitReader());
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ReaderShell(
            backgroundColor: chromePalette.pageBackground,
            chromeVisible: _chromeVisible,
            topBar: ReaderTopBar(
              onBackPressed: _requestExitReader,
              title: book.title,
              backgroundColor: chromePalette.chromeBackground,
              foregroundColor: chromePalette.chromeForeground,
              borderColor: chromePalette.chromeBorder,
              actions: [
                IconButton(
                  tooltip: l10n.search,
                  onPressed: () async {
                    final hit = await context.push<SearchHit>(
                      RoutePaths.searchInBook(book.uid),
                    );
                    if (hit != null && hit.href != null) {
                      final token = ++_searchHighlightRequestToken;
                      _searchHighlightActive = false;
                      _searchHighlightPageKey = null;
                      _searchHighlightTargetHref = _normalizeHrefKey(hit.href);
                      await _selectSearchHit(hit, token);
                    }
                    await _enterImmersiveMode();
                  },
                  icon: Icon(
                    Icons.search,
                    color: chromePalette.chromeForeground,
                  ),
                ),
                IconButton(
                  tooltip: l10n.switchThemeQuick,
                  onPressed: _toggleTheme,
                  icon: Icon(
                    _rendererTheme == 'day'
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: chromePalette.chromeForeground,
                  ),
                ),
              ],
            ),
            immersiveOverlayPadding: EdgeInsets.fromLTRB(
              immersiveOverlayHorizontalPadding,
              0,
              immersiveOverlayHorizontalPadding,
              12,
            ),
            immersiveOverlay: ReaderImmersiveHud(
              timeText: TimeOfDay.fromDateTime(_deviceNow).format(context),
              batteryLevel: _batteryLevel,
              batteryCharging: _batteryCharging,
              progress: _sliderProgress,
              progressText: _buildImmersiveProgressText(),
              darkMode: chromePalette.isDark,
            ),
            body: _session!.buildView(),
            floatingActionButton: FloatingActionButton.small(
              heroTag: 'selectionTools',
              onPressed: _openSelectionTools,
              backgroundColor: chromePalette.fabBackground,
              foregroundColor: chromePalette.fabForeground,
              child: const Icon(Icons.auto_awesome),
            ),
            bottomBar: ReaderBottomBar(
              progress: _sliderProgress,
              backgroundColor: chromePalette.chromeBackground,
              foregroundColor: chromePalette.chromeForeground,
              borderColor: chromePalette.chromeBorder,
              progressActiveColor: chromePalette.sliderActive,
              progressInactiveColor: chromePalette.sliderInactive,
              onProgressChangeStart: _handleProgressChangeStart,
              onProgressChanged: (value) {
                setState(() {
                  _sliderProgress = value;
                });
              },
              onProgressChangeEnd: _handleProgressChangeEnd,
              onPrev: () => _session?.navigatePrev(),
              onNext: () => _session?.navigateNext(),
              onOpenToc: _openToc,
              onOpenAnnotations: _openAnnotationHub,
              onOpenSettings: _openReaderSettings,
              onOpenMore: _openMoreActions,
            ),
          ),
          if (_selectionMenuVisible && _selectionRect != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _dismissSelectionMenu();
                },
              ),
            ),
          if (_selectionMenuVisible && _selectionRect != null)
            Builder(builder: (context) {
              final (menuOffset, menuWidth) = _selectionMenuLayout(context);
              return Positioned(
                left: menuOffset.dx,
                top: menuOffset.dy,
                width: menuWidth,
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
              );
            }),
        ],
      ),
    );
  }
}

class _ReaderSheetAction {
  const _ReaderSheetAction({
    required this.value,
    required this.icon,
    required this.label,
  });

  final String value;
  final IconData icon;
  final String label;
}

class _ReaderChromePalette {
  const _ReaderChromePalette({
    required this.pageBackground,
    required this.chromeBackground,
    required this.chromeForeground,
    required this.chromeBorder,
    required this.sliderActive,
    required this.sliderInactive,
    required this.fabBackground,
    required this.fabForeground,
    required this.isDark,
  });

  final Color pageBackground;
  final Color chromeBackground;
  final Color chromeForeground;
  final Color chromeBorder;
  final Color sliderActive;
  final Color sliderInactive;
  final Color fabBackground;
  final Color fabForeground;
  final bool isDark;

  static _ReaderChromePalette resolve(String theme) {
    final normalized = theme.toLowerCase();
    if (normalized == 'night' || normalized == 'dark') {
      const foreground = Color(0xFFE7EAF0);
      return _ReaderChromePalette(
        pageBackground: const Color(0xFF0F1115),
        chromeBackground: const Color(0xE60F1115),
        chromeForeground: foreground,
        chromeBorder: const Color(0x26FFFFFF),
        sliderActive: foreground,
        sliderInactive: const Color(0x33E7EAF0),
        fabBackground: const Color(0xFF1A1E26),
        fabForeground: foreground,
        isDark: true,
      );
    }
    if (normalized == 'sepia' || normalized == 'tea') {
      const foreground = Color(0xFF3B2F24);
      return _ReaderChromePalette(
        pageBackground: const Color(0xFFF4ECD8),
        chromeBackground: const Color(0xEEF4ECD8),
        chromeForeground: foreground,
        chromeBorder: const Color(0x1F000000),
        sliderActive: foreground,
        sliderInactive: const Color(0x333B2F24),
        fabBackground: const Color(0xFFE8DCC0),
        fabForeground: foreground,
        isDark: false,
      );
    }
    const foreground = Color(0xFF111318);
    return _ReaderChromePalette(
      pageBackground: Colors.white,
      chromeBackground: const Color(0xEEFFFFFF),
      chromeForeground: foreground,
      chromeBorder: const Color(0x16000000),
      sliderActive: foreground,
      sliderInactive: const Color(0x33111318),
      fabBackground: const Color(0xFFF3F5F8),
      fabForeground: foreground,
      isDark: false,
    );
  }
}
