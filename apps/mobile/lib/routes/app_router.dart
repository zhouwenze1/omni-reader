import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/library/pages/library_page.dart';
import '../features/reader/pages/reader_page.dart';
import 'route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: RoutePaths.library,
        builder: (context, state) => const LibraryPage(),
      ),
      GoRoute(
        path: RoutePaths.readerPattern,
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          return ReaderPage(bookUid: uid);
        },
      ),
    ],
  );
});
