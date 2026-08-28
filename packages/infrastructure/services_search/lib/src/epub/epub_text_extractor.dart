import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:reader_parser_core/reader_parser_core.dart';
import 'package:reader_parser_epub/reader_parser_epub.dart';

import '../models.dart';

/// Reads chapter texts from an EPUB using the in-house parser stack
/// (`reader_parser_epub`), replacing the former `epub_pro` dependency.
///
/// Chapter CFIs use the same progress shape the renderer documents:
/// `epubcfi(/6/<2*(spineIndex+1)>!)`, i.e. a chapter-start locator whose
/// `/6/N` step encodes the spine position.
class EpubTextExtractor implements ChapterTextSource {
  const EpubTextExtractor();

  @override
  Future<List<ChapterText>> readChapters(Uint8List epubBytes) async {
    final source = await _MemoryZipResourceSource.open(epubBytes);
    final parser = EpubParser();
    final package = await parser.parseFromSource(source);
    try {
      final chapters = <ChapterText>[];
      for (var index = 0; index < package.readingOrder.length; index++) {
        final item = package.readingOrder[index];
        if (!_isHtmlDocument(item)) {
          continue;
        }
        // readingOrder hrefs are relative to contentRoot; read with the
        // archive-absolute path but report the contentRoot-relative href
        // (same shape as spine manifest hrefs).
        final archivePath = package.contentRoot.isEmpty
            ? item.href
            : '${package.contentRoot}/${item.href}';
        final html = await source.readText(archivePath);
        if (html == null || html.isEmpty) {
          continue;
        }
        chapters.add(
          ChapterText(
            spineIndex: index,
            href: item.href,
            cfi: 'epubcfi(/6/${2 * (index + 1)}!)',
            text: html,
          ),
        );
      }
      return chapters;
    } finally {
      await package.close();
    }
  }

  bool _isHtmlDocument(BookAssetItem item) {
    final mediaType = item.mediaType.trim().toLowerCase();
    if (mediaType == 'application/xhtml+xml' || mediaType == 'text/html') {
      return true;
    }
    if (mediaType.isEmpty) {
      final lower = item.href.toLowerCase();
      return lower.endsWith('.xhtml') || lower.endsWith('.html') || lower.endsWith('.htm');
    }
    return false;
  }
}

/// In-memory [BookResourceSource] over decoded zip entries, mirroring the
/// path-normalization semantics of the parser's file-backed sources.
class _MemoryZipResourceSource implements BookResourceSource {
  _MemoryZipResourceSource._(Map<String, Uint8List> entries)
      : _entries = entries;

  static Future<_MemoryZipResourceSource> open(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final entries = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      entries[_normalize(file.name)] = file.content;
    }
    return _MemoryZipResourceSource._(entries);
  }

  final Map<String, Uint8List> _entries;

  @override
  String get sourceId => 'memory:zip';

  @override
  Future<List<String>> listPaths() async => _entries.keys.toList(growable: false);

  @override
  Future<bool> exists(String relativePath) async =>
      _entries.containsKey(_normalize(relativePath));

  @override
  Future<Uint8List?> readBytes(String relativePath) async =>
      _entries[_normalize(relativePath)];

  @override
  Future<String?> readText(
    String relativePath, {
    Encoding encoding = utf8,
  }) async {
    final bytes = _entries[_normalize(relativePath)];
    if (bytes == null) {
      return null;
    }
    return encoding.decode(bytes);
  }

  @override
  String? contentTypeFor(String relativePath) {
    final lower = relativePath.toLowerCase();
    if (lower.endsWith('.xhtml') || lower.endsWith('.html') || lower.endsWith('.htm')) {
      return 'application/xhtml+xml';
    }
    if (lower.endsWith('.opf')) {
      return 'application/oebps-package+xml';
    }
    if (lower.endsWith('.ncx')) {
      return 'application/x-dtbncx+xml';
    }
    if (lower.endsWith('.css')) {
      return 'text/css';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }

  @override
  Future<void> close() async {}

  static String _normalize(String value) {
    return value.replaceAll('\\', '/').trim();
  }
}
