import '../../models/toc_item.dart';

abstract class TocRepository {
  Future<List<TocItem>> getToc(String bookUid);

  Future<void> saveToc(String bookUid, List<TocItem> toc);
}
