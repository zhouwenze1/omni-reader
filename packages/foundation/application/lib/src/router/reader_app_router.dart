import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class ReaderRoutePaths {
  static const String readingNow = '/reading-now';
  static const String library = '/library';
  static const String me = '/me';

  static const String readerPattern = '/reader/:uid';
  static const String tocPattern = '/reader/:uid/toc';
  static const String searchInBookPattern = '/reader/:uid/search';

  static const String settingsHome = '/settings';
  static const String appSettings = '/settings/app';
  static const String readerSettings = '/settings/reader';
  static const String cloudSettings = '/settings/cloud';
  static const String about = '/settings/about';
  static const String stats = '/stats';

  static String reader(String uid) => '/reader/$uid';
  static String toc(String uid) => '/reader/$uid/toc';
  static String searchInBook(String uid) => '/reader/$uid/search';
}

typedef NavigationShellBuilder = Widget Function(
  BuildContext context,
  StatefulNavigationShell navigationShell,
);
typedef PageBuilder = Widget Function(BuildContext context);
typedef UidPageBuilder = Widget Function(BuildContext context, String uid);

class ReaderAppRouterPages {
  const ReaderAppRouterPages({
    required this.homeShellBuilder,
    required this.readingNowBuilder,
    required this.libraryBuilder,
    required this.meBuilder,
    required this.readerBuilder,
    required this.tocBuilder,
    required this.searchInBookBuilder,
    required this.settingsHomeBuilder,
    required this.appSettingsBuilder,
    required this.readerSettingsBuilder,
    required this.cloudSettingsBuilder,
    required this.aboutBuilder,
    required this.statsBuilder,
  });

  final NavigationShellBuilder homeShellBuilder;
  final PageBuilder readingNowBuilder;
  final PageBuilder libraryBuilder;
  final PageBuilder meBuilder;
  final UidPageBuilder readerBuilder;
  final UidPageBuilder tocBuilder;
  final UidPageBuilder searchInBookBuilder;
  final PageBuilder settingsHomeBuilder;
  final PageBuilder appSettingsBuilder;
  final PageBuilder readerSettingsBuilder;
  final PageBuilder cloudSettingsBuilder;
  final PageBuilder aboutBuilder;
  final PageBuilder statsBuilder;
}

GoRouter buildReaderAppRouter({
  required ReaderAppRouterPages pages,
  String initialLocation = ReaderRoutePaths.readingNow,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return pages.homeShellBuilder(context, navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ReaderRoutePaths.readingNow,
                builder: (context, state) => pages.readingNowBuilder(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ReaderRoutePaths.library,
                builder: (context, state) => pages.libraryBuilder(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ReaderRoutePaths.me,
                builder: (context, state) => pages.meBuilder(context),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: ReaderRoutePaths.readerPattern,
        builder: (context, state) {
          return pages.readerBuilder(context, _requiredUid(state));
        },
      ),
      GoRoute(
        path: ReaderRoutePaths.tocPattern,
        builder: (context, state) {
          return pages.tocBuilder(context, _requiredUid(state));
        },
      ),
      GoRoute(
        path: ReaderRoutePaths.searchInBookPattern,
        builder: (context, state) {
          return pages.searchInBookBuilder(context, _requiredUid(state));
        },
      ),
      GoRoute(
        path: ReaderRoutePaths.settingsHome,
        builder: (context, state) => pages.settingsHomeBuilder(context),
      ),
      GoRoute(
        path: ReaderRoutePaths.appSettings,
        builder: (context, state) => pages.appSettingsBuilder(context),
      ),
      GoRoute(
        path: ReaderRoutePaths.readerSettings,
        builder: (context, state) => pages.readerSettingsBuilder(context),
      ),
      GoRoute(
        path: ReaderRoutePaths.cloudSettings,
        builder: (context, state) => pages.cloudSettingsBuilder(context),
      ),
      GoRoute(
        path: ReaderRoutePaths.about,
        builder: (context, state) => pages.aboutBuilder(context),
      ),
      GoRoute(
        path: ReaderRoutePaths.stats,
        builder: (context, state) => pages.statsBuilder(context),
      ),
    ],
  );
}

String _requiredUid(GoRouterState state) {
  final uid = state.pathParameters['uid'];
  if (uid == null || uid.isEmpty) {
    throw StateError('Missing path parameter: uid');
  }
  return uid;
}
