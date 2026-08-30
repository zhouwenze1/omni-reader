import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Raw-SQL drift database for the reader library.
///
/// 迁移约定(2026-08 起):onCreate 直接建立当前版本 schema;onUpgrade 按
/// from→to 分步执行,每个 step 只负责自己的增量。历史版本的精确形态已不可
/// 考,因此各 step 内部保留 IF NOT EXISTS / _hasColumn 幂等防御,保证任意
/// 存量库都能安全升级。新增 schema 变更时:schemaVersion +1,并追加一个
/// step 函数,不要修改已有 step。
class AppDatabase extends GeneratedDatabase {
  AppDatabase._(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await _createLibraryIndexTable();
          await _createCollectionsTables();
          await _createReadingSessionsTable();
          await _createAllIndexes();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await _upgradeToV2();
          }
          if (from < 3) {
            await _upgradeToV3();
          }
          if (from < 4) {
            await _upgradeToV4();
          }
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

  // ---- schema v4 (current) --------------------------------------------------

  Future<void> _createLibraryIndexTable() async {
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
  }

  Future<void> _createCollectionsTables() async {
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

  Future<void> _createAllIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_library_index_format ON library_index(format);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_library_index_category ON library_index(categoryId);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_library_index_last_opened ON library_index(lastOpenedAt);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_library_index_imported ON library_index(importedAt);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_library_index_cached_progress ON library_index(cachedProgress);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_collection_items_collection ON collection_items(collectionId);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_collection_items_book ON collection_items(bookUid);',
    );
  }

  // ---- migration steps -----------------------------------------------------

  /// v2: 加入书桌(collections / collection_items)。
  Future<void> _upgradeToV2() async {
    await _createCollectionsTables();
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_collection_items_collection ON collection_items(collectionId);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_collection_items_book ON collection_items(bookUid);',
    );
  }

  /// v3: library_index 加入 categoryId(分类)。
  Future<void> _upgradeToV3() async {
    if (!await _hasColumn('library_index', 'categoryId')) {
      await customStatement(
        'ALTER TABLE library_index ADD COLUMN categoryId TEXT NULL;',
      );
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_library_index_category ON library_index(categoryId);',
    );
  }

  /// v4: reading_sessions(阅读时长会话,统计中心数据源)。
  Future<void> _upgradeToV4() async {
    await _createReadingSessionsTable();
  }

  Future<void> _createReadingSessionsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookUid TEXT NOT NULL,
        startedAt INTEGER NOT NULL,
        endedAt INTEGER NOT NULL,
        seconds INTEGER NOT NULL,
        day TEXT NOT NULL,
        startHour INTEGER NOT NULL
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_reading_sessions_day ON reading_sessions(day);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_reading_sessions_book ON reading_sessions(bookUid);',
    );
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

  @override
  Future<void> close() => executor.close();
}
