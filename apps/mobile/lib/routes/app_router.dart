import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_application/application.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return buildReaderAppRouter(
    pages: ReaderAppRouterPages(
      homeShellBuilder: (context, navigationShell) {
        return HomeShellPage(navigationShell: navigationShell);
      },
      readingNowBuilder: (context) => const ReadingNowPage(),
      libraryBuilder: (context) => const LibraryPage(),
      meBuilder: (context) => const MePage(),
      readerBuilder: (context, uid) => ReaderPage(bookUid: uid),
      tocBuilder: (context, uid) => TocDrawerPage(bookUid: uid),
      searchInBookBuilder: (context, uid) => SearchInBookPage(bookUid: uid),
      settingsHomeBuilder: (context) => const SettingsHomePage(),
      appSettingsBuilder: (context) => const AppSettingsPage(),
      readerSettingsBuilder: (context) => const ReaderGlobalSettingsPage(),
      cloudSettingsBuilder: (context) => const CloudSettingsPage(),
      aboutBuilder: (context) => const AboutPage(),
    ),
  );
});
