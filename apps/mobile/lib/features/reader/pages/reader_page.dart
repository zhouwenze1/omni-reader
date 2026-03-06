import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:foundation_application/application.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';
import 'package:kernel/kernel.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../di/engines_providers.dart';
import '../../../di/repositories_providers.dart';
import '../../../routes/route_paths.dart';
import '../../settings/controller/settings_controller.dart';
import '../widgets/dictionary_sheet.dart';
import '../widgets/reader_bottom_bar.dart';
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

class _ReaderPageState extends ConsumerState<ReaderPage> {
  ReaderSession? _session;
  StreamSubscription<ReaderEvent>? _subscription;
  ProgressRepository? _progressRepository;
  Book? _book;
  ReadingProgress? _progress;
  String? _error;
  bool _loading = true;
  double _sliderProgress = 0;

  late final DebouncedAsyncWriter<ReadingProgress> _progressWriteQueue;

  String _rendererTheme = 'day';
  double _fontSize = 18;
  double _lineHeight = 1.6;
  double _pageGap = 24;
  bool _textIndentEnabled = true;

  @override
  void initState() {
    super.initState();
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

      final session = await engine.createSession(
        book: book,
        initialProgress: progress,
        initialStyle: _currentReaderStyle(),
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
          _sliderProgress = progression;
          if (mounted) {
            setState(() {});
          }
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
        _session = session;
        _loading = false;
      });

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

  void _bootstrapReaderStyleFromSettings(ReaderSettings settings) {
    _rendererTheme = settings.rendererTheme;
    _fontSize = settings.fontSize;
    _lineHeight = settings.lineHeight;
    _pageGap = settings.pageGap;
    _textIndentEnabled = settings.textIndentEnabled;
  }

  ReaderStyle _currentReaderStyle() {
    return ReaderStyle(
      theme: _rendererTheme,
      columnCount: 1,
      pageGap: _pageGap.round(),
      fontSize: _fontSize.round(),
      lineHeight: _lineHeight,
      textIndentEnabled: _textIndentEnabled,
      textIndentEm: 2,
      textIndentSkipFirstParagraph: false,
    );
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
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'Image failed to load',
                        style: TextStyle(color: Colors.white70),
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

  Future<void> _toggleTheme() async {
    _rendererTheme = _rendererTheme == 'day' ? 'night' : 'day';
    await _applyReaderStyle();
  }

  Future<void> _applyReaderStyle() async {
    final session = _session;
    if (session == null) {
      return;
    }
    final nextSettings = ref.read(settingsControllerProvider).reader.copyWith(
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          pageGap: _pageGap,
          textIndentEnabled: _textIndentEnabled,
          rendererTheme: _rendererTheme,
        );
    await session.setStyle(_currentReaderStyle());
    await ref
        .read(settingsControllerProvider.notifier)
        .updateReader(nextSettings);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openReaderSettings() async {
    final current = ref.read(settingsControllerProvider).reader.copyWith(
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          pageGap: _pageGap,
          textIndentEnabled: _textIndentEnabled,
          rendererTheme: _rendererTheme,
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
        return;
      case 'notes':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NotesPage(bookUid: book.uid),
          ),
        );
        return;
      case 'bookmarks':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BookmarksPage(bookUid: book.uid),
          ),
        );
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
        return;
      case 'pdfOutline':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfOutlinePage(bookUid: book.uid),
          ),
        );
        return;
      case 'pdfThumb':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfThumbnailPage(bookUid: book.uid),
          ),
        );
        return;
      case 'audio':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AudioPlayerPage(bookUid: book.uid),
          ),
        );
        return;
      case 'comic':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ComicReaderPage(bookUid: book.uid),
          ),
        );
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
  }

  Future<void> _showToolSheet(Widget child) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => child,
    );
  }

  @override
  void dispose() {
    unawaited(_progressWriteQueue.close());
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reader')),
        body: Center(child: Text(_error!)),
      );
    }

    final book = _book!;
    final progress = ((_progress?.progression ?? 0) * 100).toStringAsFixed(1);

    return ReaderShell(
      appBar: ReaderTopBar(
        title: '${book.title} ($progress%)',
        actions: [
          IconButton(
            onPressed: () => context.push(RoutePaths.searchInBook(book.uid)),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () async {
              final tocItem =
                  await context.push<TocItem>(RoutePaths.toc(book.uid));
              if (tocItem?.href != null) {
                await _session?.goTo(
                  Locator(
                    href: tocItem!.href,
                    locations: _progress?.locator.locations,
                  ),
                );
              }
            },
            icon: const Icon(Icons.list),
          ),
          IconButton(
            onPressed: _toggleTheme,
            icon: Icon(
              _rendererTheme == 'day' ? Icons.dark_mode : Icons.light_mode,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: _openAuxPage,
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('\u9605\u8bfb\u8bbe\u7f6e'),
                ),
                const PopupMenuItem(
                  value: 'highlights',
                  child: Text('\u9ad8\u4eae'),
                ),
                const PopupMenuItem(
                  value: 'notes',
                  child: Text('\u7b14\u8bb0'),
                ),
                const PopupMenuItem(
                  value: 'bookmarks',
                  child: Text('\u4e66\u7b7e'),
                ),
                const PopupMenuItem(
                  value: 'debug',
                  child: Text('\u8c03\u8bd5\u4fe1\u606f'),
                ),
              ];
              if (book.format == 'pdf') {
                items.addAll(const [
                  PopupMenuItem(
                    value: 'pdfOutline',
                    child: Text('PDF \u5927\u7eb2'),
                  ),
                  PopupMenuItem(
                    value: 'pdfThumb',
                    child: Text('PDF \u7f29\u7565\u56fe'),
                  ),
                ]);
              }
              if (book.format == 'audio' ||
                  book.format.toLowerCase() == 'w3caudiobook') {
                items.add(
                  const PopupMenuItem(
                    value: 'audio',
                    child: Text('\u97f3\u9891\u64ad\u653e\u5668'),
                  ),
                );
              }
              if (book.format == 'comicZip') {
                items.add(
                  const PopupMenuItem(
                    value: 'comic',
                    child: Text('\u6f2b\u753b\u6a21\u5f0f'),
                  ),
                );
              }
              return items;
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _session!.buildView()),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'selectionTools',
              onPressed: _openSelectionTools,
              child: const Icon(Icons.auto_awesome),
            ),
          ),
        ],
      ),
      bottomBar: ReaderBottomBar(
        progress: _sliderProgress,
        onProgressChanged: (value) {
          setState(() {
            _sliderProgress = value;
          });
        },
        onProgressChangeEnd: _jumpToProgress,
        onPrev: () => _session?.navigatePrev(),
        onNext: () => _session?.navigateNext(),
      ),
    );
  }
}
