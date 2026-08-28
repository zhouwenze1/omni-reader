import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:services_search/services_search.dart';

import 'providers.dart';

final bookSearchServiceProvider = Provider<BookSearchService>((ref) {
  return BookSearchService(
    booksRootPath: ref.watch(dataModuleProvider).storagePaths.booksRoot.path,
  );
});
