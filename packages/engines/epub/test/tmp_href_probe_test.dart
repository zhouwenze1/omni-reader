import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:engine_epub/engine_epub.dart';

void main() {
  test('probe normalize chain href output', () {
    final normalizer = const LocatorNormalizer();
    final mapper = const RendererLocatorMapper();
    final locator = Locator(
      href: 'Text/Section000.xhtml',
      cfi: 'epubcfi(/6/22!/2/4/1:368)',
    );
    final normalized = normalizer.normalizeLocator(locator);
    final payload = mapper.toPayload(normalized);
    // ignore: avoid_print
    print('PROBE normalized href: ${payload['href']}');
    // ignore: avoid_print
    print('PROBE cfi: ${payload['cfi']}');
    expect(true, isTrue);
  });
}
