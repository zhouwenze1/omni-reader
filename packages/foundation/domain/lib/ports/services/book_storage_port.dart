abstract class BookStoragePort {
  String bookDirPath(String bookUuid);

  Future<void> clearBook(String bookUuid);
}
