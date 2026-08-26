import 'dart:async';

import 'package:foundation_application/application.dart';
import 'package:kernel/kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../di/engines_providers.dart';
import '../../../di/repositories_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/controller/settings_controller.dart';
import '../../settings/controller/settings_state.dart';

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
  Book? _book;
  ReadingProgress? _progress;
  String? _error;
  bool _loading = true;
  bool _chromeVisible = false;
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_progressWriteQueue.flush());
      unawaited(_readerSettingsWriteQueue.flush());
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
        initialLayoutMode: initialLayoutMode,
      );

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
        _appliedRendererLayoutMode = initialLayoutMode;
        _session = session;
        _loading = false;
      });

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
    final reader = settingsState.reader;
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
        ],
      ),
    );
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
    final progressPercent = ((_progress?.progression ?? 0) * 100)
        .clamp(0, 100)
        .toStringAsFixed(1);

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
    final progressPercent = ((_progress?.progression ?? 0) * 100)
        .clamp(0, 100)
        .toStringAsFixed(1);

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

  Future<void> _toggleTheme() async {
    final next = _rendererTheme == 'day' ? 'night' : 'day';
    setState(() {
      _rendererTheme = next;
    });
    await _applyReaderStyle();
  }

  ReaderStyle _currentReaderStyle() {
    return ReaderStyle(
      theme: _rendererTheme,
      columnCount: 1,
      pageGap: _pageGap.round(),
      fontSize: _fontSize.round(),
      lineHeight: _lineHeight,
      paddingTop: _paddingTopBottom.round(),
      paddingRight: _paddingLeftRight.round(),
      paddingBottom: _paddingTopBottom.round(),
      paddingLeft: _paddingLeftRight.round(),
      textIndentEnabled: _textIndentEnabled,
      textIndentEm: _textIndentEm,
      textIndentSkipFirstParagraph: _textIndentSkipFirst,
    );
  }

  Future<void> _applyReaderStyle() async {
    final session = _session;
    if (session == null) {
      return;
    }
    try {
      final nextLayoutMode = _resolveRendererLayoutMode();
      await session.setLayoutMode(nextLayoutMode);
      _appliedRendererLayoutMode = nextLayoutMode;
      await session.setStyle(_currentReaderStyle());
      final currentSettings = ref.read(settingsControllerProvider).reader;
      final nextSettings = currentSettings.copyWith(
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
      _scheduleReaderSettingsSave(nextSettings);
    } catch (error) {
      debugPrint('[desktop-reader][setStyle.error] $error');
    }
  }

  void _scheduleReaderSettingsSave(ReaderSettings settings) {
    _readerSettingsWriteQueue.schedule(settings);
  }

  Future<void> _openReaderSettings() async {
    final hostContext = context;
    await showDialog<void>(
      context: hostContext,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> applyFromDialog() async {
              setState(() {});
              await _applyReaderStyle();
            }

            return Dialog(
              backgroundColor: const Color(0xFF1A1A1A),
              child: SizedBox(
                width: 420,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.readerSettings,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSliderControl(
                        label: l10n.fontSize,
                        valueLabel: _fontSize.toStringAsFixed(0),
                        min: 12,
                        max: 42,
                        value: _fontSize,
                        onChanged: (v) async {
                          setDialogState(() {
                            _fontSize = v;
                          });
                          await applyFromDialog();
                        },
                      ),
                      _buildSliderControl(
                        label: l10n.lineHeight,
                        valueLabel: _lineHeight.toStringAsFixed(2),
                        min: 1.1,
                        max: 2.4,
                        value: _lineHeight,
                        onChanged: (v) async {
                          setDialogState(() {
                            _lineHeight = v;
                          });
                          await applyFromDialog();
                        },
                      ),
                      _buildSliderControl(
                        label: l10n.pageGap,
                        valueLabel: _pageGap.toStringAsFixed(0),
                        min: 0,
                        max: 80,
                        value: _pageGap,
                        onChanged: (v) async {
                          setDialogState(() {
                            _pageGap = v;
                          });
                          await applyFromDialog();
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _layoutMode,
                        decoration: const InputDecoration(
                          labelText: 'Layout mode',
                        ),
                        dropdownColor: const Color(0xFF1A1A1A),
                        items: const [
                          DropdownMenuItem(
                            value: ReaderLayoutMode.pagedAuto,
                            child: Text('Auto'),
                          ),
                          DropdownMenuItem(
                            value: ReaderLayoutMode.pagedSingle,
                            child: Text('Single'),
                          ),
                          DropdownMenuItem(
                            value: ReaderLayoutMode.pagedSpread,
                            child: Text('Spread'),
                          ),
                          DropdownMenuItem(
                            value: ReaderLayoutMode.scrollBoundary,
                            child: Text('Boundary'),
                          ),
                          DropdownMenuItem(
                            value: ReaderLayoutMode.scrollContinuous,
                            child: Text('Continuous'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            _layoutMode = value;
                          });
                          await applyFromDialog();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildSliderControl(
                        label: l10n.horizontalPadding,
                        valueLabel: _paddingLeftRight.toStringAsFixed(0),
                        min: 0,
                        max: 100,
                        value: _paddingLeftRight,
                        onChanged: (v) async {
                          setDialogState(() {
                            _paddingLeftRight = v;
                          });
                          await applyFromDialog();
                        },
                      ),
                      _buildSliderControl(
                        label: l10n.verticalPadding,
                        valueLabel: _paddingTopBottom.toStringAsFixed(0),
                        min: 0,
                        max: 80,
                        value: _paddingTopBottom,
                        onChanged: (v) async {
                          setDialogState(() {
                            _paddingTopBottom = v;
                          });
                          await applyFromDialog();
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.lightBlueAccent,
                        title: Text(
                          l10n.enableTextIndent,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: _textIndentEnabled,
                        onChanged: (v) async {
                          setDialogState(() {
                            _textIndentEnabled = v;
                          });
                          await applyFromDialog();
                        },
                      ),
                      _buildSliderControl(
                        label: l10n.indentSizeEm,
                        valueLabel: _textIndentEm.toStringAsFixed(1),
                        min: 0,
                        max: 4,
                        value: _textIndentEm,
                        onChanged: (v) async {
                          setDialogState(() {
                            _textIndentEm = v;
                          });
                          await applyFromDialog();
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.lightBlueAccent,
                        title: Text(
                          l10n.skipFirstParagraphIndent,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: _textIndentSkipFirst,
                        onChanged: (v) async {
                          setDialogState(() {
                            _textIndentSkipFirst = v;
                          });
                          await applyFromDialog();
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(l10n.close),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSliderControl({
    required String label,
    required String valueLabel,
    required double min,
    required double max,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white70)),
            ),
            Text(valueLabel, style: const TextStyle(color: Colors.white)),
          ],
        ),
        Slider(
          min: min,
          max: max,
          value: value.clamp(min, max),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
