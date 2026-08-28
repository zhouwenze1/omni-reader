import 'package:kernel/kernel.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:foundation_domain/domain.dart';

import 'book_uri_mapper.dart';
import 'locator_normalizer.dart';
import 'renderer_locator_mapper.dart';

class ReaderSelection {
  const ReaderSelection({this.href, this.cfi, this.text, this.anchor});

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
    required LocatorNormalizer locatorNormalizer,
    required BookUriMapper uriMapper,
    required void Function(ReaderEvent event) emitEvent,
  })  : _controller = controller,
        _bookUuid = bookUuid,
        _locatorNormalizer = locatorNormalizer,
        _uriMapper = uriMapper,
        _emitEvent = emitEvent;

  static const List<String> eventNames = <String>[
    'load',
    'ready',
    'error',
    'link',
    'mediaTap',
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
  final LocatorNormalizer _locatorNormalizer;
  final RendererLocatorMapper _rendererLocatorMapper =
      const RendererLocatorMapper();
  final BookUriMapper _uriMapper;
  final void Function(ReaderEvent event) _emitEvent;

  void registerAll() {
    for (final name in eventNames) {
      _controller.addJavaScriptHandler(
        handlerName: name,
        callback: (args) {
          final payload = _extractPayload(args);
          final normalized = _normalizeEventPayload(name, payload);
          final locator = _extractLocator(normalized);

          _emitEvent(
            ReaderEvent.fromRaw(
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

  Map<String, dynamic> _normalizeEventPayload(
    String name,
    Map<String, dynamic> payload,
  ) {
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
          next['locator'] = _rendererLocatorMapper.toPayload(
            Locator.fromJson(normalizedLocator),
            uriMapper: _uriMapper,
            bookUuid: _bookUuid,
          );
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
        next['selectionModel'] = ReaderSelection.fromPayload(
          normalizedSelection,
        ).toJson();
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

  ReaderEventType _mapEventType(String name) {
    switch (name) {
      case 'load':
        return ReaderEventType.load;
      case 'ready':
        return ReaderEventType.ready;
      case 'error':
        return ReaderEventType.error;
      case 'link':
        return ReaderEventType.link;
      case 'mediaTap':
        return ReaderEventType.mediaTap;
      case 'selection':
        return ReaderEventType.selection;
      case 'tapIntent':
        return ReaderEventType.tapIntent;
      case 'relocated':
        return ReaderEventType.relocated;
      case 'boundary':
        return ReaderEventType.boundary;
      case 'highlightCreateRequest':
        return ReaderEventType.highlightCreateRequest;
      case 'highlightTapped':
        return ReaderEventType.highlightTapped;
      case 'highlightApplyReport':
        return ReaderEventType.highlightApplyReport;
      case 'log':
        return ReaderEventType.log;
      default:
        return ReaderEventType.log;
    }
  }
}
