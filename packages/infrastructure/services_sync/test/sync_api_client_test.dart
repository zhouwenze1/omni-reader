import 'package:services_sync/services_sync.dart';
import 'package:test/test.dart';

void main() {
  // 协议边界回归:Go 服务器对空集合序列化为 null(如空账号首次 pull)。
  test('pull 响应 items 为 null 时解析为空列表', () {
    final result = SyncApiClient.parsePullJson(<String, dynamic>{
      'items': null,
      'serverTime': 123,
      'cursor': 0,
    });
    expect(result.items, isEmpty);
    expect(result.cursor, 0);
    expect(result.serverTime.millisecondsSinceEpoch, 123);
  });

  test('pull 响应条目(含字符串 locator)可解析', () {
    final result = SyncApiClient.parsePullJson(<String, dynamic>{
      'items': [
        <String, dynamic>{
          'bookUid': 'book-a',
          'locator': '{"href":"c1.xhtml","locations":{"progression":0.1}}',
          'progression': 0.42,
          'updatedAt': 1725000000000,
          'lastReadAt': null,
          'deviceId': 'dev1',
        },
      ],
      'serverTime': 9,
      'cursor': 3,
    });
    expect(result.items, hasLength(1));
    expect(result.items.first.bookUid, 'book-a');
    expect(result.items.first.progression, 0.42);
    expect(result.cursor, 3);
  });
}
