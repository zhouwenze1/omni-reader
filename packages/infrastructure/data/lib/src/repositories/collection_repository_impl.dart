import 'package:foundation_domain/domain.dart';

import '../db/collection_dao.dart';

class CollectionRepositoryImpl implements CollectionRepository {
  CollectionRepositoryImpl(this._dao);

  final CollectionDao _dao;

  @override
  Future<List<Collection>> listCollections() {
    return _dao.listCollections();
  }

  @override
  Future<Collection> ensureCollection(String name) {
    return _dao.ensureCollection(name);
  }

  @override
  Future<Collection> createCollection(String name) {
    return _dao.createCollection(name);
  }

  @override
  Future<void> renameCollection(int collectionId, String name) {
    return _dao.renameCollection(collectionId, name);
  }

  @override
  Future<void> deleteCollection(int collectionId) {
    return _dao.deleteCollection(collectionId);
  }

  @override
  Future<void> addBookToCollection(int collectionId, String bookUid) {
    return _dao.addBookToCollection(collectionId, bookUid);
  }

  @override
  Future<void> removeBookFromCollection(int collectionId, String bookUid) {
    return _dao.removeBookFromCollection(collectionId, bookUid);
  }

  @override
  Future<void> removeBookFromAllCollections(String bookUid) {
    return _dao.removeBookFromAllCollections(bookUid);
  }

  @override
  Future<List<CollectionItem>> listCollectionItems(int collectionId) {
    return _dao.listCollectionItems(collectionId);
  }

  @override
  Future<Map<int, Set<String>>> listCollectionBookUids() {
    return _dao.listCollectionBookUids();
  }
}
