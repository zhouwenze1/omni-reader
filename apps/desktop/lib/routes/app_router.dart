import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_shell_page.dart';
import '../features/library/pages/library_page.dart';
import '../features/me/pages/me_page.dart';
import '../features/reader/pages/reader_page.dart';
import '../features/reader/pages/search_in_book_page.dart';
import '../features/reader/pages/toc_drawer_page.dart';
import '../features/reading_now/pages/reading_now_page.dart';
import '../features/settings/pages/about_page.dart';
import '../features/settings/pages/app_settings_page.dart';
import '../features/settings/pages/cloud_settings_page.dart';
import '../features/settings/pages/reader_global_settings_page.dart';
import '../features/settings/pages/settings_home_page.dart';
import 'route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.readingNow,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShellPage(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.readingNow,
                builder: (context, state) => const ReadingNowPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.library,
                builder: (context, state) => const LibraryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.me,
                builder: (context, state) => const MePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.readerPattern,
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          return ReaderPage(bookUid: uid);
        },
      ),
      GoRoute(
        path: RoutePaths.tocPattern,
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          return TocDrawerPage(bookUid: uid);
        },
      ),
      GoRoute(
        path: RoutePaths.searchInBookPattern,
        builder: (context, state) {
          final uid = state.pathParameters['uid']!;
          return SearchInBookPage(bookUid: uid);
        },
      ),
      GoRoute(
        path: RoutePaths.settingsHome,
        builder: (context, state) => const SettingsHomePage(),
      ),
      GoRoute(
        path: RoutePaths.appSettings,
        builder: (context, state) => const AppSettingsPage(),
      ),
      GoRoute(
        path: RoutePaths.readerSettings,
        builder: (context, state) => const ReaderGlobalSettingsPage(),
      ),
      GoRoute(
        path: RoutePaths.cloudSettings,
        builder: (context, state) => const CloudSettingsPage(),
      ),
      GoRoute(
        path: RoutePaths.about,
        builder: (context, state) => const AboutPage(),
      ),
    ],
  );
});
