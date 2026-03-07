import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:foundation_application/application.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:kernel/kernel.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../di/engines_providers.dart';
import '../../../di/providers.dart';
import '../../../di/repositories_providers.dart';
import '../../../l10n/l10n.dart';
import '../../../routes/route_paths.dart';
import '../../library/controller/library_controller.dart';
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

  ReaderSession? _session;
  StreamSubscription<ReaderEvent>? _subscription;
  Timer? _deviceStatusTimer;
  ProgressRepository? _progressRepository;
  Book? _book;
  ReadingProgress? _progress;
  String? _error;
  bool _loading = true;
  bool _chromeVisible = true;
  bool _isProgressDragging = false;
  double _sliderProgress = 0;
  DateTime _deviceNow = DateTime.now();
  int? _batteryLevel;
  SystemUiOverlayStyle _restoreOverlayStyle = SystemUiOverlayStyle.dark;

  late final DebouncedAsyncWriter<ReadingProgress> _progressWriteQueue;

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
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreOverlayStyle =
        _overlayStyleForBrightness(Theme.of(context).brightness);
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
      if (book == null) {
        setState(() {
          _error = 'Book not found: ${widget.bookUid}';
          _loading = false;
        });
        return;
      }

      final progress = await progressRepository.getProgress(widget.bookUid);
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

      _subscription = session.events.listen((event) async {
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
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _book = book;
        _progress = progress;
        _sliderProgress = progress?.progression ?? 0;
        _appliedReaderStyleSignature = _readerStyleSignature(
          _currentReaderStyle(),
        );
        _appliedRendererLayoutMode = initialLayoutMode;
        _session = session;
        _loading = false;
      });

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

  ReaderStyle _currentReaderStyle() {
    final mediaQuery = MediaQuery.maybeOf(context);
    final viewPadding = mediaQuery?.viewPadding ?? EdgeInsets.zero;
    return ReaderStyle(
      theme: _rendererTheme,
      columnCount: 1,
      pageGap: _pageGap.round(),
      fontSize: _fontSize.round(),
      lineHeight: _lineHeight,
      paddingTop: (_paddingVertical + viewPadding.top).round(),
      paddingRight: (_paddingHorizontal + viewPadding.right).round(),
      paddingBottom:
          (_paddingVertical + viewPadding.bottom + _immersiveHudReserveHeight)
              .round(),
      paddingLeft: (_paddingHorizontal + viewPadding.left).round(),
      textIndentEnabled: _textIndentEnabled,
      textIndentEm: _textIndentEm,
      textIndentSkipFirstParagraph: _textIndentSkipFirstParagraph,
    );
  }

  String _readerStyleSignature(ReaderStyle style) {
    return jsonEncode(style.toJson());
  }

  String _resolveRendererLayoutMode() {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return ReaderLayoutMode.normalizeRendererMode(_layoutMode);
    }
    return ReaderLayoutMode.resolveAdaptive(
      _layoutMode,
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
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _deviceStatusTimer = Timer(nextMinute.difference(now), () {
      unawaited(
        _refreshDeviceStatus().whenComplete(_scheduleNextDeviceStatusRefresh),
      );
    });
  }

  Future<void> _refreshDeviceStatus() async {
    final now = DateTime.now();
    final batteryLevel = await _readBatteryLevel();
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceNow = now;
      _batteryLevel = batteryLevel ?? _batteryLevel;
    });
  }

  Future<int?> _readBatteryLevel() async {
    try {
      final level = await _deviceStatusChannel.invokeMethod<int>(
        'getBatteryLevel',
      );
      if (level == null || level < 0 || level > 100) {
        return null;
      }
      return level;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
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

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_restoreOverlayStyle);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
    _rendererTheme = _rendererTheme == 'day' ? 'night' : 'day';
    await _applyReaderStyle();
  }

  Future<void> _applyReaderStyle() async {
    final session = _session;
    if (session == null) {
      return;
    }
    try {
      final nextSettings = ref.read(settingsControllerProvider).reader.copyWith(
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
      final nextStyle = _currentReaderStyle();
      await session.setLayoutMode(_resolveRendererLayoutMode());
      _appliedRendererLayoutMode = _resolveRendererLayoutMode();
      await session.setStyle(nextStyle);
      _appliedReaderStyleSignature = _readerStyleSignature(nextStyle);
      await ref
          .read(settingsControllerProvider.notifier)
          .updateReader(nextSettings);
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('[mobile-reader][applyReaderStyle.error] $error');
    }
  }

  Future<void> _openReaderSettings() async {
    final current = ref.read(settingsControllerProvider).reader.copyWith(
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
        );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ReaderSettingsPanel(
          settings: current,
          onChanged: (settings) async {
            _bootstrapReaderStyleFromSettings(settings);
            await _applyReaderStyle();
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
      await _session?.goTo(
        Locator(
          href: tocItem!.href,
          locations: _progress?.locator.locations,
        ),
      );
    }
    await _enterImmersiveMode();
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
          MaterialPageRoute<void>(
            builder: (_) => NotesPage(bookUid: book.uid),
          ),
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
    WidgetsBinding.instance.removeObserver(this);
    _deviceStatusTimer?.cancel();
    ref.invalidate(libraryIndexProvider);
    ref.invalidate(mobileLibraryControllerProvider);
    ref.invalidate(meControllerProvider);
    unawaited(_progressWriteQueue.close());
    final subscription = _subscription;
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((_) {}));
    }
    final session = _session;
    if (session != null) {
      unawaited(session.dispose().catchError((_) {}));
    }
    _restoreSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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

    return ReaderShell(
      backgroundColor: chromePalette.pageBackground,
      chromeVisible: _chromeVisible,
      topBar: ReaderTopBar(
        onBackPressed: () => Navigator.of(context).maybePop(),
        title: book.title,
        backgroundColor: chromePalette.chromeBackground,
        foregroundColor: chromePalette.chromeForeground,
        borderColor: chromePalette.chromeBorder,
        actions: [
          IconButton(
            tooltip: l10n.search,
            onPressed: () async {
              await context.push(RoutePaths.searchInBook(book.uid));
              await _enterImmersiveMode();
            },
            icon: Icon(Icons.search, color: chromePalette.chromeForeground),
          ),
          IconButton(
            tooltip: l10n.switchThemeQuick,
            onPressed: _toggleTheme,
            icon: Icon(
              _rendererTheme == 'day' ? Icons.dark_mode : Icons.light_mode,
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
