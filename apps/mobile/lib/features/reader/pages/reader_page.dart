import 'dart:async';

import 'package:engine_api/engine_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

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
