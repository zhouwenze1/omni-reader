import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kernel/kernel.dart';

import 'renderer_api_models.dart';

class ReaderBridgeService {
  ReaderBridgeService({
    required InAppWebViewController Function() controllerProvider,
    required void Function(ReaderEvent event) emitEvent,
  }) : _controllerProvider = controllerProvider,
       _emitEvent = emitEvent;

  final InAppWebViewController Function() _controllerProvider;
  final void Function(ReaderEvent event) _emitEvent;

  Future<void> _commandTail = Future<void>.value();

  Future<bool> waitUntilReaderAvailable({
    Duration timeout = const Duration(seconds: 12),
    Duration pollInterval = const Duration(milliseconds: 120),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final controller = _controllerProvider();
      final result = await controller.evaluateJavascript(
        source: '''
          (function() {
            return !!(window.reader
              && typeof window.reader.init === 'function'
              && typeof window.reader.configure === 'function'
              && typeof window.reader.open === 'function'
              && typeof window.reader.navigate === 'function');
          })();
        ''',
      );
      final available = result == true || '$result' == 'true';
      if (available) {
        return true;
      }
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }

  Future<Map<String, dynamic>?> invokeReader(
    String method, [
    Map<String, dynamic>? payload,
  ]) {
    final command = rendererCommandFromWireName(method);
    if (command == null) {
      return Future<Map<String, dynamic>?>.error(
        ArgumentError.value(method, 'method', 'Unsupported renderer command'),
      );
    }
    return _enqueue(() => _invokeCommand(command, payload));
  }

  Future<void> init({required bool debug}) async {
    await _enqueue(
      () => _invokeCommand(RendererCommand.init, <String, dynamic>{
        'debug': debug,
      }),
    );
  }

  Future<void> configure({
    String? layoutMode,
    Map<String, dynamic>? spineManifest,
    Map<String, dynamic>? style,
    String? customCss,
    Object? spineVersion,
    bool? desktopDragPaging,
    String? adjacentResolverHandler,
    Map<String, dynamic>? transitionConfig,
    bool? debug,
  }) async {
    final payload = <String, dynamic>{};
    if (layoutMode != null) {
      payload['layoutMode'] = layoutMode;
    }
    if (spineManifest != null) {
      payload['spineManifest'] = spineManifest;
    }
    if (style != null) {
      payload['style'] = style;
    }
    if (customCss != null) {
      payload['customCss'] = customCss;
    }
    if (spineVersion != null) {
      payload['spineVersion'] = spineVersion;
    }
    if (desktopDragPaging != null) {
      payload['desktopDragPaging'] = desktopDragPaging;
    }
    if (adjacentResolverHandler != null) {
      payload['adjacentResolverHandler'] = adjacentResolverHandler;
    }
    if (transitionConfig != null) {
      payload['transitionConfig'] = transitionConfig;
    }
    if (debug != null) {
      payload['debug'] = debug;
    }
    if (payload.isEmpty) {
      return;
    }
    await _enqueue(() => _invokeCommand(RendererCommand.configure, payload));
  }

  Future<void> open({
    required String url,
    Map<String, dynamic>? locator,
    List<Map<String, dynamic>>? highlights,
  }) async {
    await _enqueue(
      () => _invokeCommand(RendererCommand.open, <String, dynamic>{
        'url': url,
        if (locator != null) 'locator': locator,
        if (highlights != null) 'highlights': highlights,
      }),
    );
  }

  Future<void> navigate(RendererNavigatePayload payload) async {
    await _enqueue(
      () => _invokeCommand(RendererCommand.navigate, payload.toJson()),
    );
  }

  Future<void> clearSelection() async {
    await _enqueue(() => _invokeCommand(RendererCommand.clearSelection));
  }

  Future<void> reset() async {
    await _enqueue(() => _invokeCommand(RendererCommand.reset));
  }

  Future<Map<String, dynamic>?> getSelectionAnchor([
    Map<String, dynamic>? payload,
  ]) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.getSelectionAnchor, payload),
    );
  }

  Future<Map<String, dynamic>?> applyHighlight(Map<String, dynamic> payload) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.applyHighlight, payload),
    );
  }

  Future<Map<String, dynamic>?> applyHighlights(Map<String, dynamic> payload) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.applyHighlights, payload),
    );
  }

  Future<Map<String, dynamic>?> removeHighlight(Map<String, dynamic> payload) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.removeHighlight, payload),
    );
  }

  Future<Map<String, dynamic>?> updateHighlight(Map<String, dynamic> payload) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.updateHighlight, payload),
    );
  }

  Future<Map<String, dynamic>?> _invokeCommand(
    RendererCommand command, [
    Map<String, dynamic>? payload,
  ]) async {
    final controller = _controllerProvider();
    final method = command.wireName;
    final encodedPayload = payload == null ? null : jsonEncode(payload);
    final invocation = encodedPayload == null
        ? 'api[${jsonEncode(method)}]()'
        : 'api[${jsonEncode(method)}]($encodedPayload)';
    final source =
        '''
      (async function() {
        const api = window.reader;
        const method = ${jsonEncode(method)};
        if (!api || typeof api[method] !== 'function') {
          return { ok: false, error: 'missing_method', method };
        }
        try {
          return await $invocation;
        } catch (e) {
          return { ok: false, error: String(e), method };
        }
      })();
    ''';

    final result = await controller.evaluateJavascript(source: source);
    final normalized = _normalizeResult(result);
    _emitEvent(
      ReaderEvent(
        type: ReaderEventType.log,
        payload: <String, dynamic>{
          'phase': 'invokeReader',
          'method': method,
          if (payload != null) 'payload': payload,
          'result': normalized ?? result,
        },
      ),
    );

    if (normalized != null &&
        normalized['ok'] == false &&
        normalized['error'] != null) {
      _emitEvent(
        ReaderEvent(
          type: ReaderEventType.error,
          payload: <String, dynamic>{
            'phase': 'invokeReader',
            'method': method,
            if (payload != null) 'payload': payload,
            'result': normalized,
          },
          message:
              'window.reader.$method failed: ${normalized['error'].toString()}',
        ),
      );
    }

    return normalized;
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final task = _commandTail.then((_) => operation());
    _commandTail = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return task;
  }

  Map<String, dynamic>? _normalizeResult(dynamic result) {
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      return result.map((key, value) => MapEntry('$key', value));
    }
    if (result is String) {
      final text = result.trim();
      if (text.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry('$key', value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
