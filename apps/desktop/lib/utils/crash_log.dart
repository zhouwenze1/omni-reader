import 'dart:io';

/// 桌面端崩溃/启动失败日志,写在 exe 同目录 crash.log。
/// 白屏(启动即空白)这类无法看到界面的故障靠它定位。
class CrashLog {
  CrashLog._();

  static void write(String message) {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final stamp = DateTime.now().toIso8601String();
      File('$exeDir${Platform.pathSeparator}crash.log').writeAsStringSync(
        '[$stamp] $message\n\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // 写日志失败不能再引发新异常。
    }
  }
}
