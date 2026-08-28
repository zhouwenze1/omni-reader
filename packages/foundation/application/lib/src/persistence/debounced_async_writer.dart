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
    _timer = Timer(debounce, () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      _writeChain =
          _writeChain.catchError((_) {}).then((_) => _writer(pending));
    }

    try {
      await _writeChain;
    } catch (_) {}
  }

  Future<void> close() async {
    await flush();
  }
}
