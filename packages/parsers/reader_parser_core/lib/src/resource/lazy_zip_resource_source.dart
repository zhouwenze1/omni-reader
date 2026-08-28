import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../utils/mime_utils.dart';
import '../utils/path_utils.dart';
import 'book_resource_source.dart';

class LazyZipResourceSource implements BookResourceSource {
  LazyZipResourceSource._({
    required this.sourceId,
    required String archivePath,
    required Map<String, _LazyZipEntry> entries,
    required this.maxCacheBytes,
    required this.maxCachedEntryBytes,
  })  : _archivePath = archivePath,
        _entries = entries;

  static Future<LazyZipResourceSource> open(
    String archivePath, {
    int maxCacheBytes = 8 * 1024 * 1024,
    int maxCachedEntryBytes = 512 * 1024,
  }) async {
    final file = File(archivePath);
    if (!await file.exists()) {
      throw StateError('ZIP file not found: $archivePath');
    }

    final fileSize = await file.length();
    final entries = await _LazyZipIndexReader(
      archivePath: archivePath,
      fileSize: fileSize,
    ).readEntries();

    return LazyZipResourceSource._(
      sourceId: archivePath,
      archivePath: archivePath,
      entries: entries,
      maxCacheBytes: maxCacheBytes,
      maxCachedEntryBytes: maxCachedEntryBytes,
    );
  }

  @override
  final String sourceId;

  final String _archivePath;
  final Map<String, _LazyZipEntry> _entries;
  final int maxCacheBytes;
  final int maxCachedEntryBytes;

  final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();
  int _cachedBytes = 0;

  @override
  Future<List<String>> listPaths() async {
    final paths = _entries.keys.toList(growable: false)..sort();
    return paths;
  }

  @override
  Future<bool> exists(String relativePath) async {
    final normalized = PathUtils.normalizeRelative(relativePath);
    return _entries.containsKey(normalized);
  }

  @override
  Future<Uint8List?> readBytes(String relativePath) async {
    final normalized = PathUtils.normalizeRelative(relativePath);
    final entry = _entries[normalized];
    if (entry == null) {
      return null;
    }

    final cached = _readCache(normalized);
    if (cached != null) {
      return cached;
    }

    final file = File(_archivePath);
    final raf = await file.open();
    try {
      await raf.setPosition(entry.dataOffset);
      final compressedBytes = await raf.read(entry.compressedSize);
      if (compressedBytes.length != entry.compressedSize) {
        throw StateError(
          'Unexpected EOF while reading ZIP entry: ${entry.path}',
        );
      }
      final decoded = _decompress(entry: entry, compressedBytes: compressedBytes);
      _writeCache(normalized, decoded);
      return decoded;
    } finally {
      await raf.close();
    }
  }

  @override
  Future<String?> readText(
    String relativePath, {
    Encoding encoding = utf8,
  }) async {
    final bytes = await readBytes(relativePath);
    if (bytes == null) {
      return null;
    }
    if (encoding == utf8) {
      return const Utf8Decoder(allowMalformed: true).convert(bytes);
    }
    return encoding.decode(bytes);
  }

  @override
  String? contentTypeFor(String relativePath) {
    return MimeUtils.byPath(relativePath);
  }

  Uint8List? _readCache(String path) {
    final value = _cache.remove(path);
    if (value == null) {
      return null;
    }
    _cache[path] = value;
    return value;
  }

  void _writeCache(String path, Uint8List bytes) {
    if (bytes.length > maxCachedEntryBytes || maxCacheBytes <= 0) {
      return;
    }
    final existing = _cache.remove(path);
    if (existing != null) {
      _cachedBytes -= existing.length;
    }
    _cache[path] = bytes;
    _cachedBytes += bytes.length;
    while (_cachedBytes > maxCacheBytes && _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final removed = _cache.remove(oldestKey);
      if (removed != null) {
        _cachedBytes -= removed.length;
      }
    }
  }

