enum ReaderLinkAction {
  blocked,
  renderer,
  openExternal,
  ignore,
}

class ReaderLinkDecision {
  const ReaderLinkDecision({
    required this.action,
    required this.externalUri,
  });

  final ReaderLinkAction action;
  final Uri? externalUri;
}

class ReaderEventParser {
  static Map<String, dynamic>? selectPayload({
    Map<String, dynamic>? typed,
    Map<String, dynamic>? payload,
  }) {
    return typed ?? payload;
  }

  static double resolveProgression({
    required Map<String, dynamic>? payload,
    required Map<String, dynamic>? locatorLocations,
    double fallback = 0,
  }) {
    final payloadTotalProgress = _asDouble(payload?['totalProgression']);
    final locatorTotalProgress =
        _asDouble(locatorLocations?['totalProgression']);
    final payloadProgress = _asDouble(payload?['progression']);
    final locatorProgress = _asDouble(locatorLocations?['progression']);
    return payloadTotalProgress ??
        locatorTotalProgress ??
        payloadProgress ??
        locatorProgress ??
        fallback;
  }

  static ReaderLinkDecision resolveLink(Map<String, dynamic> payload) {
    final handledBy = _asLowerText(payload['handledBy']);
    if (handledBy == 'blocked') {
      return const ReaderLinkDecision(
        action: ReaderLinkAction.blocked,
        externalUri: null,
      );
    }
    if (handledBy == 'renderer') {
      return const ReaderLinkDecision(
        action: ReaderLinkAction.renderer,
        externalUri: null,
      );
    }

    final action = _asLowerText(payload['action']);
    final externalUri = resolveExternalUri(payload);
    if (action == 'open_external' && externalUri != null) {
      return ReaderLinkDecision(
        action: ReaderLinkAction.openExternal,
        externalUri: externalUri,
      );
    }

    return const ReaderLinkDecision(
      action: ReaderLinkAction.ignore,
      externalUri: null,
    );
  }

  static Uri? resolveExternalUri(Map<String, dynamic> payload) {
    final resolved = _resolveUrlCandidate(payload, 'resolved');
    if (resolved != null && resolved.hasScheme) {
      return resolved;
    }
    final href = _resolveUrlCandidate(payload, 'href');
    if (href != null && href.hasScheme) {
      return href;
    }
    return null;
  }

  static String? resolveMediaSource(Map<String, dynamic> payload) {
    final resolved = _resolveUrlCandidate(payload, 'resolvedSrc');
    if (resolved != null) {
      return resolved.toString();
    }
    final src = _resolveUrlCandidate(payload, 'src');
    return src?.toString();
  }

  static Uri? _resolveUrlCandidate(Map<String, dynamic> payload, String key) {
    final rawValue = _asText(payload[key]);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final direct = Uri.tryParse(rawValue);
    if (direct != null && direct.hasScheme) {
      return direct;
    }

    final fromUrl = _asText(payload['fromUrl']);
    final base = fromUrl == null ? null : Uri.tryParse(fromUrl);
    if (base != null) {
      return base.resolve(rawValue);
    }
    return direct;
  }

  static String? _asText(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static String _asLowerText(Object? value) {
    return _asText(value)?.toLowerCase() ?? '';
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
