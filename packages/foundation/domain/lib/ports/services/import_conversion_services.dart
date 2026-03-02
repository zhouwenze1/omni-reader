class ConversionResult {
  const ConversionResult({required this.outputPath, this.clean});

  final String outputPath;
  final Future<void> Function()? clean;
}

abstract class PdfPackager {
  Future<ConversionResult> packagePdf(String inputPath, String tempRoot);
}

abstract class LpfToAudiobookConverter {
  Future<ConversionResult> convert(String inputPath, String tempRoot);
}
