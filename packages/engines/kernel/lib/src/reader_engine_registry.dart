import 'reader_engine.dart';

class ReaderEngineRegistry {
  ReaderEngineRegistry(Iterable<ReaderEngine> engines)
      : _engines = List<ReaderEngine>.unmodifiable(engines) {
    for (final engine in _engines) {
      final id = _normalize(engine.id);
      if (_byId.containsKey(id)) {
        throw StateError('Duplicate engine id: ${engine.id}');
      }
      _byId[id] = engine;
      for (final format in engine.supportedFormats) {
        _byFormat.putIfAbsent(_normalize(format), () => engine);
      }
    }
  }

  final List<ReaderEngine> _engines;
  final Map<String, ReaderEngine> _byFormat = <String, ReaderEngine>{};
  final Map<String, ReaderEngine> _byId = <String, ReaderEngine>{};

  ReaderEngine? findById(String id) {
    return _byId[_normalize(id)];
  }

  ReaderEngine? findByFormat(String format) {
    return _byFormat[_normalize(format)];
  }

  ReaderEngine requireByFormat(String format) {
    final engine = findByFormat(format);
    if (engine == null) {
      throw StateError('No reader engine registered for format: $format');
    }
    return engine;
  }

  List<ReaderEngine> get all => List.unmodifiable(_engines);

  Set<String> get supportedFormats => _byFormat.keys.toSet();

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}
