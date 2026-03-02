import '../../models/book.dart';
import '../../models/library_index_entry.dart';

abstract class BookRepository {
  Future<Book?> getBook(String bookUid);

  Future<void> saveBook(Book book);

  Future<List<Book>> listBooks();

  Future<List<LibraryIndexEntry>> listLibraryIndex();

  Future<LibraryIndexEntry?> findLibraryIndexByFingerprint(String fingerprint);

  Future<void> upsertLibraryIndex(LibraryIndexEntry entry);
}
