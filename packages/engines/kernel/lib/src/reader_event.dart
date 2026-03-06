import 'package:foundation_domain/domain.dart';

enum ReaderEventType {
  load,
  ready,
  error,
  link,
  mediaTap,
  selection,
  tapIntent,
  relocated,
  boundary,
  highlightCreateRequest,
  highlightTapped,
  highlightApplyReport,
  log,
}

sealed class ReaderEventData {
  const ReaderEventData();

  Map<String, dynamic> toJson();
}

class ReaderUnknownData extends ReaderEventData {
  const ReaderUnknownData(this.raw);

  final Map<String, dynamic> raw;

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}

class ReaderLogData extends ReaderEventData {
  const ReaderLogData({
    this.phase,
    this.details = const <String, dynamic>{},
  });

  final String? phase;
  final Map<String, dynamic> details;

  factory ReaderLogData.fromJson(Map<String, dynamic> json) {
    final details = Map<String, dynamic>.from(json);
    final phase = details.remove('phase') as String?;
    return ReaderLogData(phase: phase, details: details);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (phase != null && phase!.isNotEmpty) 'phase': phase,
      ...details,
    };
  }
}

class ReaderErrorData extends ReaderEventData {
  const ReaderErrorData({
    this.phase,
    this.details = const <String, dynamic>{},
  });

  final String? phase;
  final Map<String, dynamic> details;

  factory ReaderErrorData.fromJson(Map<String, dynamic> json) {
    final details = Map<String, dynamic>.from(json);
    final phase = details.remove('phase') as String?;
    return ReaderErrorData(phase: phase, details: details);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (phase != null && phase!.isNotEmpty) 'phase': phase,
      ...details,
    };
  }
}

class ReaderTapIntentData extends ReaderEventData {
  const ReaderTapIntentData({
    this.zone,
    this.mode,
    this.raw = const <String, dynamic>{},
  });

  final String? zone;
  final String? mode;
  final Map<String, dynamic> raw;

  factory ReaderTapIntentData.fromJson(Map<String, dynamic> json) {
    return ReaderTapIntentData(
      zone: json['zone'] as String?,
      mode: json['mode'] as String?,
      raw: Map<String, dynamic>.from(json),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...raw,
      if (zone != null && zone!.isNotEmpty) 'zone': zone,
      if (mode != null && mode!.isNotEmpty) 'mode': mode,
    };
  }
}

class ReaderLinkData extends ReaderEventData {
  const ReaderLinkData({
    this.handledBy,
    this.action,
    this.href,
    this.resolved,
    this.fromUrl,
    this.raw = const <String, dynamic>{},
  });

  final String? handledBy;
  final String? action;
  final String? href;
  final String? resolved;
  final String? fromUrl;
  final Map<String, dynamic> raw;

  factory ReaderLinkData.fromJson(Map<String, dynamic> json) {
    return ReaderLinkData(
      handledBy: json['handledBy'] as String?,
      action: json['action'] as String?,
      href: json['href'] as String?,
      resolved: json['resolved'] as String?,
      fromUrl: json['fromUrl'] as String?,
      raw: Map<String, dynamic>.from(json),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...raw,
      if (handledBy != null && handledBy!.isNotEmpty) 'handledBy': handledBy,
      if (action != null && action!.isNotEmpty) 'action': action,
      if (href != null && href!.isNotEmpty) 'href': href,
      if (resolved != null && resolved!.isNotEmpty) 'resolved': resolved,
      if (fromUrl != null && fromUrl!.isNotEmpty) 'fromUrl': fromUrl,
    };
  }
}

class ReaderMediaTapData extends ReaderEventData {
  const ReaderMediaTapData({
    this.src,
    this.resolvedSrc,
    this.fromUrl,
    this.raw = const <String, dynamic>{},
  });

  final String? src;
  final String? resolvedSrc;
  final String? fromUrl;
  final Map<String, dynamic> raw;

  factory ReaderMediaTapData.fromJson(Map<String, dynamic> json) {
    return ReaderMediaTapData(
      src: json['src'] as String?,
      resolvedSrc: json['resolvedSrc'] as String?,
      fromUrl: json['fromUrl'] as String?,
      raw: Map<String, dynamic>.from(json),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...raw,
      if (src != null && src!.isNotEmpty) 'src': src,
      if (resolvedSrc != null && resolvedSrc!.isNotEmpty)
        'resolvedSrc': resolvedSrc,
      if (fromUrl != null && fromUrl!.isNotEmpty) 'fromUrl': fromUrl,
    };
  }
}

class ReaderRelocatedData extends ReaderEventData {
  const ReaderRelocatedData({
    this.progression,
    this.raw = const <String, dynamic>{},
  });

  final double? progression;
  final Map<String, dynamic> raw;

  factory ReaderRelocatedData.fromJson(Map<String, dynamic> json) {
    return ReaderRelocatedData(
      progression: (json['progression'] as num?)?.toDouble(),
      raw: Map<String, dynamic>.from(json),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      ...raw,
      if (progression != null) 'progression': progression,
    };
  }
}

class ReaderEventDataCodec {
  static ReaderEventData fromType(
    ReaderEventType type,
    Map<String, dynamic> payload,
  ) {
    switch (type) {
      case ReaderEventType.log:
        return ReaderLogData.fromJson(payload);
      case ReaderEventType.error:
        return ReaderErrorData.fromJson(payload);
      case ReaderEventType.tapIntent:
        return ReaderTapIntentData.fromJson(payload);
      case ReaderEventType.link:
        return ReaderLinkData.fromJson(payload);
      case ReaderEventType.mediaTap:
        return ReaderMediaTapData.fromJson(payload);
      case ReaderEventType.relocated:
        return ReaderRelocatedData.fromJson(payload);
      default:
        return ReaderUnknownData(payload);
    }
  }
}

class ReaderEvent {
  const ReaderEvent({
    required this.type,
    this.payload,
    this.data,
    this.locator,
    this.message,
  });

  factory ReaderEvent.fromRaw({
    required ReaderEventType type,
    Map<String, dynamic>? payload,
    Locator? locator,
    String? message,
  }) {
    final normalized = payload == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(payload);
    return ReaderEvent(
      type: type,
      payload: normalized,
      data: ReaderEventDataCodec.fromType(type, normalized),
      locator: locator,
      message: message ?? normalized['message'] as String?,
    );
  }

  final ReaderEventType type;
  final Map<String, dynamic>? payload;
  final ReaderEventData? data;
  final Locator? locator;
  final String? message;

  ReaderEventData get typedData {
    if (data != null) {
      return data!;
    }
    return ReaderEventDataCodec.fromType(
        type, payload ?? const <String, dynamic>{});
  }

  T? asData<T extends ReaderEventData>() {
    final resolved = typedData;
    if (resolved is T) {
      return resolved;
    }
    return null;
  }
}
