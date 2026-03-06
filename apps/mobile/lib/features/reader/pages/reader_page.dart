import 'dart:async';

import 'package:foundation_application/application.dart';
import 'package:kernel/kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../di/engines_providers.dart';
import '../../../di/repositories_providers.dart';

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
  late final DebouncedAsyncWriter<ReadingProgress> _progressWriteQueue;

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
        if (event.type == ReaderEventType.log ||
            event.type == ReaderEventType.error ||
            event.type == ReaderEventType.ready) {
          debugPrint(
            '[mobile-reader][${event.type.name}] payload=${event.payload}',
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
          _scheduleProgressSave(nextProgress);
          _progress = nextProgress;
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
    switch (decision.action) {
      case ReaderLinkAction.blocked:
        debugPrint('[mobile-reader][link.blocked] payload=$source');
        return;
      case ReaderLinkAction.renderer:
        debugPrint('[mobile-reader][link.renderer] payload=$source');
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
        '[mobile-reader][link.open_external.failed] uri=$externalUri payload=$source',
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

    final progress = ((_progress?.progression ?? 0) * 100).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_book!.title} ($progress%)'),
        actions: [
          IconButton(
            onPressed: () => _session?.navigatePrev(),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: () => _session?.navigateNext(),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: _session!.buildView(),
    );
  }
}
