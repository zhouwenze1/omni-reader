import 'package:flutter_test/flutter_test.dart';

import 'package:reader_mobile/utils/formatters.dart';

void main() {
  test('AppFormatters.percent formats progression', () {
    expect(AppFormatters.percent(0.25), '25%');
    expect(AppFormatters.percent(0.333, digits: 1), '33.3%');
  });
}
