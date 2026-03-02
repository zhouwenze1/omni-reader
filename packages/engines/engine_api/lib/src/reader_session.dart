import 'package:flutter/widgets.dart';
import 'package:foundation_domain/domain.dart';

import 'engine_event.dart';

abstract class ReaderSession {
  Widget buildView();

  Stream<EngineEvent> get events;

  Future<void> open();

  Future<void> setStyle(Map<String, dynamic> style);

  Future<void> applyTheme(String theme);

  Future<void> navigateNext();

  Future<void> navigatePrev();

  Future<void> goTo(Locator locator);

  Future<void> dispose();
}
