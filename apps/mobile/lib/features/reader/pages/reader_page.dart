import 'dart:async';

import 'package:engine_api/engine_api.dart';
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
  StreamSubscription<EngineEvent>? _subscription;
  Book? _book;
  ReadingProgress? _progress;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
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
            '[mobile-reader][${event.type.name}] payload=${event.payload}',
          );
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

        if (event.type == EngineEventType.link) {
          await _handleLinkEvent(event.payload);
        }

        if (event.type == EngineEventType.mediaTap) {
          await _handleMediaTapEvent(event.payload);
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

  Future<void> _handleLinkEvent(Map<String, dynamic>? payload) async {
    if (payload == null) {
      return;
    }

    final handledBy = _asLowerText(payload['handledBy']);
    final action = _asLowerText(payload['action']);
    final externalUri = _resolveExternalUri(payload);

    if (handledBy == 'blocked') {
      debugPrint('[mobile-reader][link.blocked] payload=$payload');
      return;
    }

    if (handledBy == 'renderer') {
      debugPrint('[mobile-reader][link.renderer] payload=$payload');
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
        '[mobile-reader][link.open_external.failed] uri=$externalUri payload=$payload',
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

  @override
  void dispose() {
    _subscription?.cancel();
    _session?.dispose();
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
