import 'dart:async';

import 'package:engine_api/engine_api.dart';
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

class _ReaderPageState extends ConsumerState<ReaderPage> {
  ReaderSession? _session;
  StreamSubscription<EngineEvent>? _subscription;
  ProgressRepository? _progressRepository;
  Book? _book;
  ReadingProgress? _progress;
  String? _error;
  bool _loading = true;
  bool _chromeVisible = false;
  Timer? _progressSaveDebounce;
  ReadingProgress? _pendingProgressToSave;
  Future<void> _progressSaveChain = Future<void>.value();

  String _theme = 'day';
  double _fontSize = 20;
  double _lineHeight = 1.6;
  double _pageGap = 24;
  double _paddingLeftRight = 36;
  double _paddingTopBottom = 16;
  bool _textIndentEnabled = true;
  double _textIndentEm = 2;
  bool _textIndentSkipFirst = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _bootstrapReaderStyleFromSettings(ref.read(settingsControllerProvider));

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
      );

      _subscription = session.events.listen((event) async {
        if (event.type == EngineEventType.log ||
            event.type == EngineEventType.error ||
            event.type == EngineEventType.ready) {
          debugPrint(
            '[desktop-reader][${event.type.name}] payload=${event.payload}',
          );
        }

        if (event.type == EngineEventType.tapIntent) {
          _handleTapIntent(event.payload);
        }

        if (event.type == EngineEventType.link) {
          await _handleLinkEvent(event.payload);
        }

        if (event.type == EngineEventType.mediaTap) {
          await _handleMediaTapEvent(event.payload);
        }

        if (event.type == EngineEventType.relocated && event.locator != null) {
          final payloadProgress =
              (event.payload?['progression'] as num?)?.toDouble();
          final locatorProgress =
              (event.locator!.locations?['progression'] as num?)?.toDouble();
          final progression = payloadProgress ?? locatorProgress ?? 0;

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

  void _bootstrapReaderStyleFromSettings(SettingsState settingsState) {
    final reader = settingsState.reader;
    _theme = reader.theme;
    _fontSize = reader.fontSize;
    _lineHeight = reader.lineHeight;
    _pageGap = reader.pageGap;
    _paddingLeftRight = reader.paddingHorizontal;
    _paddingTopBottom = reader.paddingVertical;
    _textIndentEnabled = reader.textIndentEnabled;
    _textIndentEm = reader.textIndentEm;
    _textIndentSkipFirst = reader.textIndentSkipFirstParagraph;
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
    _progressSaveDebounce?.cancel();
    _flushPendingProgressSave();
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
    _pendingProgressToSave = progress;
    _progressSaveDebounce?.cancel();
    _progressSaveDebounce = Timer(
      const Duration(milliseconds: 280),
      _flushPendingProgressSave,
    );
  }

  void _flushPendingProgressSave() {
    final repository = _progressRepository;
    final pending = _pendingProgressToSave;
    if (repository == null || pending == null) {
      return;
    }

    _pendingProgressToSave = null;
    _progressSaveChain = _progressSaveChain.then((_) async {
      try {
        await repository.saveProgress(pending);
      } catch (error) {
        debugPrint('[desktop-reader][saveProgress.error] $error');
      }
    });
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

  void _handleTapIntent(Map<String, dynamic>? payload) {
    if (payload == null) {
      return;
    }
    final zone = '${payload['zone'] ?? ''}'.toLowerCase();
    final mode = '${payload['mode'] ?? ''}'.toLowerCase();
    if (zone == 'center' && mode == 'reading' && mounted) {
      setState(() {
        _chromeVisible = !_chromeVisible;
      });
    }
  }

  Future<void> _handleLinkEvent(Map<String, dynamic>? payload) async {
    if (payload == null) {
      return;
    }

    final handledBy = _asLowerText(payload['handledBy']);
    final action = _asLowerText(payload['action']);
    final externalUri = _resolveExternalUri(payload);

    if (handledBy == 'blocked') {
      debugPrint('[desktop-reader][link.blocked] payload=$payload');
      return;
    }

    if (handledBy == 'renderer') {
      debugPrint('[desktop-reader][link.renderer] payload=$payload');
      return;
    }

    if (action != 'open_external' || externalUri == null) {
      return;
    }

    final launched = await launchUrl(
      externalUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint(
        '[desktop-reader][link.open_external.failed] uri=$externalUri payload=$payload',
      );
    }
  }

  Future<void> _handleMediaTapEvent(Map<String, dynamic>? payload) async {
    if (payload == null || !mounted) {
      return;
    }

    final src = _resolveMediaSrc(payload);
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

  Uri? _resolveExternalUri(Map<String, dynamic> payload) {
    final resolved = _resolveUrlCandidate(payload, 'resolved');
    if (resolved != null && resolved.hasScheme) {
      return resolved;
    }
    final href = _resolveUrlCandidate(payload, 'href');
    if (href != null && href.hasScheme) {
      return href;
    }
    return null;
  }

  String? _resolveMediaSrc(Map<String, dynamic> payload) {
    final resolved = _resolveUrlCandidate(payload, 'resolvedSrc');
    if (resolved != null) {
      return resolved.toString();
    }
    final src = _resolveUrlCandidate(payload, 'src');
    return src?.toString();
  }

  Uri? _resolveUrlCandidate(Map<String, dynamic> payload, String key) {
    final rawValue = _asText(payload[key]);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final direct = Uri.tryParse(rawValue);
    if (direct != null && direct.hasScheme) {
      return direct;
    }

    final fromUrl = _asText(payload['fromUrl']);
    final base = fromUrl == null ? null : Uri.tryParse(fromUrl);
    if (base != null) {
      return base.resolve(rawValue);
    }
    return direct;
  }

  String? _asText(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  String _asLowerText(Object? value) {
    return _asText(value)?.toLowerCase() ?? '';
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
                    tooltip:
                        _theme == 'day' ? l10n.switchToNight : l10n.switchToDay,
                    onPressed: _toggleTheme,
                    icon: Icon(
                      _theme == 'day' ? Icons.dark_mode : Icons.light_mode,
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

  void _toggleTheme() {
    final next = _theme == 'day' ? 'night' : 'day';
    setState(() {
      _theme = next;
    });
    unawaited(_applyReaderStyle());
  }

  Map<String, dynamic> _currentReaderStyle() {
    return <String, dynamic>{
      'theme': _theme,
      'columnCount': 1,
      'pageGap': _pageGap.round(),
      'fontSize': _fontSize.round(),
      'lineHeight': _lineHeight,
      'paddingTop': _paddingTopBottom.round(),
      'paddingRight': _paddingLeftRight.round(),
      'paddingBottom': _paddingTopBottom.round(),
      'paddingLeft': _paddingLeftRight.round(),
      'textIndentEnabled': _textIndentEnabled,
      'textIndentEm': _textIndentEm,
      'textIndentSkipFirstParagraph': _textIndentSkipFirst,
    };
  }

  Future<void> _applyReaderStyle() async {
    final session = _session;
    if (session == null) {
      return;
    }
    try {
      await session.setStyle(_currentReaderStyle());
      final readerSettings = ReaderSettings(
        fontFamily: 'system',
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        pageGap: _pageGap,
        paddingHorizontal: _paddingLeftRight,
        paddingVertical: _paddingTopBottom,
        textIndentEnabled: _textIndentEnabled,
        textIndentEm: _textIndentEm,
        textIndentSkipFirstParagraph: _textIndentSkipFirst,
        theme: _theme,
        layoutMode: 'paged_spread',
        progressDisplay: 'percentage',
      );
      unawaited(
        ref
            .read(settingsControllerProvider.notifier)
            .updateReader(readerSettings),
      );
    } catch (error) {
      debugPrint('[desktop-reader][setStyle.error] $error');
    }
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
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(color: Colors.white),
            ),
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
