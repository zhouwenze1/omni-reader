import 'package:foundation_domain/domain.dart';

import 'book_uri_mapper.dart';
import 'locator_normalizer.dart';

class RendererLocatorMapper {
  const RendererLocatorMapper({
    LocatorNormalizer normalizer = const LocatorNormalizer(),
  }) : _normalizer = normalizer;

  final LocatorNormalizer _normalizer;

  Map<String, dynamic> toPayload(
    Locator locator, {
    BookUriMapper? uriMapper,
    String? bookUuid,
  }) {
    final normalized = _normalizer.normalizeMap(
      locator.toJson(),
      uriMapper: uriMapper,
      bookUuid: bookUuid,
    );
    final text = normalized['text'];
    if (text is String && text.trim().isNotEmpty) {
      normalized['text'] = <String, dynamic>{'highlight': text};
    }
    return normalized;
  }

  Map<String, dynamic> normalizePayload(
    Map<String, dynamic>? payload, {
    BookUriMapper? uriMapper,
    String? bookUuid,
  }) {
    return _normalizer.normalizeMap(
      payload,
      uriMapper: uriMapper,
      bookUuid: bookUuid,
    );
  }

  Locator fromPayload(
    dynamic payload, {
    BookUriMapper? uriMapper,
    String? bookUuid,
  }) {
    return _normalizer.fromAny(
      payload,
      uriMapper: uriMapper,
      bookUuid: bookUuid,
    );
  }
}
