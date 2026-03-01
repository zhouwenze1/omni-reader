typedef JsonMap = Map<String, Object?>;

enum LayoutMode { scroll, paged }

extension LayoutModeX on LayoutMode {
  String get value {
    switch (this) {
      case LayoutMode.scroll:
        return 'scroll';
      case LayoutMode.paged:
        return 'paged';
    }
  }
}

LayoutMode layoutModeFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'paged':
      return LayoutMode.paged;
    default:
      return LayoutMode.scroll;
  }
}

enum NavigateKind { next, prev, progression, anchor }

extension NavigateKindX on NavigateKind {
  String get value {
    switch (this) {
      case NavigateKind.next:
        return 'next';
      case NavigateKind.prev:
        return 'prev';
      case NavigateKind.progression:
        return 'progression';
      case NavigateKind.anchor:
        return 'anchor';
    }
  }
}

NavigateKind navigateKindFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'prev':
      return NavigateKind.prev;
    case 'progression':
      return NavigateKind.progression;
    case 'anchor':
      return NavigateKind.anchor;
    default:
      return NavigateKind.next;
  }
}

class DomRectModel {
  const DomRectModel({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  JsonMap toJson() {
    return <String, Object?>{
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }

  factory DomRectModel.fromJson(Map<String, Object?> json) {
    return DomRectModel(
      left: _asDouble(json['left']) ?? 0,
      top: _asDouble(json['top']) ?? 0,
      width: _asDouble(json['width']) ?? 0,
      height: _asDouble(json['height']) ?? 0,
    );
  }
}

class BridgeLocatorLocations {
  const BridgeLocatorLocations({
    this.position,
    this.progression,
    this.totalProgression,
  });

  final int? position;
  final double? progression;
  final double? totalProgression;

  JsonMap toJson() {
    return <String, Object?>{
      'position': position,
      'progression': progression,
      'totalProgression': totalProgression,
    };
  }

  factory BridgeLocatorLocations.fromJson(Map<String, Object?> json) {
    return BridgeLocatorLocations(
      position: _asInt(json['position']),
      progression: _asDouble(json['progression']),
      totalProgression: _asDouble(json['totalProgression']),
    );
  }
}

class BridgeLocatorAnchor {
  const BridgeLocatorAnchor({
    this.uid,
    this.uidNext,
    this.xpath,
    this.offset,
    this.rect,
  });

  final String? uid;
  final String? uidNext;
  final String? xpath;
  final int? offset;
  final DomRectModel? rect;

  JsonMap toJson() {
    return <String, Object?>{
      'uid': uid,
      'uidNext': uidNext,
      'xpath': xpath,
      'offset': offset,
      'rect': rect?.toJson(),
    };
  }

  factory BridgeLocatorAnchor.fromJson(Map<String, Object?> json) {
    return BridgeLocatorAnchor(
      uid: _asString(json['uid']),
      uidNext: _asString(json['uidNext']),
      xpath: _asString(json['xpath']),
      offset: _asInt(json['offset']),
      rect: _asMap(json['rect']) == null
          ? null
          : DomRectModel.fromJson(_asMap(json['rect'])!),
    );
  }
}

class BridgeLocatorText {
  const BridgeLocatorText({this.before, this.highlight, this.after});

  final String? before;
  final String? highlight;
  final String? after;

  JsonMap toJson() {
    return <String, Object?>{
      'before': before,
      'highlight': highlight,
      'after': after,
    };
  }

  factory BridgeLocatorText.fromJson(Map<String, Object?> json) {
    return BridgeLocatorText(
      before: _asString(json['before']),
      highlight: _asString(json['highlight']),
      after: _asString(json['after']),
    );
  }
}

class BridgeLocator {
  const BridgeLocator({
    this.href,
    this.url,
    this.locations,
    this.anchor,
    this.text,
  });

  final String? href;
  final String? url;
  final BridgeLocatorLocations? locations;
  final BridgeLocatorAnchor? anchor;
  final BridgeLocatorText? text;

  JsonMap toJson() {
    return <String, Object?>{
      'href': href,
      'url': url,
      'locations': locations?.toJson(),
      'anchor': anchor?.toJson(),
      'text': text?.toJson(),
    };
  }

  factory BridgeLocator.fromJson(Map<String, Object?> json) {
    return BridgeLocator(
      href: _asString(json['href']),
      url: _asString(json['url']),
      locations: _asMap(json['locations']) == null
          ? null
          : BridgeLocatorLocations.fromJson(_asMap(json['locations'])!),
      anchor: _asMap(json['anchor']) == null
          ? null
          : BridgeLocatorAnchor.fromJson(_asMap(json['anchor'])!),
      text: _asMap(json['text']) == null
          ? null
          : BridgeLocatorText.fromJson(_asMap(json['text'])!),
    );
  }
}

class ReaderStyleModel {
  const ReaderStyleModel({
    this.fontSize,
    this.lineHeight,
    this.fontFamily,
    this.textColor,
    this.backgroundColor,
    this.paddingTop,
    this.paddingRight,
    this.paddingBottom,
    this.paddingLeft,
    this.pageGap,
    this.columnCount,
    this.theme,
    this.linkColor,
    this.selectionColor,
    this.gutterColor,
    this.gutterShadowLeft,
    this.gutterShadowRight,
    this.textIndentEnabled,
    this.textIndentEm,
    this.textIndentSkipFirstParagraph,
    this.gutterWidth,
  });

  final double? fontSize;
  final double? lineHeight;
  final String? fontFamily;
  final String? textColor;
  final String? backgroundColor;
  final double? paddingTop;
  final double? paddingRight;
  final double? paddingBottom;
  final double? paddingLeft;
  final double? pageGap;
  final int? columnCount;
  final String? theme;
  final String? linkColor;
  final String? selectionColor;
  final String? gutterColor;
  final String? gutterShadowLeft;
  final String? gutterShadowRight;
  final bool? textIndentEnabled;
  final double? textIndentEm;
  final bool? textIndentSkipFirstParagraph;
  final double? gutterWidth;

  JsonMap toJson() {
    return <String, Object?>{
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontFamily': fontFamily,
      'textColor': textColor,
      'backgroundColor': backgroundColor,
      'paddingTop': paddingTop,
      'paddingRight': paddingRight,
      'paddingBottom': paddingBottom,
      'paddingLeft': paddingLeft,
      'pageGap': pageGap,
      'columnCount': columnCount,
      'theme': theme,
      'linkColor': linkColor,
      'selectionColor': selectionColor,
      'gutterColor': gutterColor,
      'gutterShadowLeft': gutterShadowLeft,
      'gutterShadowRight': gutterShadowRight,
      'textIndentEnabled': textIndentEnabled,
      'textIndentEm': textIndentEm,
      'textIndentSkipFirstParagraph': textIndentSkipFirstParagraph,
      'gutterWidth': gutterWidth,
    };
  }

  factory ReaderStyleModel.fromJson(Map<String, Object?> json) {
    return ReaderStyleModel(
      fontSize: _asDouble(json['fontSize']),
      lineHeight: _asDouble(json['lineHeight']),
      fontFamily: _asString(json['fontFamily']),
      textColor: _asString(json['textColor']),
      backgroundColor: _asString(json['backgroundColor']),
      paddingTop: _asDouble(json['paddingTop']),
      paddingRight: _asDouble(json['paddingRight']),
      paddingBottom: _asDouble(json['paddingBottom']),
      paddingLeft: _asDouble(json['paddingLeft']),
      pageGap: _asDouble(json['pageGap']),
      columnCount: _asInt(json['columnCount']),
      theme: _asString(json['theme']),
      linkColor: _asString(json['linkColor']),
      selectionColor: _asString(json['selectionColor']),
      gutterColor: _asString(json['gutterColor']),
      gutterShadowLeft: _asString(json['gutterShadowLeft']),
      gutterShadowRight: _asString(json['gutterShadowRight']),
      textIndentEnabled: _asBool(json['textIndentEnabled']),
      textIndentEm: _asDouble(json['textIndentEm']),
      textIndentSkipFirstParagraph: _asBool(
        json['textIndentSkipFirstParagraph'],
      ),
      gutterWidth: _asDouble(json['gutterWidth']),
    );
  }
}

class NavigatePayloadModel {
  const NavigatePayloadModel({required this.kind, this.value});

  final NavigateKind kind;
  final Object? value;

  JsonMap toJson() {
    return <String, Object?>{'kind': kind.value, 'value': value};
  }

  factory NavigatePayloadModel.fromJson(Map<String, Object?> json) {
    return NavigatePayloadModel(
      kind: navigateKindFromValue(json['kind']),
      value: json['value'],
    );
  }
}

class OpenPayloadModel {
  const OpenPayloadModel({
    required this.url,
    this.locator,
    this.highlights = const <Map<String, Object?>>[],
  });

  final String url;
  final BridgeLocator? locator;
  final List<Map<String, Object?>> highlights;

  JsonMap toJson() {
    return <String, Object?>{
      'url': url,
      'locator': locator?.toJson(),
      'highlights': highlights,
    };
  }

  factory OpenPayloadModel.fromJson(Map<String, Object?> json) {
    return OpenPayloadModel(
      url: _asString(json['url']) ?? '',
      locator: _asMap(json['locator']) == null
          ? null
          : BridgeLocator.fromJson(_asMap(json['locator'])!),
      highlights: _asList(json['highlights']),
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

List<Map<String, Object?>> _asList(Object? value) {
  if (value is List<Map<String, Object?>>) {
    return value;
  }
  if (value is List) {
    return value
        .whereType<Map>()
        .map(
          (entry) => entry.map((key, item) => MapEntry(key.toString(), item)),
        )
        .toList();
  }
  return const <Map<String, Object?>>[];
}
