import 'package:foundation_domain/domain.dart';

import 'book_uri_mapper.dart';

class LocatorNormalizer {
  const LocatorNormalizer();

  Locator normalizeLocator(
    Locator locator, {
    BookUriMapper? uriMapper,
    String? bookUuid,
  }) {
    final map = normalizeMap(
      locator.toJson(),
      uriMapper: uriMapper,
      bookUuid: bookUuid,
    );
    return Locator.fromJson(map);
  }

  Map<String, dynamic> normalizeMap(
    Map<String, dynamic>? raw, {
    BookUriMapper? uriMapper,
    String? bookUuid,
  }) {
    final source = raw ?? const <String, dynamic>{};
    final hrefOrUrl =
        _asNonEmptyString(source['href']) ?? _asNonEmptyString(source['url']);

    final href = _normalizeHref(
      hrefOrUrl,
      uriMapper: uriMapper,
      bookUuid: bookUuid,
    );

    final cfi = _asNonEmptyString(source['cfi']);
    final progression = _extractProgression(source['locations']);
    final anchor = _normalizeAnchor(source['anchor']);

    final result = <String, dynamic>{};
    if (href != null && href.isNotEmpty) {
      result['href'] = href;
    }
    if (cfi != null && cfi.isNotEmpty) {
      result['cfi'] = cfi;
    }
    if (progression != null) {
      result['locations'] = <String, dynamic>{'progression': progression};
    }
    if (anchor != null && anchor.isNotEmpty) {
      result['anchor'] = anchor;
    }
    return result;
  }

  Map<String, dynamic> toReaderPayload(
    Locator locator, {
    BookUriMapper? uriMapper,
    String? bookUuid,
  }) {
    return normalizeMap(
      locator.toJson(),
      uriMapper: uriMapper,
      bookUuid: bookUuid,
    );
  }

  Locator fromAny(
    dynamic value, {
    BookUriMapper? uriMapper,
    String? bookUuid,
  }) {
    final map = _toMap(value);
    return Locator.fromJson(
      normalizeMap(
        map,
        uriMapper: uriMapper,
        bookUuid: bookUuid,
      ),
    );
  }

  Map<String, dynamic>? _normalizeAnchor(dynamic rawAnchor) {
    final anchorMap = _toMap(rawAnchor);
    if (anchorMap == null || anchorMap.isEmpty) {
      return null;
    }
    final uid = _asNonEmptyString(anchorMap['uid']);
    final offset = _toInt(anchorMap['offset']);
    final offsetEnd = _toInt(anchorMap['offsetEnd']);

    final result = <String, dynamic>{};
    if (uid != null) {
      result['uid'] = uid;
    }
    if (offset != null) {
      result['offset'] = offset;
    }
    if (offsetEnd != null) {
      result['offsetEnd'] = offsetEnd;
    }
    return result.isEmpty ? null : result;
  }

  double? _extractProgression(dynamic rawLocations) {
    final map = _toMap(rawLocations);
    if (map == null) {
      return null;
    }
    final progression = map['progression'];
    if (progression is num) {
      return progression.toDouble();
    }
    if (progression is String) {
      return double.tryParse(progression);
    }
    return null;
  }

  String? _normalizeHref(
    String? value, {
    BookUriMapper? uriMapper,
    String? bookUuid,
  }) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.startsWith('book://')) {
      if (uriMapper != null) {
        final http = uriMapper.bookToHttp(trimmed);
        return uriMapper.hrefFromHttpUrl(http);
      }
      final uri = Uri.parse(trimmed);
      return uri.path.replaceFirst(RegExp(r'^/+'), '');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      if (uriMapper != null) {
        return uriMapper.hrefFromHttpUrl(trimmed);
      }
      return uri.path.replaceFirst(RegExp(r'^/+'), '');
    }

    if (bookUuid != null &&
        uriMapper != null &&
        trimmed.startsWith('/book/$bookUuid/')) {
      return trimmed.replaceFirst('/book/$bookUuid/', '');
    }

    if (uriMapper != null) {
      return uriMapper.toPublicHref(trimmed);
    }

    return trimmed.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  }

  String? _asNonEmptyString(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') {
      return null;
    }
    return text;
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry('$key', val));
    }
    return null;
  }
}
