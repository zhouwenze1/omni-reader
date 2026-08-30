import 'package:flutter_test/flutter_test.dart';
import 'package:kernel/kernel.dart';

void main() {
  test('decodes selection event data', () {
    final event = ReaderEvent.fromRaw(
      type: ReaderEventType.selection,
      payload: <String, dynamic>{
        'phase': 'start',
        'mode': 'selection',
        'text': 'selected',
        'rect': <String, dynamic>{'left': 12, 'top': 24},
      },
    );

    final data = event.asData<ReaderSelectionData>();

    expect(data?.phase, 'start');
    expect(data?.text, 'selected');
    expect(data?.rect?['left'], 12);
  });

  test('decodes highlight tapped event data', () {
    final event = ReaderEvent.fromRaw(
      type: ReaderEventType.highlightTapped,
      payload: <String, dynamic>{
        'uid': 'hl-1',
        'href': 'Text/chapter.xhtml',
        'rects': <Map<String, dynamic>>[
          <String, dynamic>{'left': 1, 'top': 2},
        ],
      },
    );

    final data = event.asData<ReaderHighlightTappedData>();

    expect(data?.uid, 'hl-1');
    expect(data?.href, 'Text/chapter.xhtml');
    expect(data?.rects, hasLength(1));
  });
}
