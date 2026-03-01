typedef JsonMap = Map<String, Object?>;

class DomRectLike {
  const DomRectLike({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  DomRectLike copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    return DomRectLike(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  JsonMap toJson() {
    return <String, Object?>{
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }

  factory DomRectLike.fromJson(Map<String, Object?> json) {
    return DomRectLike(
      left: _asDouble(json['left']) ?? 0,
      top: _asDouble(json['top']) ?? 0,
      width: _asDouble(json['width']) ?? 0,
      height: _asDouble(json['height']) ?? 0,
    );
  }
}

class LocatorLocations {
  const LocatorLocations({
    this.position,
    this.progression,
    this.totalProgression,
    this.page,
    this.totalPages,
    this.audioPositionMs,
    this.audioDurationMs,
  });

  final int? position;
  final double? progression;
  final double? totalProgression;
  final int? page;
  final int? totalPages;
  final int? audioPositionMs;
  final int? audioDurationMs;

  Duration? get audioPosition =>
      audioPositionMs == null ? null : Duration(milliseconds: audioPositionMs!);

  Duration? get audioDuration =>
      audioDurationMs == null ? null : Duration(milliseconds: audioDurationMs!);

  LocatorLocations copyWith({
    int? position,
    double? progression,
    double? totalProgression,
    int? page,
    int? totalPages,
    int? audioPositionMs,
    int? audioDurationMs,
  }) {
    return LocatorLocations(
      position: position ?? this.position,
      progression: progression ?? this.progression,
      totalProgression: totalProgression ?? this.totalProgression,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      audioPositionMs: audioPositionMs ?? this.audioPositionMs,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
    );
  }

  JsonMap toJson() {
    return <String, Object?>{
      'position': position,
      'progression': progression,
      'totalProgression': totalProgression,
      'page': page,
      'totalPages': totalPages,
      'audioPositionMs': audioPositionMs,
      'audioDurationMs': audioDurationMs,
    };
  }

  factory LocatorLocations.fromJson(Map<String, Object?> json) {
    return LocatorLocations(
      position: _asInt(json['position']),
      progression: _asDouble(json['progression']),
      totalProgression: _asDouble(json['totalProgression']),
      page: _asInt(json['page']),
      totalPages: _asInt(json['totalPages']),
      audioPositionMs: _asInt(json['audioPositionMs']),
      audioDurationMs: _asInt(json['audioDurationMs']),
    );
  }
}

class LocatorAnchor {
  const LocatorAnchor({
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
  final DomRectLike? rect;

  LocatorAnchor copyWith({
    String? uid,
    String? uidNext,
    String? xpath,
    int? offset,
    DomRectLike? rect,
  }) {
    return LocatorAnchor(
      uid: uid ?? this.uid,
      uidNext: uidNext ?? this.uidNext,
      xpath: xpath ?? this.xpath,
      offset: offset ?? this.offset,
      rect: rect ?? this.rect,
    );
  }

  JsonMap toJson() {
    return <String, Object?>{
      'uid': uid,
      'uidNext': uidNext,
      'xpath': xpath,
      'offset': offset,
      'rect': rect?.toJson(),
    };
  }

  factory LocatorAnchor.fromJson(Map<String, Object?> json) {
    return LocatorAnchor(
      uid: _asString(json['uid']),
      uidNext: _asString(json['uidNext']),
      xpath: _asString(json['xpath']),
      offset: _asInt(json['offset']),
      rect: _asMap(json['rect']) == null
          ? null
          : DomRectLike.fromJson(_asMap(json['rect'])!),
    );
  }
}

class LocatorTextContext {
  const LocatorTextContext({this.before, this.highlight, this.after});

  final String? before;
  final String? highlight;
  final String? after;

  LocatorTextContext copyWith({
    String? before,
    String? highlight,
    String? after,
  }) {
    return LocatorTextContext(
      before: before ?? this.before,
      highlight: highlight ?? this.highlight,
      after: after ?? this.after,
    );
  }

  JsonMap toJson() {
    return <String, Object?>{
      'before': before,
      'highlight': highlight,
      'after': after,
    };
  }

  factory LocatorTextContext.fromJson(Map<String, Object?> json) {
    return LocatorTextContext(
      before: _asString(json['before']),
      highlight: _asString(json['highlight']),
      after: _asString(json['after']),
    );
  }
}

class Locator {
  const Locator({
    this.href,
    this.url,
    this.locations,
    this.anchor,
    this.text,
    this.extras = const <String, Object?>{},
  });

  final String? href;
  final String? url;
  final LocatorLocations? locations;
  final LocatorAnchor? anchor;
  final LocatorTextContext? text;
  final Map<String, Object?> extras;

  Locator copyWith({
    String? href,
    String? url,
    LocatorLocations? locations,
    LocatorAnchor? anchor,
    LocatorTextContext? text,
    Map<String, Object?>? extras,
  }) {
    return Locator(
      href: href ?? this.href,
      url: url ?? this.url,
      locations: locations ?? this.locations,
      anchor: anchor ?? this.anchor,
      text: text ?? this.text,
      extras: extras ?? this.extras,
    );
  }

  JsonMap toJson() {
    return <String, Object?>{
      'href': href,
      'url': url,
      'locations': locations?.toJson(),
      'anchor': anchor?.toJson(),
      'text': text?.toJson(),
      'extras': extras,
    };
  }

  factory Locator.fromJson(Map<String, Object?> json) {
    return Locator(
      href: _asString(json['href']),
      url: _asString(json['url']),
      locations: _asMap(json['locations']) == null
          ? null
          : LocatorLocations.fromJson(_asMap(json['locations'])!),
      anchor: _asMap(json['anchor']) == null
          ? null
          : LocatorAnchor.fromJson(_asMap(json['anchor'])!),
      text: _asMap(json['text']) == null
          ? null
          : LocatorTextContext.fromJson(_asMap(json['text'])!),
      extras: _asMap(json['extras']) ?? const <String, Object?>{},
    );
  }
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
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

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
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
