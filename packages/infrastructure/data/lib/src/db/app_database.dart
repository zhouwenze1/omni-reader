import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase._(QueryExecutor executor) : super(executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await _migrate();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          await _migrate();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  static Future<AppDatabase> open(String dbPath) async {
    final file = File(dbPath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    return AppDatabase._(NativeDatabase(file));
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
        categoryId TEXT NULL,
        coverRelPath TEXT NULL,
        importedAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        lastOpenedAt INTEGER NULL,
        cachedProgress REAL NULL
      );
    ''');

    if (!await _hasColumn('library_index', 'categoryId')) {
      await customStatement(
        'ALTER TABLE library_index ADD COLUMN categoryId TEXT NULL;',
      );
    }

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

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table);').get();
    for (final row in rows) {
      final name = row.data['name']?.toString();
      if (name == column) {
        return true;
      }
    }
    return false;
  }

  Future<void> close() => executor.close();
}
