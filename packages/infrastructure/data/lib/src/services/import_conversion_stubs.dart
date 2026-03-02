import 'package:foundation_domain/domain.dart';

class StubPdfPackager implements PdfPackager {
  @override
  Future<ConversionResult> packagePdf(String inputPath, String tempRoot) async {
    return ConversionResult(outputPath: inputPath);
  }
}

class StubLpfToAudiobookConverter implements LpfToAudiobookConverter {
  @override
  Future<ConversionResult> convert(String inputPath, String tempRoot) async {
    return ConversionResult(outputPath: inputPath);
  }
}