  Uint8List _decompress({
    required _LazyZipEntry entry,
    required Uint8List compressedBytes,
  }) {
    if (entry.isEncrypted) {
      throw UnsupportedError(
        'Encrypted ZIP entries are not supported: ${entry.path}',
      );
    }

    late final List<int> decoded;
    switch (entry.compressionMethod) {
      case _ZipSignatures.storeMethod:
        decoded = compressedBytes;
        break;
      case _ZipSignatures.deflateMethod:
        decoded = ZLibDecoder(raw: true).convert(compressedBytes);
        break;
      default:
        throw UnsupportedError(
          'Unsupported ZIP compression method '
          '${entry.compressionMethod} for ${entry.path}',
        );
    }

    final result = decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
    if (entry.uncompressedSize >= 0 &&
        result.length != entry.uncompressedSize) {
      throw StateError(
        'ZIP entry size mismatch for ${entry.path}: '
        'expected ${entry.uncompressedSize}, got ${result.length}',
      );
    }
    return result;
  }

  @override
  Future<void> close() async {
    _cache.clear();
    _cachedBytes = 0;
  }
}

class _LazyZipIndexReader {
  _LazyZipIndexReader({
    required this.archivePath,
    required this.fileSize,
  });

  final String archivePath;
  final int fileSize;

  Future<Map<String, _LazyZipEntry>> readEntries() async {
    final file = File(archivePath);
    final raf = await file.open();
    try {
      final eocd = await _readEndOfCentralDirectory(raf);
      final records = await _readCentralDirectoryRecords(
        raf,
        eocd.centralDirectoryOffset,
        eocd.centralDirectorySize,
      );

      final entries = <String, _LazyZipEntry>{};
      for (final record in records) {
        final dataOffset = await _readLocalFileDataOffset(
          raf,
          record.localHeaderOffset,
        );
        if (record.isDirectory) {
          continue;
        }
        entries[record.path] = _LazyZipEntry(
          path: record.path,
          compressionMethod: record.compressionMethod,
          compressedSize: record.compressedSize,
          uncompressedSize: record.uncompressedSize,
          localHeaderOffset: record.localHeaderOffset,
          dataOffset: dataOffset,
          flags: record.flags,
        );
      }
      return entries;
    } finally {
      await raf.close();
    }
  }

  Future<_EndOfCentralDirectory> _readEndOfCentralDirectory(
    RandomAccessFile raf,
  ) async {
    final searchWindow = fileSize < _ZipSignatures.maxEocdSearch
        ? fileSize
        : _ZipSignatures.maxEocdSearch;
    final start = fileSize - searchWindow;
    await raf.setPosition(start);
    final tail = await raf.read(searchWindow);
    final eocdOffsetInTail = _findEocdOffset(tail);
    if (eocdOffsetInTail < 0) {
      throw StateError('EOCD not found in ZIP archive: $archivePath');
    }

    final eocdOffset = start + eocdOffsetInTail;
    final data = ByteData.sublistView(tail);
    final diskNumber = data.getUint16(
      eocdOffsetInTail + 4,
      Endian.little,
    );
    final startDisk = data.getUint16(
      eocdOffsetInTail + 6,
      Endian.little,
    );
    var entriesOnDisk = data.getUint16(
      eocdOffsetInTail + 8,
      Endian.little,
    );
    var totalEntries = data.getUint16(
      eocdOffsetInTail + 10,
      Endian.little,
    );
    var centralDirectorySize = data.getUint32(
      eocdOffsetInTail + 12,
      Endian.little,
    );
    var centralDirectoryOffset = data.getUint32(
      eocdOffsetInTail + 16,
      Endian.little,
    );

    if (diskNumber != 0 || startDisk != 0) {
      throw UnsupportedError(
        'Multi-disk ZIP archives are not supported: $archivePath',
      );
    }

    final usesZip64 =
        entriesOnDisk == 0xffff ||
        totalEntries == 0xffff ||
        centralDirectorySize == 0xffffffff ||
        centralDirectoryOffset == 0xffffffff;

    if (usesZip64) {
      final zip64 = await _readZip64EndOfCentralDirectory(raf, eocdOffset);
      entriesOnDisk = zip64.entriesOnDisk;
      totalEntries = zip64.totalEntries;
      centralDirectorySize = zip64.centralDirectorySize;
      centralDirectoryOffset = zip64.centralDirectoryOffset;
    }

    return _EndOfCentralDirectory(
      entriesOnDisk: entriesOnDisk,
      totalEntries: totalEntries,
      centralDirectorySize: centralDirectorySize,
      centralDirectoryOffset: centralDirectoryOffset,
    );
  }

