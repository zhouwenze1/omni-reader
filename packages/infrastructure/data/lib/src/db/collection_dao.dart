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

  Future<Collection> createCollection(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT INTO collections (name, createdAt, updatedAt) VALUES (?, ?, ?)',
      [name, now, now],
    );

    final idRow = await _db
        .customSelect('SELECT last_insert_rowid() AS id')
        .getSingle();
    final id = (idRow.data['id'] as num).toInt();

    return Collection(
      id: id,
      name: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> renameCollection(int id, String name) {
    return _db.customStatement(
      'UPDATE collections SET name = ?, updatedAt = ? WHERE id = ?',
      [name, DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<void> deleteCollection(int id) {
    return _db.customStatement('DELETE FROM collections WHERE id = ?', [id]);
  }

  Future<void> addBookToCollection(int collectionId, String bookUid) {
    return _db.customStatement(
      '''
      INSERT OR REPLACE INTO collection_items (collectionId, bookUid, addedAt)
      VALUES (?, ?, ?)
      ''',
      [collectionId, bookUid, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<void> removeBookFromCollection(int collectionId, String bookUid) {
    return _db.customStatement(
      'DELETE FROM collection_items WHERE collectionId = ? AND bookUid = ?',
      [collectionId, bookUid],
    );
  }

  Future<List<CollectionItem>> listCollectionItems(int collectionId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM collection_items WHERE collectionId = ? ORDER BY addedAt DESC',
          variables: [Variable.withInt(collectionId)],
        )
        .get();

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
}
