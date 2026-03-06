import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_domain/domain.dart';

import 'package:reader_mobile/utils/formatters.dart';

void main() {
  test('AppFormatters.percent formats progression', () {
    expect(AppFormatters.percent(0.25), '25%');
    expect(AppFormatters.percent(0.333, digits: 1), '33.3%');
  });

  test('ReaderLayoutMode resolves adaptive paging by viewport size', () {
    expect(
      ReaderLayoutMode.resolveAdaptive(
        ReaderLayoutMode.pagedAuto,
        shortestSide: 390,
      ),
      ReaderLayoutMode.pagedSingle,
    );
    expect(
      ReaderLayoutMode.resolveAdaptive(
        ReaderLayoutMode.pagedAuto,
        shortestSide: 900,
      ),
      ReaderLayoutMode.pagedSpread,
    );
    expect(
      ReaderLayoutMode.resolveAdaptive(
        ReaderLayoutMode.scrollContinuous,
        shortestSide: 390,
      ),
      ReaderLayoutMode.scrollContinuous,
    );
  });
}
