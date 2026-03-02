import 'package:engine_api/engine_api.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:foundation_domain/domain.dart';

import 'book_storage_service.dart';
import 'book_uri_mapper.dart';
import 'locator_normalizer.dart';

class ReaderSelection {
  const ReaderSelection({
    this.href,
    this.cfi,
    this.text,
    this.anchor,
  });

  final String? href;
  final String? cfi;
  final String? text;
  final Map<String, dynamic>? anchor;

  factory ReaderSelection.fromPayload(Map<String, dynamic> payload) {
    final href = payload['href'] as String?;
    final cfi = payload['cfi'] as String?;
    final text = payload['text'] as String?;
    final anchor = payload['anchor'] is Map
        ? (payload['anchor'] as Map).map((k, v) => MapEntry('$k', v))
        : null;
    return ReaderSelection(href: href, cfi: cfi, text: text, anchor: anchor);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (href != null && href!.isNotEmpty) 'href': href,
      if (cfi != null && cfi!.isNotEmpty) 'cfi': cfi,
      if (text != null && text!.isNotEmpty) 'text': text,
      if (anchor != null && anchor!.isNotEmpty) 'anchor': anchor,
    };
  }
}

class ReaderEventReceiver {
  ReaderEventReceiver({
    required InAppWebViewController controller,
    required String bookUuid,
    required BookStorageService storageService,
    required LocatorNormalizer locatorNormalizer,
    required BookUriMapper uriMapper,
    required void Function(EngineEvent event) emitEvent,
  })  : _controller = controller,
        _bookUuid = bookUuid,
        _storageService = storageService,
        _locatorNormalizer = locatorNormalizer,
        _uriMapper = uriMapper,
        _emitEvent = emitEvent;

  static const List<String> eventNames = <String>[
    'load',
    'ready',
    'error',
    'link',
    'selection',
    'tapIntent',
    'relocated',
    'boundary',
    'highlightCreateRequest',
    'highlightTapped',
    'highlightApplyReport',
    'log',
  ];

  final InAppWebViewController _controller;
  final String _bookUuid;
  final BookStorageService _storageService;
  final LocatorNormalizer _locatorNormalizer;
  final BookUriMapper _uriMapper;
  final void Function(EngineEvent event) _emitEvent;

  void registerAll() {
    for (final name in eventNames) {
      _controller.addJavaScriptHandler(
        handlerName: name,
        callback: (args) async {
          final payload = _extractPayload(args);
          final normalized = await _normalizeEventPayload(name, payload);
          final locator = _extractLocator(normalized);

          _emitEvent(
            EngineEvent(
              type: _mapEventType(name),
              payload: normalized,
              locator: locator,
              message: normalized['message'] as String?,
            ),
          );
          return <String, dynamic>{'ok': true};
        },
      );
    }
  }

  Future<Map<String, dynamic>> _normalizeEventPayload(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final next = Map<String, dynamic>.from(payload);
    if (name == 'relocated') {
      final rawLocator = _extractLocatorJson(payload);
      if (rawLocator != null) {
        final normalizedLocator = _locatorNormalizer.normalizeMap(
          rawLocator,
          uriMapper: _uriMapper,
          bookUuid: _bookUuid,
        );
        if (normalizedLocator.isNotEmpty) {
          next['locator'] = normalizedLocator;
          await _storageService.saveLastLocator(_bookUuid, normalizedLocator);
        }
      }
    }

    if (name == 'selection') {
      final rawSelection = _extractSelectionPayload(payload);
      final normalizedSelection = _locatorNormalizer.normalizeMap(
        rawSelection,
        uriMapper: _uriMapper,
        bookUuid: _bookUuid,
      );
      if (normalizedSelection.isNotEmpty) {
        next['selectionModel'] =
            ReaderSelection.fromPayload(normalizedSelection).toJson();
      }
    }
    return next;
  }

  Map<String, dynamic>? _extractLocatorJson(Map<String, dynamic> payload) {
    final locator = payload['locator'];
    if (locator is Map<String, dynamic>) {
      return locator;
    }
    if (locator is Map) {
      return locator.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  Map<String, dynamic> _extractSelectionPayload(Map<String, dynamic> payload) {
    final selection = payload['selection'];
    if (selection is Map<String, dynamic>) {
      return selection;
    }
    if (selection is Map) {
      return selection.map((key, value) => MapEntry('$key', value));
    }
    return payload;
  }

  Locator? _extractLocator(Map<String, dynamic> payload) {
    final locatorMap = _extractLocatorJson(payload);
    if (locatorMap == null || locatorMap.isEmpty) {
      return null;
    }
    return _locatorNormalizer.fromAny(
      locatorMap,
      uriMapper: _uriMapper,
      bookUuid: _bookUuid,
    );
  }

  Map<String, dynamic> _extractPayload(List<dynamic> args) {
    if (args.isEmpty) {
      return <String, dynamic>{};
    }
    final raw = args.first;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value));
    }
    return <String, dynamic>{'value': raw};
  }

  EngineEventType _mapEventType(String name) {
    switch (name) {
      case 'load':
        return EngineEventType.load;
      case 'ready':
        return EngineEventType.ready;
      case 'error':
        return EngineEventType.error;
      case 'link':
        return EngineEventType.link;
      case 'selection':
        return EngineEventType.selection;
      case 'tapIntent':
        return EngineEventType.tapIntent;
      case 'relocated':
        return EngineEventType.relocated;
      case 'boundary':
        return EngineEventType.boundary;
      case 'highlightCreateRequest':
        return EngineEventType.highlightCreateRequest;
      case 'highlightTapped':
        return EngineEventType.highlightTapped;
      case 'highlightApplyReport':
        return EngineEventType.highlightApplyReport;
      case 'log':
        return EngineEventType.log;
      default:
        return EngineEventType.log;
    }
  }
}
