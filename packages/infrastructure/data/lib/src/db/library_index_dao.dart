import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:foundation_domain/domain.dart';

import 'app_database.dart';

class LibraryIndexDao {
  LibraryIndexDao(this._db);

  final AppDatabase _db;

  Future<List<LibraryIndexEntry>> listAll() async {
    final rows = await _db
        .customSelect('SELECT * FROM library_index ORDER BY updatedAt DESC')
        .get();

    return rows.map(_mapEntry).toList();
  }

  Future<LibraryIndexEntry?> findByFingerprint(String fingerprint) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM library_index WHERE fingerprint = ? LIMIT 1',
          variables: [Variable.withString(fingerprint)],
        )
        .get();

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
        bookUid, fingerprint, format, title, authorsJson, coverRelPath,
        importedAt, updatedAt, lastOpenedAt, cachedProgress
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(bookUid) DO UPDATE SET
        fingerprint=excluded.fingerprint,
        format=excluded.format,
        title=excluded.title,
        authorsJson=excluded.authorsJson,
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
