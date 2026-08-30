import 'package:drift/drift.dart';
import 'package:foundation_domain/domain.dart';

import 'app_database.dart';

class CollectionDao {
  CollectionDao(this._db);

  final AppDatabase _db;

  Future<List<Collection>> listCollections() async {
    final rows = await _db
        .customSelect('SELECT * FROM collections ORDER BY updatedAt DESC')
        .get();

    return rows
        .map(
          (row) => Collection(
            id: (row.data['id'] as num).toInt(),
            name: row.data['name'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (row.data['createdAt'] as num).toInt(),
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              (row.data['updatedAt'] as num).toInt(),
            ),
          ),
        )
        .toList();
  }

  Future<Collection?> findCollectionByName(String name) async {
    final normalized = _normalizeName(name);
    if (normalized.isEmpty) {
      return null;
    }

    final rows = await _db.customSelect(
      '''
      SELECT * FROM collections
      WHERE lower(trim(name)) = ?
      ORDER BY updatedAt DESC, id DESC
      LIMIT 1
      ''',
      variables: [Variable.withString(normalized.toLowerCase())],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    return _mapCollection(rows.first.data);
  }

  Future<Collection> ensureCollection(String name) async {
    final existing = await findCollectionByName(name);
    if (existing != null) {
      return existing;
    }
    return createCollection(name);
  }

  Future<Collection> createCollection(String name) async {
    final normalized = _normalizeName(name);
    if (normalized.isEmpty) {
      throw StateError('Collection name cannot be empty');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT INTO collections (name, createdAt, updatedAt) VALUES (?, ?, ?)',
      [normalized, now, now],
    );

    final idRow =
        await _db.customSelect('SELECT last_insert_rowid() AS id').getSingle();
    final id = (idRow.data['id'] as num).toInt();

    return Collection(
      id: id,
      name: normalized,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> renameCollection(int id, String name) async {
    final normalized = _normalizeName(name);
    if (normalized.isEmpty) {
      throw StateError('Collection name cannot be empty');
    }

    final existing = await findCollectionByName(normalized);
    if (existing != null && existing.id != id) {
      throw StateError('Collection name already exists');
    }

    await _db.customStatement(
      'UPDATE collections SET name = ?, updatedAt = ? WHERE id = ?',
      [normalized, DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<void> deleteCollection(int id) {
    return _db.customStatement('DELETE FROM collections WHERE id = ?', [id]);
  }

  Future<void> addBookToCollection(int collectionId, String bookUid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      '''
      INSERT OR REPLACE INTO collection_items (collectionId, bookUid, addedAt)
      VALUES (?, ?, ?)
      ''',
      [collectionId, bookUid, now],
    );
    await _touchCollection(collectionId, now);
  }

  Future<void> removeBookFromCollection(
      int collectionId, String bookUid) async {
    await _db.customStatement(
      'DELETE FROM collection_items WHERE collectionId = ? AND bookUid = ?',
      [collectionId, bookUid],
    );
    await _touchCollection(collectionId);
  }

  Future<void> removeBookFromAllCollections(String bookUid) async {
    final collectionIds = await listCollectionIdsForBook(bookUid);
    await _db.customStatement(
      'DELETE FROM collection_items WHERE bookUid = ?',
      [bookUid],
    );
    for (final collectionId in collectionIds) {
      await _touchCollection(collectionId);
    }
  }

  Future<List<CollectionItem>> listCollectionItems(int collectionId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM collection_items WHERE collectionId = ? ORDER BY addedAt DESC',
      variables: [Variable.withInt(collectionId)],
    ).get();

    return rows
        .map(
          (row) => CollectionItem(
            collectionId: (row.data['collectionId'] as num).toInt(),
            bookUid: row.data['bookUid'] as String,
            addedAt: DateTime.fromMillisecondsSinceEpoch(
              (row.data['addedAt'] as num).toInt(),
            ),
          ),
        )
        .toList();
  }

  Future<List<int>> listCollectionIdsForBook(String bookUid) async {
    final rows = await _db.customSelect(
      'SELECT collectionId FROM collection_items WHERE bookUid = ?',
      variables: [Variable.withString(bookUid)],
    ).get();

    return rows
        .map((row) => (row.data['collectionId'] as num).toInt())
        .toList();
  }

  Future<Map<int, Set<String>>> listCollectionBookUids() async {
    final rows = await _db
        .customSelect(
          'SELECT collectionId, bookUid FROM collection_items',
        )
        .get();

    final result = <int, Set<String>>{};
    for (final row in rows) {
      final collectionId = (row.data['collectionId'] as num).toInt();
      final bookUid = row.data['bookUid'] as String;
      result.putIfAbsent(collectionId, () => <String>{}).add(bookUid);
    }
    return result;
  }

  Collection _mapCollection(Map<String, dynamic> data) {
    return Collection(
      id: (data['id'] as num).toInt(),
      name: data['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAt'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (data['updatedAt'] as num).toInt(),
      ),
    );
  }

  String _normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _touchCollection(int collectionId, [int? now]) {
    return _db.customStatement(
      'UPDATE collections SET updatedAt = ? WHERE id = ?',
      [now ?? DateTime.now().millisecondsSinceEpoch, collectionId],
    );
  }
}
