import 'package:reader_parser_core/reader_parser_core.dart';

class ComicZipParser implements FormatParser<ParsedBookPackage> {
  @override
  BookFormat get format => BookFormat.comicZip;

  @override
  bool supportsFile(String filePath) {
    return BookFormat.fromFilePath(filePath) == BookFormat.comicZip;
  }

  @override
  Future<ParsedBookPackage> parseFromFile(String filePath) {
    throw UnimplementedError('ComicZip parser is not implemented yet.');
  }

  @override
  Future<BookMetadata> parseInfo(String filePath) {
    throw UnimplementedError('ComicZip parser is not implemented yet.');
  }
}

