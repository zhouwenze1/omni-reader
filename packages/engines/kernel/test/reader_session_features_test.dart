import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:kernel/kernel.dart';

class _FakeSession extends ReaderSession {
  @override
  Widget buildView() => throw UnimplementedError();

  @override
  Stream<ReaderEvent> get events => throw UnimplementedError();

  @override
  Set<ReaderCapability> get capabilities => const <ReaderCapability>{};

  @override
  ReaderStyle get style => ReaderStyle.defaults;

  @override
  Future<void> open() async {}

  @override
  Future<void> setStyle(ReaderStyle style) async {}

  @override
  Future<void> navigateNext() async {}

  @override
  Future<void> navigatePrev() async {}

  @override
  Future<void> goTo(Locator locator) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  group('ReaderSession self-description defaults', () {
    test('default features are all-off', () {
      final session = _FakeSession();
      final features = session.features;
      expect(features.textSelection, ReaderTextSelection.none);
      expect(features.annotationKinds, isEmpty);
      expect(features.canAnnotate, isFalse);
      expect(features.toc, isFalse);
      expect(features.pageList, isFalse);
      expect(features.search, isFalse);
      expect(features.dictionary, isFalse);
      expect(features.translate, isFalse);
      expect(features.readAloud, isFalse);
      expect(features.externalLink, isFalse);
      expect(features.mediaLightbox, isFalse);
      expect(features.layout.layoutModes, isEmpty);
      expect(features.layout.spreadable, isFalse);
      expect(features.layout.direction, ReaderDirection.ltr);
    });

    test('default settingsOptions has nothing and no groups', () {
      final session = _FakeSession();
      expect(session.settingsOptions.hasAnything, isFalse);
      expect(session.auxActions, isEmpty);
    });
  });

  group('ReaderFeatures', () {
    test('supportsKind reflects annotationKinds', () {
      const features = ReaderFeatures(
        annotationKinds: <ReaderAnnotationKind>{
          ReaderAnnotationKind.pageBookmark,
        },
      );
      expect(features.supportsKind(ReaderAnnotationKind.pageBookmark), isTrue);
      expect(features.supportsKind(ReaderAnnotationKind.textHighlight), isFalse);
    });

    test('layout.supports normalizes layout modes', () {
      const support = ReaderLayoutSupport(
        layoutModes: <String>{'paged_single', 'scroll_continuous'},
      );
      expect(support.supports('paged_single'), isTrue);
      expect(support.supports('PAGED_SINGLE'), isTrue);
      expect(support.supports('paged_spread'), isFalse);
    });
  });

  group('ReaderAuxAction', () {
    test('uniqueness is by id', () {
      const a = ReaderAuxAction(id: 'pageList', iconKey: 'grid', labelKey: 'pages');
      const b = ReaderAuxAction(id: 'pageList', iconKey: 'other', labelKey: 'other');
      const c = ReaderAuxAction(id: 'other', iconKey: 'grid', labelKey: 'pages');
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });
  });
}
