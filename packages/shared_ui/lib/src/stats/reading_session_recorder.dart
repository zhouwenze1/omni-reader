import 'dart:async';

import 'package:flutter/foundation.dart';

/// 阅读时长埋点计时器(口径:前台全额计时,见
/// docs/specs/2026-08-30-reading-stats-center.md §4.3)。
///
/// 生命周期完全由阅读页驱动:阅读会话建立后 `start()`,阅读页现有
/// `didChangeAppLifecycleState` 的后台分支 `pause()`、resumed 分支
/// `resume()`,`dispose()` 兜底。Recorder 自身不监听系统事件、不依赖
/// 存储层,宿主通过 [onSegment] 接收段落并落盘。
///
/// 段落以 [heartbeat] 为上限切分(崩溃最多丢一个心跳);零秒段与时间
/// 倒挂段在此处即被丢弃。
// gstack-shortcut(spec-stats-duration): 前台全额计时、无挂机检测;
// 升级条件=用户反馈时长虚增,届时仅在 _settle 处追加活跃度判断。
class ReadingSessionRecorder {
  ReadingSessionRecorder({
    required this.bookUid,
    required void Function(DateTime startedAt, DateTime endedAt) onSegment,
    DateTime Function() now = DateTime.now,
    this.heartbeat = const Duration(seconds: 60),
  })  : _onSegment = onSegment,
        _now = now;

  final String bookUid;
  final Duration heartbeat;

  final void Function(DateTime startedAt, DateTime endedAt) _onSegment;
  final DateTime Function() _now;

  DateTime? _anchor;
  Timer? _timer;
  bool _started = false;

  /// 开始计时;已开始时为 no-op。暂停后的恢复请用 [resume]。
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _anchor = _now();
    _timer = Timer.periodic(heartbeat, (_) => _tick());
  }

  /// 暂停:结算当前段并停表;幂等。
  void pause() {
    if (!_started) {
      return;
    }
    _settle();
    _timer?.cancel();
    _timer = null;
  }

  /// 恢复:重新起表;幂等。
  void resume() {
    if (!_started || _anchor != null) {
      return;
    }
    _anchor = _now();
    _timer = Timer.periodic(heartbeat, (_) => _tick());
  }

  /// 结束并结算最后一段;幂等,调用后实例不可复用。
  void dispose() {
    if (!_started) {
      return;
    }
    _started = false;
    _settle();
    _timer?.cancel();
    _timer = null;
  }

  /// 心跳:结算上一段并立即开新段,保证单段长度不超过一个心跳。
  void _tick() {
    _settle();
    _anchor = _now();
  }

  void _settle() {
    final anchor = _anchor;
    if (anchor == null) {
      return;
    }
    _anchor = null;
    final ended = _now();
    if (ended.isBefore(anchor)) {
      return;
    }
    if (ended.difference(anchor).inSeconds < 1) {
      return;
    }
    try {
      _onSegment(anchor, ended);
    } catch (error) {
      debugPrint('[stats][record.error] $error');
    }
  }
}
