import '../models/epub_book_package.dart';

class EpubReaderMetadataAdapter {
  static Map<String, Object?> toReaderMetadataJson(
    EpubBookPackage package, {
    required String bookUuid,
    Map<String, Object?>? lastLocator,
    DateTime? updatedAt,
  }) {
    return <String, Object?>{
      'bookUuid': bookUuid,
      'opfPath': package.opfPath,
      'contentRoot': package.contentRoot,
      'spineItems': package.readingOrder
          .map(
            (item) => <String, Object?>{
              'id': item.id,
              'href': item.href,
              'mediaType': item.mediaType,
              'properties': item.properties,
              'linear': item.linear,
            },
          )
          .toList(growable: false),
      'toc': package.toc.map((item) => item.toJson()).toList(growable: false),
      if (lastLocator != null && lastLocator.isNotEmpty)
        'lastLocator': lastLocator,
      'updatedAt': (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }
}
