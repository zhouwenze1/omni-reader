class EpubReaderPackageExport {
  const EpubReaderPackageExport({
    required this.bookUuid,
    required this.rootDirectoryPath,
    required this.archivePath,
    required this.metadataPath,
    required this.artifactPaths,
  });

  final String bookUuid;
  final String rootDirectoryPath;
  final String archivePath;
  final String metadataPath;
  final Map<String, String> artifactPaths;

  Map<String, String> get files {
    return <String, String>{
      'book.epub': archivePath,
      'meta.json': metadataPath,
      ...artifactPaths,
    };
  }
}
