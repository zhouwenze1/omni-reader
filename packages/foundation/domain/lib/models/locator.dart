class Locator {
  const Locator({
    this.href,
    this.url,
    this.cfi,
    this.locations,
    this.anchor,
    this.text,
    this.extras,
  });

  final String? href;
  final String? url;
  final String? cfi;
  final Map<String, dynamic>? locations;
  final Map<String, dynamic>? anchor;
  final String? text;
  final Map<String, dynamic>? extras;

  Locator copyWith({
    String? href,
    String? url,
    String? cfi,
    Map<String, dynamic>? locations,
    Map<String, dynamic>? anchor,
    String? text,
    Map<String, dynamic>? extras,
  }) {
    return Locator(
      href: href ?? this.href,
      url: url ?? this.url,
      cfi: cfi ?? this.cfi,
      locations: locations ?? this.locations,
      anchor: anchor ?? this.anchor,
      text: text ?? this.text,
      extras: extras ?? this.extras,
    );
  }

  factory Locator.fromJson(Map<String, dynamic> json) {
    return Locator(
      href: json['href'] as String?,
      url: json['url'] as String?,
      cfi: json['cfi'] as String?,
      locations: _asMap(json['locations']),
      anchor: _asMap(json['anchor']),
      text: json['text'] as String?,
      extras: _asMap(json['extras']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (href != null && href!.isNotEmpty) 'href': href,
      if (url != null && url!.isNotEmpty) 'url': url,
      if (cfi != null && cfi!.isNotEmpty) 'cfi': cfi,
      if (locations != null && locations!.isNotEmpty) 'locations': locations,
      if (anchor != null && anchor!.isNotEmpty) 'anchor': anchor,
      if (text != null && text!.isNotEmpty) 'text': text,
      if (extras != null && extras!.isNotEmpty) 'extras': extras,
    };
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return null;
  }
}
