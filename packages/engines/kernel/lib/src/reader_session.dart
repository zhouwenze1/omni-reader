import 'package:flutter/widgets.dart';
import 'package:foundation_domain/domain.dart';

import 'reader_capability.dart';
import 'reader_event.dart';
import 'reader_style.dart';

abstract class ReaderSession {
  Widget buildView();

  Stream<ReaderEvent> get events;

  Set<ReaderCapability> get capabilities;

  ReaderStyle get style;

  Future<void> open();

  Future<void> setStyle(ReaderStyle style);

  Future<void> setLayoutMode(String layoutMode) async {}

  Future<void> patchStyle(Map<String, dynamic> patch) {
    return setStyle(style.mergePatch(patch));
  }

  Future<void> applyTheme(String theme) {
    return setStyle(style.copyWith(theme: theme));
  }

  Future<void> navigateNext();

  Future<void> navigatePrev();

  Future<void> goTo(Locator locator);

  /// Highlights a search hit inside the already-open chapter using a
  /// text-quote anchor. Engines without search support ignore this call.
  Future<void> applySearchHighlight({
    required String href,
    required String prefix,
    required String exact,
    required String suffix,
  }) async {}

  Future<void> dispose();
}