  int _findEocdOffset(Uint8List tail) {
    if (tail.length < _ZipSignatures.eocdSize) {
      return -1;
    }
    final data = ByteData.sublistView(tail);
    for (var offset = tail.length - _ZipSignatures.eocdSize;
        offset >= 0;
        offset -= 1) {
      if (data.getUint32(offset, Endian.little) != _ZipSignatures.eocdSignature) {
        continue;
      }
      final commentLength =
          data.getUint16(offset + 20, Endian.little);
      final expectedLength = offset + _ZipSignatures.eocdSize + commentLength;
      if (expectedLength == tail.length) {
        return offset;
      }
    }
    return -1;
  }

  Future<_Zip64EndOfCentralDirectory> _readZip64EndOfCentralDirectory(
    RandomAccessFile raf,
    int eocdOffset,
  ) async {
    final locatorOffset = eocdOffset - _ZipSignatures.zip64LocatorSize;
    if (locatorOffset < 0) {
      throw UnsupportedError('ZIP64 locator missing: $archivePath');
    }

    await raf.setPosition(locatorOffset);
    final locatorBytes = await raf.read(_ZipSignatures.zip64LocatorSize);
    final locator = ByteData.sublistView(locatorBytes);
    final locatorSignature = locator.getUint32(0, Endian.little);
    if (locatorSignature != _ZipSignatures.zip64LocatorSignature) {
      throw UnsupportedError('ZIP64 locator signature missing: $archivePath');
    }

    final diskWithRecord = locator.getUint32(4, Endian.little);
    final recordOffset = locator.getUint64(8, Endian.little);
    final totalDisks = locator.getUint32(16, Endian.little);
    if (diskWithRecord != 0 || totalDisks != 1) {
      throw UnsupportedError(
        'Multi-disk ZIP64 archives are not supported: $archivePath',
      );
    }

    await raf.setPosition(recordOffset);
    final headerBytes = await raf.read(_ZipSignatures.zip64EocdMinSize);
    final record = ByteData.sublistView(headerBytes);
    if (record.getUint32(0, Endian.little) !=
        _ZipSignatures.zip64EocdSignature) {
      throw UnsupportedError('ZIP64 EOCD signature missing: $archivePath');
    }

    final sizeOfRecord = record.getUint64(4, Endian.little);
    if (sizeOfRecord + 12 > _ZipSignatures.zip64EocdMinSize) {
      await raf.setPosition(recordOffset);
      final fullBytes = await raf.read(sizeOfRecord.toInt() + 12);
      final fullRecord = ByteData.sublistView(fullBytes);
      return _parseZip64Record(fullRecord);
    }
    return _parseZip64Record(record);
  }

  _Zip64EndOfCentralDirectory _parseZip64Record(ByteData record) {
    final diskNumber = record.getUint32(16, Endian.little);
    final startDisk = record.getUint32(20, Endian.little);
    if (diskNumber != 0 || startDisk != 0) {
      throw UnsupportedError(
        'Multi-disk ZIP64 archives are not supported: $archivePath',
      );
    }

    return _Zip64EndOfCentralDirectory(
      entriesOnDisk: record.getUint64(24, Endian.little).toInt(),
      totalEntries: record.getUint64(32, Endian.little).toInt(),
      centralDirectorySize: record.getUint64(40, Endian.little).toInt(),
      centralDirectoryOffset: record.getUint64(48, Endian.little).toInt(),
    );
  }

