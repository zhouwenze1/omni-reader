import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:services_search/services_search.dart';
import 'providers.dart';
import 'repositories_providers.dart';

final importServiceProvider = Provider((ref) {
  return ref.watch(importRepositoryProvider);
});

final bookSearchServiceProvider = Provider<BookSearchService>((ref) {
  return BookSearchService(
    booksRootPath: ref.watch(dataModuleProvider).storagePaths.booksRoot.path,
  );
});
