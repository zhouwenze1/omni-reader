import 'package:foundation_domain/domain.dart';

enum EngineEventType {
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

class EngineEvent {
  const EngineEvent({
    required this.type,
    this.payload,
    this.locator,
    this.message,
  });

  final EngineEventType type;
  final Map<String, dynamic>? payload;
  final Locator? locator;
  final String? message;
}
