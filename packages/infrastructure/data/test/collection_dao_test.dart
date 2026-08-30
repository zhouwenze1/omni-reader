import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure_data/src/db/app_database.dart';
import 'package:infrastructure_data/src/db/collection_dao.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late CollectionDao dao;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('collection_dao_test_');
    db = await AppDatabase.open(
      '${tempRoot.path}${Platform.pathSeparator}test.sqlite',
    );
    dao = CollectionDao(db);
  });

  tearDown(() async {
    await db.close();
    await tempRoot.delete(recursive: true);
  });

  test('supports multiple collections and keeps books after collection delete',
      () async {
    final first = await dao.ensureCollection('First');
    final second = await dao.ensureCollection('Second');

    await dao.addBookToCollection(first.id, 'book-1');
    await dao.addBookToCollection(second.id, 'book-1');

    final memberships = await dao.listCollectionBookUids();
    expect(memberships[first.id], contains('book-1'));
    expect(memberships[second.id], contains('book-1'));

    await dao.deleteCollection(first.id);
    final remaining = await dao.listCollectionBookUids();
    expect(remaining[first.id], isNull);
    expect(remaining[second.id], contains('book-1'));
  });

  test('rejects duplicate names when renaming', () async {
    final first = await dao.ensureCollection('First');
    final second = await dao.ensureCollection('Second');

    await expectLater(
      dao.renameCollection(second.id, ' first '),
      throwsA(isA<StateError>()),
    );
    expect((await dao.findCollectionByName('Second'))?.id, second.id);
    expect((await dao.findCollectionByName('First'))?.id, first.id);
  });
}
