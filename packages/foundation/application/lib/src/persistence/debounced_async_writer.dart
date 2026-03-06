import 'dart:async';

typedef AsyncValueWriter<T> = Future<void> Function(T value);

class DebouncedAsyncWriter<T> {
  DebouncedAsyncWriter({
    required this.debounce,
    required AsyncValueWriter<T> writer,
  }) : _writer = writer;

  final Duration debounce;
  final AsyncValueWriter<T> _writer;

  Timer? _timer;
  T? _pending;
  Future<void> _writeChain = Future<void>.value();

  void schedule(T value) {
    _pending = value;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  void flush() {
    final pending = _pending;
    if (pending == null) {
      return;
    }

    _pending = null;
    _writeChain = _writeChain.catchError((_) {}).then((_) => _writer(pending));
  }

  Future<void> close() async {
    _timer?.cancel();
    flush();
    try {
      await _writeChain;
    } catch (_) {}
  }
}
