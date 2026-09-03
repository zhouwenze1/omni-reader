import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kernel/kernel.dart';

import 'renderer_api_models.dart';

class ReaderBridgeService {
  ReaderBridgeService({
    required InAppWebViewController Function() controllerProvider,
    required void Function(ReaderEvent event) emitEvent,
  })  : _controllerProvider = controllerProvider,
        _emitEvent = emitEvent;

  final InAppWebViewController Function() _controllerProvider;
  final void Function(ReaderEvent event) _emitEvent;

  Future<void> _commandTail = Future<void>.value();
  bool _debug = false;

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
    return _enqueue(
      () => _invokeCommand(command, payload),
      label: command.wireName,
    );
  }

  Future<void> init({required bool debug}) async {
    _debug = debug;
    await _enqueue(
      () => _invokeCommand(RendererCommand.init, <String, dynamic>{
        'debug': debug,
      }),
      label: RendererCommand.init.wireName,
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
    if (debug != null) _debug = debug;
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
    await _enqueue(
      () => _invokeCommand(RendererCommand.configure, payload),
      label: RendererCommand.configure.wireName,
    );
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
      label: RendererCommand.open.wireName,
    );
  }

  Future<void> navigate(RendererNavigatePayload payload) async {
    await _enqueue(
      () => _invokeCommand(RendererCommand.navigate, payload.toJson()),
      label: RendererCommand.navigate.wireName,
    );
  }

  Future<void> clearSelection() async {
    await _enqueue(
      () => _invokeCommand(RendererCommand.clearSelection),
      label: RendererCommand.clearSelection.wireName,
    );
  }

  Future<void> reset() async {
    await _enqueue(
      () => _invokeCommand(RendererCommand.reset),
      label: RendererCommand.reset.wireName,
    );
  }

  Future<Map<String, dynamic>?> getSelectionAnchor([
    Map<String, dynamic>? payload,
  ]) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.getSelectionAnchor, payload),
      label: RendererCommand.getSelectionAnchor.wireName,
    );
  }

  Future<Map<String, dynamic>?> applyHighlight(Map<String, dynamic> payload) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.applyHighlight, payload),
      label: RendererCommand.applyHighlight.wireName,
    );
  }

  Future<Map<String, dynamic>?> applyHighlights(Map<String, dynamic> payload) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.applyHighlights, payload),
      label: RendererCommand.applyHighlights.wireName,
    );
  }

  Future<Map<String, dynamic>?> removeHighlight(Map<String, dynamic> payload) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.removeHighlight, payload),
      label: RendererCommand.removeHighlight.wireName,
    );
  }

  Future<Map<String, dynamic>?> updateHighlight(Map<String, dynamic> payload) {
    return _enqueue(
      () => _invokeCommand(RendererCommand.updateHighlight, payload),
      label: RendererCommand.updateHighlight.wireName,
    );
  }

  Future<Map<String, dynamic>?> _invokeCommand(
    RendererCommand command, [
    Map<String, dynamic>? payload,
  ]) async {
    final controller = _controllerProvider();
    final method = command.wireName;
    final jsStopwatch = Stopwatch()..start();
    final asyncResult = await controller.callAsyncJavaScript(
      functionBody: '''
        const api = window.reader;
        if (!api || typeof api[methodName] !== 'function') {
          return JSON.stringify({
            ok: false,
            error: 'missing_method',
            method: methodName,
          });
        }
        try {
          const value = hasPayload
              ? await api[methodName](payload)
              : await api[methodName]();
          // Serialize explicitly so result-bearing commands keep their fields
          // on every WebView platform, including WebView2.
          return JSON.stringify(value ?? null);
        } catch (e) {
          return JSON.stringify({
            ok: false,
            error: String(e),
            method: methodName,
          });
        }
      ''',
      arguments: <String, dynamic>{
        'methodName': method,
        'hasPayload': payload != null,
        'payload': payload,
      },
    );
    jsStopwatch.stop();

    final result = asyncResult?.error == null
        ? asyncResult?.value
        : jsonEncode(<String, dynamic>{
            'ok': false,
            'error': asyncResult?.error,
            'method': method,
          });
    final normalized = _normalizeResult(result);
    if (_debug) {
      _emitEvent(
        ReaderEvent(
          type: ReaderEventType.log,
          payload: <String, dynamic>{
            'phase': 'invokeReader',
            'method': method,
            'jsExecutionMs': jsStopwatch.elapsedMicroseconds / 1000,
            if (payload != null) 'payload': payload,
            'result': normalized ?? result,
          },
        ),
      );
    }

    if (normalized != null &&
        normalized['ok'] == false &&
        normalized['error'] != null) {
      _emitEvent(
        ReaderEvent(
          type: ReaderEventType.error,
          payload: <String, dynamic>{
            'phase': 'invokeReader',
            'method': method,
            'result': normalized,
            if (_debug && payload != null) 'payload': payload,
          },
          message:
              'window.reader.$method failed: ${normalized['error'].toString()}',
        ),
      );
    }

    return normalized;
  }

  Future<T> _enqueue<T>(
    Future<T> Function() operation, {
    String? label,
  }) {
    final queuedAt = Stopwatch()..start();
    final task = _commandTail.then((_) {
      final queueWaitMs = queuedAt.elapsedMicroseconds / 1000;
      final startedAt = Stopwatch()..start();
      return operation().whenComplete(() {
        startedAt.stop();
        if (!_debug) return;
        _emitEvent(
          ReaderEvent(
            type: ReaderEventType.log,
            payload: <String, dynamic>{
              'phase': 'bridgeTiming',
              'method': label,
              'queueWaitMs': queueWaitMs,
              'totalMs': queueWaitMs + startedAt.elapsedMicroseconds / 1000,
            },
          ),
        );
      });
    });
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
