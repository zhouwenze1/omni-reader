import 'package:foundation_domain/domain.dart';
import 'package:engine_epub/engine_epub.dart';

void main() {
  final normalizer = const LocatorNormalizer();
  final mapper = const RendererLocatorMapper();
  final locator = Locator(href: 'Text/Section000.xhtml', cfi: 'epubcfi(/6/22!/2/4/1:368)');
  final normalized = normalizer.normalizeLocator(locator);
  final payload = mapper.toPayload(normalized);
  print('normalized href: ${payload['href']}');
  print('cfi: ${payload['cfi']}');
}
