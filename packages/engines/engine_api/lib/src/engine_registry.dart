import 'reader_engine.dart';

class EngineRegistry {
  EngineRegistry(this._engines);

  final List<ReaderEngine> _engines;

  ReaderEngine? findByFormat(String format) {
    for (final engine in _engines) {
      if (engine.supportsFormat(format)) {
        return engine;
      }
    }
    return null;
  }

  List<ReaderEngine> get all => List.unmodifiable(_engines);
}
