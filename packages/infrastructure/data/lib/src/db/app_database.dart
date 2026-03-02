import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase._(QueryExecutor executor) : super(executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  static Future<AppDatabase> open(String dbPath) async {
    final file = File(dbPath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    final db = AppDatabase._(NativeDatabase(file));
    await db._migrate();
    return db;
  }

  Future<void> _migrate() async {
    await customStatement('PRAGMA foreign_keys = ON;');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS library_index (
        bookUid TEXT PRIMARY KEY,
        fingerprint TEXT UNIQUE NOT NULL,
        format TEXT NOT NULL,
        title TEXT NOT NULL,
        authorsJson TEXT NOT NULL,
        coverRelPath TEXT NULL,
        importedAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        lastOpenedAt INTEGER NULL,
        cachedProgress REAL NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS collection_items (
        collectionId INTEGER NOT NULL,
        bookUid TEXT NOT NULL,
        addedAt INTEGER NOT NULL,
        PRIMARY KEY (collectionId, bookUid),
        FOREIGN KEY (collectionId) REFERENCES collections(id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> close() => executor.close();
}
