import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';
import 'package:kernel/kernel.dart';

class _FakeEngine extends ReaderEngine {
  _FakeEngine(this._id, this._formats);

  final String _id;
  final Set<String> _formats;

  @override
  String get id => _id;

  @override
  Set<String> get supportedFormats => _formats;

  @override
  Set<ReaderCapability> get capabilities => const <ReaderCapability>{};

  @override
  Future<ReaderSession> createSession({
    required Book book,
    ReadingProgress? initialProgress,
    ReaderStyle initialStyle = ReaderStyle.defaults,
    String? initialLayoutMode,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('ReaderEngineRegistry', () {
    test('finds engines by format case-insensitively', () {
      final registry = ReaderEngineRegistry([
        _FakeEngine('epub', <String>{'epub'}),
      ]);

      expect(registry.findByFormat('EPUB')?.id, 'epub');
      expect(registry.requireByFormat(' epub ').id, 'epub');
      expect(registry.findByFormat('mobi'), isNull);
    });

    test('rejects duplicate engine ids', () {
      expect(
        () => ReaderEngineRegistry([
          _FakeEngine('epub', <String>{'epub'}),
          _FakeEngine('epub', <String>{'pdf'}),
        ]),
        throwsStateError,
      );
    });

    test('rejects a format claimed by two different engines', () {
      expect(
        () => ReaderEngineRegistry([
          _FakeEngine('epub', <String>{'epub', 'webpub'}),
          _FakeEngine('web', <String>{'webpub'}),
        ]),
        throwsStateError,
      );
    });

    test('tolerates duplicate formats within one engine', () {
      final registry = ReaderEngineRegistry([
        _FakeEngine('audio', <String>{'audio', 'AUDIO'}),
      ]);

      expect(registry.findByFormat('audio')?.id, 'audio');
    });
  });
}
