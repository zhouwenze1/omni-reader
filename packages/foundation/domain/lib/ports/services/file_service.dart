abstract class FileService {
  Future<void> ensureDir(String path);

  Future<Map<String, dynamic>?> readJson(String path);

  Future<void> writeJsonAtomic(String path, Map<String, dynamic> json);

  Future<void> writeTextAtomic(String path, String content);

  Future<String?> readText(String path);

  Future<void> appendLine(String path, String line);

  Future<void> copyFile(String from, String to);

  Future<void> removeDir(String path);

  Future<List<String>> listDirs(String path);

  Future<void> moveDirAtomic(String from, String to);

  Future<bool> exists(String path);
}
