import '../../models/collection.dart';

abstract class CollectionRepository {
  Future<List<Collection>> listCollections();

  Future<Collection> ensureCollection(String name);

  Future<Collection> createCollection(String name);

  Future<void> renameCollection(int collectionId, String name);

  Future<void> deleteCollection(int collectionId);

  Future<void> addBookToCollection(int collectionId, String bookUid);

  Future<void> removeBookFromCollection(int collectionId, String bookUid);

  Future<void> removeBookFromAllCollections(String bookUid);

  Future<List<CollectionItem>> listCollectionItems(int collectionId);

  Future<Map<int, Set<String>>> listCollectionBookUids();
}
