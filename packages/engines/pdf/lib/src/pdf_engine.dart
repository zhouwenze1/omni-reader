import 'dart:async';

import 'package:kernel/kernel.dart';
import 'package:flutter/material.dart';
import 'package:foundation_domain/domain.dart';

class PdfReaderEngine extends ReaderEngine {
  static const Set<String> _formats = <String>{'pdf'};

  static const Set<ReaderCapability> _capabilities = <ReaderCapability>{
    ReaderCapability.linearNavigation,
    ReaderCapability.jumpNavigation,
    ReaderCapability.style,
    ReaderCapability.theme,
  };

  @override
  String get id => 'pdf';

  @override
  String get displayName => 'PDF';

  @override
  Set<String> get supportedFormats => _formats;

  @override
  Set<ReaderCapability> get capabilities => _capabilities;

  @override
  Future<ReaderSession> createSession({
    required Book book,
    ReadingProgress? initialProgress,
    ReaderStyle initialStyle = ReaderStyle.defaults,
  }) async {
    return _PdfStubSession(
      book: book,
      initialProgress: initialProgress,
      initialStyle: initialStyle,
    );
  }
}

class _PdfStubSession extends ReaderSession {
  _PdfStubSession({
    required Book book,
    this.initialProgress,
    required ReaderStyle initialStyle,
  })  : _book = book,
        _style = initialStyle {
    _progress = initialProgress?.progression ?? 0;
  }

  final Book _book;
  final ReadingProgress? initialProgress;
  final StreamController<ReaderEvent> _events =
      StreamController<ReaderEvent>.broadcast();
  ReaderStyle _style;

  double _progress = 0;

  @override
  Stream<ReaderEvent> get events => _events.stream;

  @override
  Set<ReaderCapability> get capabilities => PdfReaderEngine._capabilities;

  @override
  ReaderStyle get style => _style;

  @override
  Widget buildView() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('PDF Stub Engine: ${_book.title}'),
              const SizedBox(height: 8),
              Text('Progress: ${(_progress * 100).toStringAsFixed(1)}%'),
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
      ReaderEvent(
        type: ReaderEventType.ready,
        payload: {'format': 'pdf', 'bookUid': _book.uid},
      ),
    );
    _emitRelocated();
  }

  @override
  Future<void> setStyle(ReaderStyle style) async {
    _style = style;
  }

  @override
  Future<void> applyTheme(String theme) async {
    _style = _style.copyWith(theme: theme);
  }

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
      ReaderEvent(
        type: ReaderEventType.relocated,
        locator: locator ?? Locator(locations: {'progression': _progress}),
        payload: {'progression': _progress, 'format': 'pdf'},
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}
