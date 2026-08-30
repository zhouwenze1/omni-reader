import 'package:flutter/widgets.dart';
import 'package:foundation_domain/domain.dart';

import 'reader_capability.dart';
import 'reader_event.dart';
import 'reader_highlight.dart';
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

  /// Makes the current book's user highlights available to the engine.
  /// Engines without highlight support ignore this call.
  Future<void> setActiveHighlights(List<ReaderHighlight> highlights) async {}

  /// Applies one user highlight and returns whether the engine acknowledged it.
  Future<bool> applyUserHighlight(ReaderHighlight highlight) async => false;

  /// Changes one user's highlight color.
  Future<bool> updateUserHighlightColor({
    required String uid,
    required String color,
  }) async =>
      false;

  /// Removes one user highlight.
  Future<bool> removeUserHighlight(String uid) async => false;

  /// Reads the currently selected text as a stable text-quote anchor.
  Future<ReaderSelectionQuote?> getSelectionQuote() async => null;

  Future<void> navigateNext();

  Future<void> navigatePrev();

  Future<void> goTo(Locator locator);

  /// Highlights a search hit inside the already-open chapter using a
  /// text-quote anchor. Engines without search support ignore this call.
  /// Applies a temporary search-hit highlight and reports whether the
  /// renderer actually created it.
  ///
  /// Engines without search support return `false`.
  Future<bool> applySearchHighlight({
    required String href,
    required String prefix,
    required String exact,
    required String suffix,
    int? requestToken,
  }) async =>
      false;

  /// Removes a previous search-hit highlight.
  Future<void> clearSearchHighlight({int? requestToken}) async {}

  Future<void> dispose();
}
