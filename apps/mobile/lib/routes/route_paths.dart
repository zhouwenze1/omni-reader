class RoutePaths {
  static const String library = '/';
  static const String readerPattern = '/reader/:uid';

  static String reader(String uid) => '/reader/$uid';
}
