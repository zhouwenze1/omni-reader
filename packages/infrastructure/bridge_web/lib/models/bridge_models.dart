import 'layout_models.dart';

typedef JsonMap = Map<String, Object?>;

enum RendererEventName { load, ready, error, link, selection, relocated, log }

extension RendererEventNameX on RendererEventName {
  String get value {
    switch (this) {
      case RendererEventName.load:
        return 'load';
      case RendererEventName.ready:
        return 'ready';
      case RendererEventName.error:
        return 'error';
      case RendererEventName.link:
        return 'link';
      case RendererEventName.selection:
        return 'selection';
      case RendererEventName.relocated:
        return 'relocated';
      case RendererEventName.log:
        return 'log';
    }
  }
}

RendererEventName rendererEventNameFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'load':
      return RendererEventName.load;
    case 'ready':
      return RendererEventName.ready;
    case 'error':
      return RendererEventName.error;
    case 'link':
      return RendererEventName.link;
    case 'selection':
      return RendererEventName.selection;
    case 'relocated':
      return RendererEventName.relocated;
    default:
      return RendererEventName.log;
  }
}

class RendererEvent {
  const RendererEvent({required this.name, required this.payload});

  final RendererEventName name;
  final Map<String, Object?> payload;

  JsonMap toJson() {
    return <String, Object?>{'name': name.value, 'payload': payload};
  }

  factory RendererEvent.fromJson(Map<String, Object?> json) {
    return RendererEvent(
      name: rendererEventNameFromValue(json['name']),
      payload: _asMap(json['payload']) ?? const <String, Object?>{},
    );
  }
}

class InitPayloadModel {
  const InitPayloadModel({this.debug = false});

  final bool debug;

  JsonMap toJson() => <String, Object?>{'debug': debug};

  factory InitPayloadModel.fromJson(Map<String, Object?> json) {
    return InitPayloadModel(debug: _asBool(json['debug']) ?? false);
  }
}

class ConfigurePayloadModel {
  const ConfigurePayloadModel({this.mode = LayoutMode.scroll});

  final LayoutMode mode;

  JsonMap toJson() => <String, Object?>{'mode': mode.value};

  factory ConfigurePayloadModel.fromJson(Map<String, Object?> json) {
    return ConfigurePayloadModel(mode: layoutModeFromValue(json['mode']));
  }
}

class StylePayloadModel {
  const StylePayloadModel({required this.style});

  final ReaderStyleModel style;

  JsonMap toJson() => <String, Object?>{'style': style.toJson()};

  factory StylePayloadModel.fromJson(Map<String, Object?> json) {
    return StylePayloadModel(
      style: ReaderStyleModel.fromJson(
        _asMap(json['style']) ?? const <String, Object?>{},
      ),
    );
  }
}

class CustomCssPayloadModel {
  const CustomCssPayloadModel({required this.css});

  final String css;

  JsonMap toJson() => <String, Object?>{'css': css};

  factory CustomCssPayloadModel.fromJson(Map<String, Object?> json) {
    return CustomCssPayloadModel(css: _asString(json['css']) ?? '');
  }
}

class OkResultModel {
  const OkResultModel({this.ok = true});

  final bool ok;

  JsonMap toJson() => <String, Object?>{'ok': ok};

  factory OkResultModel.fromJson(Map<String, Object?> json) {
    return OkResultModel(ok: _asBool(json['ok']) ?? true);
  }
}

class LoadPayloadModel {
  const LoadPayloadModel({
    required this.userAgent,
    required this.platform,
    required this.ts,
  });

  final String userAgent;
  final String platform;
  final int ts;

  JsonMap toJson() {
    return <String, Object?>{
      'userAgent': userAgent,
      'platform': platform,
      'ts': ts,
    };
  }

  factory LoadPayloadModel.fromJson(Map<String, Object?> json) {
    return LoadPayloadModel(
      userAgent: _asString(json['userAgent']) ?? '',
      platform: _asString(json['platform']) ?? '',
      ts: _asInt(json['ts']) ?? 0,
    );
  }
}

class ReadyPayloadModel {
  const ReadyPayloadModel({required this.url, required this.ts});

  final String url;
  final int ts;

  JsonMap toJson() {
    return <String, Object?>{'url': url, 'ts': ts};
  }

