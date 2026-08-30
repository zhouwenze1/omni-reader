import 'package:foundation_application/application.dart';

class RoutePaths {
  static const String readingNow = ReaderRoutePaths.readingNow;
  static const String library = ReaderRoutePaths.library;
  static const String me = ReaderRoutePaths.me;

  static const String readerPattern = ReaderRoutePaths.readerPattern;
  static const String tocPattern = ReaderRoutePaths.tocPattern;
  static const String searchInBookPattern =
      ReaderRoutePaths.searchInBookPattern;

  static const String settingsHome = ReaderRoutePaths.settingsHome;
  static const String appSettings = ReaderRoutePaths.appSettings;
  static const String readerSettings = ReaderRoutePaths.readerSettings;
  static const String cloudSettings = ReaderRoutePaths.cloudSettings;
  static const String about = ReaderRoutePaths.about;
  static const String stats = ReaderRoutePaths.stats;

  static String reader(String uid) => ReaderRoutePaths.reader(uid);
  static String toc(String uid) => ReaderRoutePaths.toc(uid);
  static String searchInBook(String uid) => ReaderRoutePaths.searchInBook(uid);
}
