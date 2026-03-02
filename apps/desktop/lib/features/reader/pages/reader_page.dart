import 'dart:async';

import 'package:engine_api/engine_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/engines_providers.dart';
import '../../../di/repositories_providers.dart';
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
  Book? _book;
  ReadingProgress? _progress;
  String? _error;
  bool _loading = true;
  bool _chromeVisible = false;

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
          await progressRepository.saveProgress(nextProgress);
          _progress = nextProgress;
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

  Widget _buildTopToolbar(BuildContext context) {
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
                    tooltip: 'Back',
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
                    tooltip: 'Reader settings',
                    onPressed: _openReaderSettings,
                    icon: const Icon(Icons.tune, color: Colors.white),
                  ),
                  IconButton(
                    tooltip:
                        _theme == 'day' ? 'Switch to night' : 'Switch to day',
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
                    tooltip: 'Previous',
                    onPressed: () => _session?.navigatePrev(),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'Progress: $progressPercent%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next',
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
                      const Text(
                        '阅读设置',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSliderControl(
                        label: '字体大小',
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
                        label: '行高',
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
                        label: '页间距',
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
                        label: '左右边距',
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
                        label: '上下边距',
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
                        title: const Text(
                          '启用首行缩进',
                          style: TextStyle(color: Colors.white),
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
                        label: '缩进 (em)',
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
                        title: const Text(
                          '首段不缩进',
                          style: TextStyle(color: Colors.white),
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
                          child: const Text('关闭'),
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
