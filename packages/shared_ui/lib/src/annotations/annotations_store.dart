import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:foundation_domain/domain.dart';
import 'package:kernel/kernel.dart';

class AnnotationsStore extends ChangeNotifier {
  AnnotationsStore({
    required AnnotationRepository repository,
    required String bookUid,
  })  : _repository = repository,
        _bookUid = bookUid;

  final AnnotationRepository _repository;
  final String _bookUid;
  final List<Annotation> _items = <Annotation>[];
  Future<void> _writeTail = Future<void>.value();
  bool _loaded = false;
  int _idCounter = 0;

  List<Annotation> get items => List<Annotation>.unmodifiable(_items);

  bool get isLoaded => _loaded;

  Future<void> load() async {
    await _writeTail;
    final loaded = await _repository.listAnnotations(_bookUid);
    _items
      ..clear()
      ..addAll(loaded);
    _loaded = true;
    notifyListeners();
  }

  Future<Annotation> createHighlight({
    required ReaderSelectionQuote selection,
    required String color,
    String? note,
    String? id,
  }) async {
    await _ensureLoaded();
    final now = DateTime.now();
    final annotation = Annotation(
      id: id ?? _newId(now),
      bookUid: _bookUid,
      type: AnnotationType.highlight,
      locator: Locator(
        href: selection.href,
        cfi: selection.cfi,
        anchor: <String, dynamic>{'text': selection.quote.toJson()},
      ),
      text: selection.quote.exact,
      note: _cleanNote(note),
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    await _replace(<Annotation>[..._items, annotation]);
    return annotation;
  }

  String newHighlightId() => _newId(DateTime.now());

  Future<void> changeColor(String id, String color) async {
    await _ensureLoaded();
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].color == color) {
      return;
    }
    final next = List<Annotation>.from(_items);
    next[index] = _copyWith(next[index], color: color);
    await _replace(next);
  }

  Future<void> setNote(String id, String? note) async {
    await _ensureLoaded();
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    final cleaned = _cleanNote(note);
    if (nextNoteEquals(_items[index].note, cleaned)) {
      return;
    }
    final next = List<Annotation>.from(_items);
    next[index] = _copyWith(next[index], note: cleaned, clearNote: true);
    await _replace(next);
  }

  Future<void> remove(String id) async {
    await _ensureLoaded();
    final next = _items.where((item) => item.id != id).toList();
    if (next.length == _items.length) {
      return;
    }
    await _replace(next);
  }

  Annotation? find(String id) {
    for (final item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  List<ReaderHighlight> get readerHighlights {
    return _items
        .where((item) => item.type == AnnotationType.highlight)
        .map(annotationToReaderHighlight)
        .whereType<ReaderHighlight>()
        .toList(growable: false);
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) {
      await load();
    }
  }

  Future<void> _replace(List<Annotation> next) async {
    final operation = _writeTail.then((_) async {
      await _repository.replaceAnnotations(_bookUid, next);
      _items
        ..clear()
        ..addAll(next);
      notifyListeners();
    });
    _writeTail = operation.catchError((Object _) {});
    await operation;
  }

  String _newId(DateTime now) {
    _idCounter += 1;
    return 'hl-${now.microsecondsSinceEpoch}-$_idCounter';
  }

  static String? _cleanNote(String? note) {
    final value = note?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static bool nextNoteEquals(String? left, String? right) => left == right;

  static Annotation _copyWith(
    Annotation source, {
    String? color,
    String? note,
    bool clearNote = false,
  }) {
    return Annotation(
      id: source.id,
      bookUid: source.bookUid,
      type: source.type,
      locator: source.locator,
      text: source.text,
      note: clearNote ? note : note ?? source.note,
      color: color ?? source.color,
      createdAt: source.createdAt,
      updatedAt: DateTime.now(),
      extras: source.extras,
    );
  }
}

ReaderHighlight? annotationToReaderHighlight(Annotation annotation) {
  final anchor = annotation.locator.anchor;
  final quote = ReaderTextQuote.fromJson(anchor?['text']);
  final href = annotation.locator.href;
  if (href == null || href.trim().isEmpty || !quote.isUsable) {
    return null;
  }
  return ReaderHighlight(
    uid: annotation.id,
    href: href,
    color: annotation.color ?? '#FFF59D',
    quote: quote,
    cfi: annotation.locator.cfi,
  );
}
