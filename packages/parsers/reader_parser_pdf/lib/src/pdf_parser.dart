import 'package:reader_parser_core/reader_parser_core.dart';

class PdfParser implements FormatParser<ParsedBookPackage> {
  @override
  BookFormat get format => BookFormat.pdf;

  @override
  bool supportsFile(String filePath) {
    return BookFormat.fromFilePath(filePath) == BookFormat.pdf;
  }

  @override
  Future<ParsedBookPackage> parseFromFile(String filePath) {
    throw UnimplementedError('PDF parser is not implemented yet.');
  }

  @override
  Future<BookMetadata> parseInfo(String filePath) {
    throw UnimplementedError('PDF parser is not implemented yet.');
  }
}
