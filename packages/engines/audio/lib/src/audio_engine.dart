import 'dart:async';

import 'package:engine_api/engine_api.dart';
import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

class AudioReaderEngine implements ReaderEngine {
  @override
  String get id => 'audio';

  @override
  bool supportsFormat(String format) {
    final lower = format.toLowerCase();
    return lower == 'audio' || lower == 'w3caudiobook';
  }

  @override
  Future<ReaderSession> createSession({
    required Book book,
    ReadingProgress? initialProgress,
  }) async {
    return _AudioStubSession(book: book, initialProgress: initialProgress);
  }
}

class _AudioStubSession implements ReaderSession {
  _AudioStubSession({required Book book, this.initialProgress}) : _book = book {
    _progress = initialProgress?.progression ?? 0;
  }

  final Book _book;
  final ReadingProgress? initialProgress;
  final StreamController<EngineEvent> _events =
      StreamController<EngineEvent>.broadcast();

  double _progress = 0;

  @override
  Stream<EngineEvent> get events => _events.stream;

  @override
  Widget buildView() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Audio Stub Engine: ${_book.title}'),
              const SizedBox(height: 8),
              Text('Position: ${(_progress * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: () async {
                      await navigatePrev();
                      setState(() {});
                    },
                    child: const Text('Prev'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await navigateNext();
                      setState(() {});
                    },
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Future<void> open() async {
    _events.add(
      EngineEvent(
        type: EngineEventType.ready,
        payload: {'format': 'audio', 'bookUid': _book.uid},
      ),
    );
    _emitRelocated();
  }

  @override
  Future<void> setStyle(Map<String, dynamic> style) async {}

  @override
  Future<void> applyTheme(String theme) async {}

  @override
  Future<void> navigateNext() async {
    _progress = (_progress + 0.1).clamp(0, 1);
    _emitRelocated();
  }

  @override
  Future<void> navigatePrev() async {
    _progress = (_progress - 0.1).clamp(0, 1);
    _emitRelocated();
  }

  @override
  Future<void> goTo(Locator locator) async {
    final progression = locator.locations?['progression'];
    if (progression is num) {
      _progress = progression.toDouble().clamp(0, 1);
    }
    _emitRelocated(locator: locator);
  }

  void _emitRelocated({Locator? locator}) {
    _events.add(
      EngineEvent(
        type: EngineEventType.relocated,
        locator: locator ?? Locator(locations: {'progression': _progress}),
        payload: {'progression': _progress, 'format': 'audio'},
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}
