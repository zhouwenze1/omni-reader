import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:foundation_domain/domain.dart';

class FingerprintServiceImpl implements FingerprintService {
  @override
  Future<String> hashPdfFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return sha256.convert(bytes).toString();
  }

  @override
  Future<String> zipFingerprint(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);

      final lines = <String>[];
      for (final entry in archive.files) {
        if (entry.isFile) {
          lines.add('${entry.name}|${entry.crc32}|${entry.size}');
        }
      }
      lines.sort();

      final canonical = utf8.encode(lines.join('\n'));
      return sha256.convert(canonical).toString();
    } catch (_) {
      final bytes = await File(filePath).readAsBytes();
      return sha256.convert(bytes).toString();
    }
  }
}
