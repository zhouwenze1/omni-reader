import 'dart:convert';

import 'package:kernel/kernel.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ReaderBridgeService {
  ReaderBridgeService({
    required InAppWebViewController Function() controllerProvider,
    required void Function(ReaderEvent event) emitEvent,
  })  : _controllerProvider = controllerProvider,
        _emitEvent = emitEvent;

  final InAppWebViewController Function() _controllerProvider;
  final void Function(ReaderEvent event) _emitEvent;

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
  ]) async {
    final controller = _controllerProvider();
    final source = payload == null
        ? '''
          (async function() {
            if (!window.reader || !window.reader.$method) {
              return { ok: false, error: 'missing_method' };
            }
            try {
              return await window.reader.$method();
            } catch (e) {
              return { ok: false, error: String(e) };
            }
          })();
        '''
        : '''
          (async function() {
            if (!window.reader || !window.reader.$method) {
              return { ok: false, error: 'missing_method' };
            }
            try {
              return await window.reader.$method(${jsonEncode(payload)});
            } catch (e) {
              return { ok: false, error: String(e) };
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

  Future<void> init({required bool debug}) async {
    await invokeReader('init', <String, dynamic>{'debug': debug});
  }

  Future<void> configure({
    String? layoutMode,
    Map<String, dynamic>? spineManifest,
    Map<String, dynamic>? style,
    String? customCss,
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
    if (payload.isEmpty) {
      return;
    }
    await invokeReader(
      'configure',
      payload,
    );
  }

  Future<void> setLayoutMode(String layoutMode) async {
    await configure(layoutMode: layoutMode);
  }

  Future<void> open({
    required String url,
    required Map<String, dynamic> locator,
  }) async {
    await invokeReader(
      'open',
      <String, dynamic>{'url': url, 'locator': locator},
    );
  }

  Future<void> navigate(Map<String, dynamic> payload) async {
    await invokeReader('navigate', payload);
  }

  Future<void> setStyle(Map<String, dynamic> style) async {
    await invokeReader('setStyle', <String, dynamic>{'style': style});
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
