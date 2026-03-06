import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:foundation_domain/domain.dart';

import 'app_database.dart';

class LibraryIndexDao {
  LibraryIndexDao(this._db);

  final AppDatabase _db;

  Future<List<LibraryIndexEntry>> listAll() async {
    return query(
      sortMode: LibrarySortMode.recentRead,
      filters: const LibraryFilters(),
    );
  }

  Future<List<LibraryIndexEntry>> query({
    required LibrarySortMode sortMode,
    required LibraryFilters filters,
  }) async {
    final where = <String>[];
    final variables = <Variable<Object>>[];

    if (filters.hasFormatFilter) {
      final formats = filters.formats.map((it) => it.toLowerCase()).toList()
        ..sort();
      if (formats.isNotEmpty) {
        where.add(
          'LOWER(format) IN (${List<String>.filled(formats.length, '?').join(', ')})',
        );
        for (final format in formats) {
          variables.add(Variable.withString(format));
        }
      }
    }

    if (filters.hasCategoryFilter) {
      final categoryIds = filters.categoryIds.toList()..sort();
      where.add(
        'categoryId IN (${List<String>.filled(categoryIds.length, '?').join(', ')})',
      );
      for (final categoryId in categoryIds) {
        variables.add(Variable.withString(categoryId));
      }
    }

    switch (filters.progress) {
      case LibraryProgressBucket.all:
        break;
      case LibraryProgressBucket.notStarted:
        where.add('COALESCE(cachedProgress, 0) <= 0.0001');
        break;
      case LibraryProgressBucket.inProgress:
        where.add('COALESCE(cachedProgress, 0) > 0.0001');
        where.add('COALESCE(cachedProgress, 0) < 0.9999');
        break;
      case LibraryProgressBucket.completed:
        where.add('COALESCE(cachedProgress, 0) >= 0.9999');
        break;
    }

    final orderBy = switch (sortMode) {
      LibrarySortMode.recentRead => 'COALESCE(lastOpenedAt, updatedAt) DESC',
      LibrarySortMode.importedAt => 'importedAt DESC',
      LibrarySortMode.name => 'LOWER(title) ASC',
    };

    final whereSql = where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}';
    final sql = 'SELECT * FROM library_index$whereSql ORDER BY $orderBy';
    final rows = await _db.customSelect(sql, variables: variables).get();
    return rows.map(_mapEntry).toList();
  }

  Future<LibraryIndexEntry?> findByFingerprint(String fingerprint) async {
    final rows = await _db.customSelect(
      'SELECT * FROM library_index WHERE fingerprint = ? LIMIT 1',
      variables: [Variable.withString(fingerprint)],
    ).get();

    if (rows.isEmpty) {
      return null;
    }
    return _mapEntry(rows.first);
  }

  Future<void> upsert(LibraryIndexEntry entry) async {
    final authorsJson = jsonEncode(entry.authors);
    await _db.customStatement(
      '''
      INSERT INTO library_index (
        bookUid, fingerprint, format, title, authorsJson, categoryId, coverRelPath,
        importedAt, updatedAt, lastOpenedAt, cachedProgress
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(bookUid) DO UPDATE SET
        fingerprint=excluded.fingerprint,
        format=excluded.format,
        title=excluded.title,
        authorsJson=excluded.authorsJson,
        categoryId=excluded.categoryId,
        coverRelPath=excluded.coverRelPath,
        importedAt=excluded.importedAt,
        updatedAt=excluded.updatedAt,
        lastOpenedAt=excluded.lastOpenedAt,
        cachedProgress=excluded.cachedProgress
      ''',
      [
        entry.bookUid,
        entry.fingerprint,
        entry.format,
        entry.title,
        authorsJson,
        entry.categoryId,
        entry.coverRelPath,
        entry.importedAt.millisecondsSinceEpoch,
        entry.updatedAt.millisecondsSinceEpoch,
        entry.lastOpenedAt?.millisecondsSinceEpoch,
        entry.cachedProgress,
      ],
    );
  }

  Future<void> updateCachedProgress(String bookUid, double progression) async {
    await _db.customStatement(
      'UPDATE library_index SET cachedProgress = ?, updatedAt = ? WHERE bookUid = ?',
      [progression, DateTime.now().millisecondsSinceEpoch, bookUid],
    );
  }

  Future<void> deleteByBookUid(String bookUid) {
    return _db.customStatement(
      'DELETE FROM library_index WHERE bookUid = ?',
      [bookUid],
    );
  }

  LibraryIndexEntry _mapEntry(QueryRow row) {
    final authors =
        (jsonDecode(row.data['authorsJson'] as String) as List<dynamic>)
            .map((it) => '$it')
            .toList();

    return LibraryIndexEntry(
      bookUid: row.data['bookUid'] as String,
      fingerprint: row.data['fingerprint'] as String,
      format: row.data['format'] as String,
      title: row.data['title'] as String,
      authors: authors,
      categoryId: row.data['categoryId'] as String?,
      coverRelPath: row.data['coverRelPath'] as String?,
      importedAt: DateTime.fromMillisecondsSinceEpoch(
        (row.data['importedAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row.data['updatedAt'] as num).toInt(),
      ),
      lastOpenedAt: row.data['lastOpenedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (row.data['lastOpenedAt'] as num).toInt(),
            ),
      cachedProgress: (row.data['cachedProgress'] as num?)?.toDouble(),
    );
  }
}
