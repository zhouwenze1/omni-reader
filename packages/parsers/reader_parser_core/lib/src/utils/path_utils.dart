import 'package:path/path.dart' as p;

class PathUtils {
  static String normalizeRelative(String input) {
    final raw = input.trim().replaceAll('\\', '/');
    if (raw.isEmpty || raw == '.' || raw == '/') {
      return '';
    }
    final normalized = p.posix.normalize(raw);
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }
    return normalized.replaceFirst(RegExp(r'^/+'), '');
  }

  static String dirname(String input) {
    final normalized = normalizeRelative(input);
    if (normalized.isEmpty) {
      return '';
    }
    final dir = p.posix.dirname(normalized);
    return dir == '.' ? '' : dir;
  }

  static String basename(String input) {
    return p.posix.basename(normalizeRelative(input));
  }

  static String extension(String input) {
    return p.posix.extension(normalizeRelative(input)).toLowerCase();
  }

  static String joinRelative(String baseDir, String relativePath) {
    final base = normalizeRelative(baseDir);
    final relative = normalizeRelative(relativePath);
    if (base.isEmpty) {
      return relative;
    }
    if (relative.isEmpty) {
      return base;
    }
    return normalizeRelative(p.posix.join(base, relative));
  }

  static String resolveAgainstFile(String baseFilePath, String relativePath) {
    final baseDir = dirname(baseFilePath);
    return joinRelative(baseDir, relativePath);
  }

  static String relativeToDirectory(String baseDir, String filePath) {
    final relative = p.relative(filePath, from: baseDir);
    return normalizeRelative(relative);
  }

  static String joinNative(String baseDir, String relativePath) {
    final parts = normalizeRelative(relativePath)
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return p.joinAll(<String>[baseDir, ...parts]);
  }
}