  Future<List<_CentralDirectoryRecord>> _readCentralDirectoryRecords(
    RandomAccessFile raf,
    int offset,
    int size,
  ) async {
    await raf.setPosition(offset);
    final bytes = await raf.read(size);
    if (bytes.length != size) {
      throw StateError('Failed to read central directory from $archivePath');
    }

    final records = <_CentralDirectoryRecord>[];
    var cursor = 0;
    final data = ByteData.sublistView(bytes);
    while (cursor + _ZipSignatures.centralDirectoryHeaderSize <= bytes.length) {
      final signature = data.getUint32(cursor, Endian.little);
      if (signature != _ZipSignatures.centralDirectoryHeaderSignature) {
        break;
      }

      final flags = data.getUint16(cursor + 8, Endian.little);
      final compressionMethod = data.getUint16(cursor + 10, Endian.little);
      final compressedSize = data.getUint32(cursor + 20, Endian.little);
      final uncompressedSize = data.getUint32(cursor + 24, Endian.little);
      final fileNameLength = data.getUint16(cursor + 28, Endian.little);
      final extraFieldLength = data.getUint16(cursor + 30, Endian.little);
      final fileCommentLength = data.getUint16(cursor + 32, Endian.little);
      final diskStart = data.getUint16(cursor + 34, Endian.little);
      final localHeaderOffset = data.getUint32(cursor + 42, Endian.little);

      final fixedEnd = cursor + _ZipSignatures.centralDirectoryHeaderSize;
      final fileNameBytes =
          bytes.sublist(fixedEnd, fixedEnd + fileNameLength);
      final extraStart = fixedEnd + fileNameLength;
      final extraEnd = extraStart + extraFieldLength;
      final extraBytes = bytes.sublist(extraStart, extraEnd);

      var resolvedCompressedSize = compressedSize;
      var resolvedUncompressedSize = uncompressedSize;
      var resolvedLocalHeaderOffset = localHeaderOffset;

      if (diskStart != 0) {
        throw UnsupportedError(
          'Multi-disk ZIP archives are not supported: $archivePath',
        );
      }

      if (compressedSize == 0xffffffff ||
          uncompressedSize == 0xffffffff ||
          localHeaderOffset == 0xffffffff) {
        final zip64 = _readZip64Extra(extraBytes);
        if (uncompressedSize == 0xffffffff) {
          resolvedUncompressedSize = zip64.readUint64();
        }
        if (compressedSize == 0xffffffff) {
          resolvedCompressedSize = zip64.readUint64();
        }
        if (localHeaderOffset == 0xffffffff) {
          resolvedLocalHeaderOffset = zip64.readUint64();
        }
      }

      final decodedPath = _decodePath(fileNameBytes, flags);
      final normalizedPath = PathUtils.normalizeRelative(decodedPath);
      final isDirectory = decodedPath.endsWith('/');

      records.add(
        _CentralDirectoryRecord(
          path: normalizedPath,
          compressionMethod: compressionMethod,
          compressedSize: resolvedCompressedSize,
          uncompressedSize: resolvedUncompressedSize,
          localHeaderOffset: resolvedLocalHeaderOffset,
          flags: flags,
          isDirectory: isDirectory,
        ),
      );

      cursor = extraEnd + fileCommentLength;
    }
    return records;
  }

  _Zip64ExtraReader _readZip64Extra(List<int> extraBytes) {
    var cursor = 0;
    final data = ByteData.sublistView(Uint8List.fromList(extraBytes));
    while (cursor + 4 <= extraBytes.length) {
      final headerId = data.getUint16(cursor, Endian.little);
      final dataSize = data.getUint16(cursor + 2, Endian.little);
      final dataStart = cursor + 4;
      final dataEnd = dataStart + dataSize;
      if (dataEnd > extraBytes.length) {
        break;
      }
      if (headerId == _ZipSignatures.zip64ExtraFieldId) {
        return _Zip64ExtraReader(
          ByteData.sublistView(
            Uint8List.fromList(extraBytes.sublist(dataStart, dataEnd)),
          ),
        );
      }
      cursor = dataEnd;
    }
    throw UnsupportedError('ZIP64 extra field missing: $archivePath');
  }

