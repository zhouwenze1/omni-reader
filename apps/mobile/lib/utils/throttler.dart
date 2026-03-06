import 'dart:async';

class Throttler {
  Throttler(this.delay);

  final Duration delay;
  bool _locked = false;

  Future<void> run(FutureOr<void> Function() action) async {
    if (_locked) {
      return;
    }
    _locked = true;
    try {
      await Future<void>.sync(action);
    } finally {
      Timer(delay, () {
        _locked = false;
      });
    }
  }
}
