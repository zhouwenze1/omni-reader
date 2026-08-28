import 'package:reader_parser_core/reader_parser_core.dart';

class MobiParser implements FormatParser<ParsedBookPackage> {
  @override
  BookFormat get format => BookFormat.mobi;

  @override
  bool supportsFile(String filePath) {
    return BookFormat.fromFilePath(filePath) == BookFormat.mobi;
  }

  @override
  Future<ParsedBookPackage> parseFromFile(String filePath) {
    throw UnimplementedError('Mobi parser is not implemented yet.');
  }

  @override
  Future<BookMetadata> parseInfo(String filePath) {
    throw UnimplementedError('Mobi parser is not implemented yet.');
  }
}
