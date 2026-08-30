import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_data/data.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('app_database_test_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  Future<List<String>> tableNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    return rows.map((row) => row.data['name'].toString()).toList();
  }

  Future<List<String>> columnNames(
    AppDatabase db,
    String table,
  ) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((row) => row.data['name'].toString()).toList();
  }

  Future<int> userVersion(AppDatabase db) async {
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    return int.parse(row.data['user_version'].toString());
  }

  test('fresh database is created at schema v4 with all tables and columns',
      () async {
    final db = await AppDatabase.open(
      '${tempRoot.path}${Platform.pathSeparator}fresh.sqlite',
    );
    addTearDown(db.close);

    final tables = await tableNames(db);
    expect(tables, containsAll(<String>['library_index', 'collections']));
    expect(tables, contains('reading_sessions'));
    // sqlite 自动表
    expect(tables, isNot(contains('android_metadata')));

    final columns = await columnNames(db, 'library_index');
    expect(columns, contains('categoryId'));
    final sessionColumns = await columnNames(db, 'reading_sessions');
    expect(
      sessionColumns,
      containsAll(<String>[
        'id',
        'bookUid',
        'startedAt',
        'endedAt',
        'seconds',
        'day',
        'startHour',
      ]),
    );
    expect(await userVersion(db), 4);
  });

  test('legacy v1 database upgrades through stepwise migrations to v3',
      () async {
    final dbPath = '${tempRoot.path}${Platform.pathSeparator}legacy.sqlite';

    // 构造 v1 形态的旧库:library_index 没有 categoryId,没有书桌表。
    final legacy = sqlite3.open(dbPath);
    legacy.execute('''
      CREATE TABLE library_index (
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
    legacy.execute(
      "INSERT INTO library_index VALUES ('b1', 'fp1', 'epub', 'Old Book', "
      "'[]', NULL, 1, 1, NULL, NULL);",
    );
    legacy.execute('PRAGMA user_version = 1;');
    legacy.dispose();

    final db = await AppDatabase.open(dbPath);
    addTearDown(db.close);

    final tables = await tableNames(db);
    expect(tables, containsAll(<String>['collections', 'collection_items']));
    expect(tables, contains('reading_sessions'));

    final columns = await columnNames(db, 'library_index');
    expect(columns, contains('categoryId'));

    expect(await userVersion(db), 4);

    // 旧数据在升级后仍然可读。
    final row = await db
        .customSelect("SELECT title FROM library_index WHERE bookUid = 'b1'")
        .getSingle();
    expect(row.data['title'], 'Old Book');
  });

  test('v3 database upgrades to v4 and keeps existing rows intact',
      () async {
    final dbPath = '${tempRoot.path}${Platform.pathSeparator}v3.sqlite';

    // 构造 v3 形态的旧库:含 categoryId 与书桌表,但没有 reading_sessions。
    final legacy = sqlite3.open(dbPath);
    legacy.execute('''
      CREATE TABLE library_index (
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
    legacy.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');
    legacy.execute(
      "INSERT INTO library_index VALUES ('b3', 'fp3', 'epub', 'V3 Book', "
      "'[]', NULL, NULL, 1, 1, NULL, 0.5);",
    );
    legacy.execute('PRAGMA user_version = 3;');
    legacy.dispose();

    final db = await AppDatabase.open(dbPath);
    addTearDown(db.close);

    expect(
      await columnNames(db, 'reading_sessions'),
      containsAll(<String>['day', 'startHour', 'seconds']),
    );
    expect(await userVersion(db), 4);

    final row = await db
        .customSelect("SELECT title, cachedProgress FROM library_index WHERE bookUid = 'b3'")
        .getSingle();
    expect(row.data['title'], 'V3 Book');
    expect((row.data['cachedProgress'] as num).toDouble(), 0.5);
  });
}
