import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reader/services/book_search_service.dart';
import 'providers.dart';
import 'repositories_providers.dart';

final importServiceProvider = Provider((ref) {
  return ref.watch(importRepositoryProvider);
});

final bookSearchServiceProvider = Provider<BookSearchService>((ref) {
  return BookSearchService(
    storagePaths: ref.watch(dataModuleProvider).storagePaths,
  );
});
