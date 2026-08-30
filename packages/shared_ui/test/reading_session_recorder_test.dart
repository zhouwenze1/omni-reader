import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  test('heartbeat splits foreground time into consecutive segments', () async {
    fakeAsync((async) {
      var time = DateTime(2026, 8, 30, 10);
      final segments = <(DateTime, DateTime)>[];
      final recorder = ReadingSessionRecorder(
        bookUid: 'b1',
        onSegment: (startedAt, endedAt) => segments.add((startedAt, endedAt)),
        now: () => time,
      );

      recorder.start();
      time = time.add(const Duration(seconds: 60));
      async.elapse(const Duration(seconds: 60));
      time = time.add(const Duration(seconds: 60));
      async.elapse(const Duration(seconds: 60));

      expect(segments, hasLength(2));
      expect(
        segments[0],
        (
          DateTime(2026, 8, 30, 10),
          DateTime(2026, 8, 30, 10, 1),
        ),
      );
      expect(
        segments[1],
        (
          DateTime(2026, 8, 30, 10, 1),
          DateTime(2026, 8, 30, 10, 2),
        ),
      );
      recorder.dispose();
    });
  });

  test('pause settles the tail and resume re-anchors; zero-second dropped',
      () async {
    fakeAsync((async) {
      var time = DateTime(2026, 8, 30, 10);
      final segments = <(DateTime, DateTime)>[];
      final recorder = ReadingSessionRecorder(
        bookUid: 'b1',
        onSegment: (startedAt, endedAt) => segments.add((startedAt, endedAt)),
        now: () => time,
      );

      recorder.start();
      time = time.add(const Duration(seconds: 30));
      recorder.pause();
      expect(segments, hasLength(1));
      expect(segments.single.$2, DateTime(2026, 8, 30, 10, 0, 30));

      recorder.resume();
      time = time.add(const Duration(seconds: 1));
      recorder.pause();
      expect(segments, hasLength(2));

      // 无时间流逝的 pause:零秒段被丢弃。
      recorder.resume();
      recorder.pause();
      expect(segments, hasLength(2));

      // 暂停期间心跳不触发。
      time = time.add(const Duration(minutes: 5));
      async.elapse(const Duration(minutes: 5));
      expect(segments, hasLength(2));
      recorder.dispose();
    });
  });

  test('dispose settles the final segment and stops the heartbeat', () async {
    fakeAsync((async) {
      var time = DateTime(2026, 8, 30, 22);
      final segments = <(DateTime, DateTime)>[];
      final recorder = ReadingSessionRecorder(
        bookUid: 'b1',
        onSegment: (startedAt, endedAt) => segments.add((startedAt, endedAt)),
        now: () => time,
      );

      recorder.start();
      time = time.add(const Duration(seconds: 45));
      recorder.dispose();
      expect(segments, hasLength(1));
      expect(segments.single.$2, DateTime(2026, 8, 30, 22, 0, 45));

      time = time.add(const Duration(minutes: 3));
      async.elapse(const Duration(minutes: 3));
      expect(segments, hasLength(1));
    });
  });

  test('start/resume are idempotent and keep one heartbeat timer', () async {
    fakeAsync((async) {
      var time = DateTime(2026, 8, 30, 10);
      final segments = <(DateTime, DateTime)>[];
      final recorder = ReadingSessionRecorder(
        bookUid: 'b1',
        onSegment: (startedAt, endedAt) => segments.add((startedAt, endedAt)),
        now: () => time,
      );

      recorder.start();
      recorder.start();
      recorder.resume(); // anchor 未清空时为 no-op
      time = time.add(const Duration(seconds: 60));
      async.elapse(const Duration(seconds: 60));
      expect(segments, hasLength(1));

      time = time.add(const Duration(seconds: 60));
      async.elapse(const Duration(seconds: 60));
      expect(segments, hasLength(2));
      recorder.dispose();
      recorder.dispose();
    });
  });

  test('clock running backwards drops the reversed segment', () async {
    fakeAsync((async) {
      var time = DateTime(2026, 8, 30, 10);
      final segments = <(DateTime, DateTime)>[];
      final recorder = ReadingSessionRecorder(
        bookUid: 'b1',
        onSegment: (startedAt, endedAt) => segments.add((startedAt, endedAt)),
        now: () => time,
      );

      recorder.start();
      time = time.subtract(const Duration(minutes: 10));
      recorder.pause();
      expect(segments, isEmpty);
      recorder.dispose();
    });
  });
}