  factory ReadyPayloadModel.fromJson(Map<String, Object?> json) {
    return ReadyPayloadModel(
      url: _asString(json['url']) ?? '',
      ts: _asInt(json['ts']) ?? 0,
    );
  }
}

class RelocatedPayloadModel {
  const RelocatedPayloadModel({
    required this.url,
    required this.ts,
    this.mode,
    this.progression,
    this.pageIndex,
    this.pageCount,
    this.atStart,
    this.atEnd,
    this.canGoPrev,
    this.canGoNext,
    this.locator,
  });

  final String url;
  final int ts;
  final LayoutMode? mode;
  final double? progression;
  final int? pageIndex;
  final int? pageCount;
  final bool? atStart;
  final bool? atEnd;
  final bool? canGoPrev;
  final bool? canGoNext;
  final BridgeLocator? locator;

  JsonMap toJson() {
    return <String, Object?>{
      'url': url,
      'mode': mode?.value,
      'progression': progression,
      'pageIndex': pageIndex,
      'pageCount': pageCount,
      'atStart': atStart,
      'atEnd': atEnd,
      'canGoPrev': canGoPrev,
      'canGoNext': canGoNext,
      'locator': locator?.toJson(),
      'ts': ts,
    };
  }

  factory RelocatedPayloadModel.fromJson(Map<String, Object?> json) {
    return RelocatedPayloadModel(
      url: _asString(json['url']) ?? '',
      mode: _asString(json['mode']) == null
          ? null
          : layoutModeFromValue(json['mode']),
      progression: _asDouble(json['progression']),
      pageIndex: _asInt(json['pageIndex']),
      pageCount: _asInt(json['pageCount']),
      atStart: _asBool(json['atStart']),
      atEnd: _asBool(json['atEnd']),
      canGoPrev: _asBool(json['canGoPrev']),
      canGoNext: _asBool(json['canGoNext']),
      locator: _asMap(json['locator']) == null
          ? null
          : BridgeLocator.fromJson(_asMap(json['locator'])!),
      ts: _asInt(json['ts']) ?? 0,
    );
  }
}

class LinkPayloadModel {
  const LinkPayloadModel({required this.href, required this.ts, this.resolved});

  final String href;
  final String? resolved;
  final int ts;

  JsonMap toJson() {
    return <String, Object?>{'href': href, 'resolved': resolved, 'ts': ts};
  }

  factory LinkPayloadModel.fromJson(Map<String, Object?> json) {
    return LinkPayloadModel(
      href: _asString(json['href']) ?? '',
      resolved: _asString(json['resolved']),
      ts: _asInt(json['ts']) ?? 0,
    );
  }
}

class SelectionPayloadModel {
  const SelectionPayloadModel({
    required this.text,
    required this.rect,
    required this.ts,
    this.locator,
  });

  final String text;
  final DomRectModel rect;
  final BridgeLocator? locator;
  final int ts;

  JsonMap toJson() {
    return <String, Object?>{
      'text': text,
      'rect': rect.toJson(),
      'locator': locator?.toJson(),
      'ts': ts,
    };
  }

  factory SelectionPayloadModel.fromJson(Map<String, Object?> json) {
    return SelectionPayloadModel(
      text: _asString(json['text']) ?? '',
      rect: DomRectModel.fromJson(
        _asMap(json['rect']) ?? const <String, Object?>{},
      ),
      locator: _asMap(json['locator']) == null
          ? null
          : BridgeLocator.fromJson(_asMap(json['locator'])!),
      ts: _asInt(json['ts']) ?? 0,
    );
  }
}

class ErrorPayloadModel {
  const ErrorPayloadModel({
    required this.message,
    required this.ts,
    this.stack,
    this.scope,
  });

  final String message;
  final String? stack;
  final String? scope;
  final int ts;

  JsonMap toJson() {
    return <String, Object?>{
      'message': message,
      'stack': stack,
      'scope': scope,
      'ts': ts,
    };
  }

  factory ErrorPayloadModel.fromJson(Map<String, Object?> json) {
    return ErrorPayloadModel(
      message: _asString(json['message']) ?? '',
      stack: _asString(json['stack']),
      scope: _asString(json['scope']),
      ts: _asInt(json['ts']) ?? 0,
    );
  }
}

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return null;
}

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}
