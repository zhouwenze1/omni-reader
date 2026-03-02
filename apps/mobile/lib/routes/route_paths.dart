class RoutePaths {
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

  static String reader(String uid) => '/reader/$uid';
  static String toc(String uid) => '/reader/$uid/toc';
  static String searchInBook(String uid) => '/reader/$uid/search';
}