  Future<int> _readLocalFileDataOffset(
    RandomAccessFile raf,
    int localHeaderOffset,
  ) async {
    await raf.setPosition(localHeaderOffset);
    final headerBytes = await raf.read(_ZipSignatures.localFileHeaderSize);
    if (headerBytes.length != _ZipSignatures.localFileHeaderSize) {
      throw StateError('Failed to read local file header from $archivePath');
    }
    final data = ByteData.sublistView(headerBytes);
    final signature = data.getUint32(0, Endian.little);
    if (signature != _ZipSignatures.localFileHeaderSignature) {
      throw StateError('Invalid local file header in $archivePath');
    }
    final fileNameLength = data.getUint16(26, Endian.little);
    final extraFieldLength = data.getUint16(28, Endian.little);
    return localHeaderOffset +
        _ZipSignatures.localFileHeaderSize +
        fileNameLength +
        extraFieldLength;
  }

  String _decodePath(List<int> fileNameBytes, int flags) {
    if ((flags & _ZipSignatures.utf8Flag) != 0) {
      return const Utf8Decoder(allowMalformed: true).convert(fileNameBytes);
    }
    try {
      return const Utf8Decoder(allowMalformed: true).convert(fileNameBytes);
    } catch (_) {
      return latin1.decode(fileNameBytes, allowInvalid: true);
    }
  }
}

class _LazyZipEntry {
  const _LazyZipEntry({
    required this.path,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.dataOffset,
    required this.flags,
  });

  final String path;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final int dataOffset;
  final int flags;

  bool get isEncrypted => (flags & 0x0001) != 0;
}

class _CentralDirectoryRecord {
  const _CentralDirectoryRecord({
    required this.path,
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.flags,
    required this.isDirectory,
  });

  final String path;
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;
  final int flags;
  final bool isDirectory;
}

class _EndOfCentralDirectory {
  const _EndOfCentralDirectory({
    required this.entriesOnDisk,
    required this.totalEntries,
    required this.centralDirectorySize,
    required this.centralDirectoryOffset,
  });

  final int entriesOnDisk;
  final int totalEntries;
  final int centralDirectorySize;
  final int centralDirectoryOffset;
}

class _Zip64EndOfCentralDirectory {
  const _Zip64EndOfCentralDirectory({
    required this.entriesOnDisk,
    required this.totalEntries,
    required this.centralDirectorySize,
    required this.centralDirectoryOffset,
  });

  final int entriesOnDisk;
  final int totalEntries;
  final int centralDirectorySize;
  final int centralDirectoryOffset;
}

class _Zip64ExtraReader {
  _Zip64ExtraReader(this.data);

  final ByteData data;
  int _offset = 0;

  int readUint64() {
    final value = data.getUint64(_offset, Endian.little).toInt();
    _offset += 8;
    return value;
  }
}

class _ZipSignatures {
  static const int eocdSignature = 0x06054b50;
  static const int eocdSize = 22;
  static const int zip64LocatorSignature = 0x07064b50;
  static const int zip64LocatorSize = 20;
  static const int zip64EocdSignature = 0x06064b50;
  static const int zip64EocdMinSize = 56;
  static const int centralDirectoryHeaderSignature = 0x02014b50;
  static const int centralDirectoryHeaderSize = 46;
  static const int localFileHeaderSignature = 0x04034b50;
  static const int localFileHeaderSize = 30;
  static const int maxEocdSearch = 65535 + eocdSize + zip64LocatorSize;
  static const int zip64ExtraFieldId = 0x0001;
  static const int utf8Flag = 0x0800;
  static const int storeMethod = 0;
  static const int deflateMethod = 8;
}
