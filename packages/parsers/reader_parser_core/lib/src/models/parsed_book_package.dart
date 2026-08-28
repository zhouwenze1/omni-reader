import '../formats/book_format.dart';
import '../resource/book_resource_source.dart';
import 'book_artifact_bundle.dart';
import 'book_asset_item.dart';
import 'book_metadata.dart';
import 'book_toc_item.dart';

class ParsedBookPackage {
  ParsedBookPackage({
    required this.format,
    required this.sourcePath,
    required this.metadata,
    required this.contentRoot,
    required this.readingOrder,
    required this.resources,
    required this.toc,
    required this.resourceSource,
    this.artifacts = const BookArtifactBundle(),
  });

  final BookFormat format;
  final String sourcePath;
  final BookMetadata metadata;
  final String contentRoot;
  final List<BookAssetItem> readingOrder;
  final List<BookAssetItem> resources;
  final List<BookTocItem> toc;
  final BookResourceSource resourceSource;
  final BookArtifactBundle artifacts;

  Future<void> close() {
    return resourceSource.close();
  }
}

