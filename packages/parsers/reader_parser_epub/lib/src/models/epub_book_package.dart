import 'package:reader_parser_core/reader_parser_core.dart';

import 'epub_node_locator.dart';

class EpubBookPackage extends ParsedBookPackage {
  EpubBookPackage({
    required super.sourcePath,
    required super.metadata,
    required super.contentRoot,
    required super.readingOrder,
    required super.resources,
    required super.toc,
    required super.resourceSource,
    required this.opfPath,
    required this.containerPath,
    required this.manifestById,
    required this.spineIds,
    this.navPath,
    this.ncxPath,
    this.locatorsByHref = const <String, List<EpubNodeLocator>>{},
    super.artifacts = const BookArtifactBundle(),
  }) : super(format: BookFormat.epub);

  final String containerPath;
  final String opfPath;
  final Map<String, BookAssetItem> manifestById;
  final List<String> spineIds;
  final String? navPath;
  final String? ncxPath;
  final Map<String, List<EpubNodeLocator>> locatorsByHref;

  EpubBookPackage copyWith({
    BookMetadata? metadata,
    String? contentRoot,
    List<BookAssetItem>? readingOrder,
    List<BookAssetItem>? resources,
    List<BookTocItem>? toc,
    BookArtifactBundle? artifacts,
    Map<String, BookAssetItem>? manifestById,
    List<String>? spineIds,
    String? navPath,
    String? ncxPath,
    Map<String, List<EpubNodeLocator>>? locatorsByHref,
  }) {
    return EpubBookPackage(
      sourcePath: sourcePath,
      metadata: metadata ?? this.metadata,
      contentRoot: contentRoot ?? this.contentRoot,
      readingOrder: readingOrder ?? this.readingOrder,
      resources: resources ?? this.resources,
      toc: toc ?? this.toc,
      resourceSource: resourceSource,
      opfPath: opfPath,
      containerPath: containerPath,
      manifestById: manifestById ?? this.manifestById,
      spineIds: spineIds ?? this.spineIds,
      navPath: navPath ?? this.navPath,
      ncxPath: ncxPath ?? this.ncxPath,
      locatorsByHref: locatorsByHref ?? this.locatorsByHref,
      artifacts: artifacts ?? this.artifacts,
    );
  }
}
