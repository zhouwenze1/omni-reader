import '../../models/book.dart';
import '../../models/library_index_entry.dart';
import '../../models/library_query.dart';

abstract class BookRepository {
  Future<Book?> getBook(String bookUid);

  Future<void> saveBook(Book book);

  Future<List<Book>> listBooks();

  Future<List<LibraryIndexEntry>> listLibraryIndex({
    LibrarySortMode sortMode = LibrarySortMode.recentRead,
    LibraryFilters filters = const LibraryFilters(),
  });

  Future<LibraryIndexEntry?> findLibraryIndexByFingerprint(String fingerprint);

  Future<void> upsertLibraryIndex(LibraryIndexEntry entry);

  Future<void> deleteBook(String bookUid);
}
