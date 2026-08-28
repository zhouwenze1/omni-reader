class BookManifestDocument {
  const BookManifestDocument({
    required this.metadata,
    required this.readingOrder,
    this.resources = const <Map<String, Object?>>[],
    this.toc = const <Map<String, Object?>>[],
    this.links = const <Map<String, Object?>>[],
    this.context = 'https://readium.org/webpub-manifest/context.jsonld',
  });

  final String context;
  final Map<String, Object?> metadata;
  final List<Map<String, Object?>> readingOrder;
  final List<Map<String, Object?>> resources;
  final List<Map<String, Object?>> toc;
  final List<Map<String, Object?>> links;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      '@context': context,
      'metadata': metadata,
      'readingOrder': readingOrder,
      if (resources.isNotEmpty) 'resources': resources,
      if (toc.isNotEmpty) 'toc': toc,
      if (links.isNotEmpty) 'links': links,
    };
  }
}
