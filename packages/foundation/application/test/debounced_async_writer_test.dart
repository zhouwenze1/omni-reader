import 'package:flutter_test/flutter_test.dart';

import 'package:foundation_application/application.dart';

void main() {
  test('flush writes pending value immediately and is idempotent', () async {
    final values = <int>[];
    final writer = DebouncedAsyncWriter<int>(
      debounce: const Duration(hours: 1),
      writer: (value) async {
        values.add(value);
      },
    );

    writer.schedule(7);
    await writer.flush();
    await writer.flush();

    expect(values, <int>[7]);
    await writer.close();
  });
}
