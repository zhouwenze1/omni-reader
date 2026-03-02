abstract class FingerprintService {
  Future<String> hashPdfFile(String filePath);

  Future<String> zipFingerprint(String filePath);
}
