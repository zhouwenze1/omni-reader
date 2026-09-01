import 'package:flutter/widgets.dart';

/// 阅读中页复用的时间/进度格式化(与移动端 AppFormatters 同口径)。
class ReaderFormatters {
  const ReaderFormatters._();

  static String percent(double value, {int digits = 0}) {
    final normalized = (value * 100).clamp(0, 100);
    return '${normalized.toStringAsFixed(digits)}%';
  }

  static String readingProgress(double value, {Locale? locale}) {
    return _isZh(locale)
        ? '阅读进度 ${percent(value)}'
        : 'Progress ${percent(value)}';
  }

  static String relativeReadTime(
    DateTime? value, {
    DateTime? now,
    Locale? locale,
    bool withVerb = false,
  }) {
    final zh = _isZh(locale);
    if (value == null) {
      return zh ? '未开始阅读' : 'Not started';
    }

    final current = (now ?? DateTime.now()).toLocal();
    final target = value.toLocal();
    final currentDate = DateTime(current.year, current.month, current.day);
    final targetDate = DateTime(target.year, target.month, target.day);
    final dayDiff = currentDate.difference(targetDate).inDays;

    if (dayDiff <= 0) {
      return zh ? (withVerb ? '今天阅读' : '今天') : 'Today';
    }
    if (dayDiff < 7) {
      return zh
          ? (withVerb ? '$dayDiff天前阅读' : '$dayDiff天前')
          : '$dayDiff days ago';
    }

    final weekDiff = (dayDiff / 7).floor();
    if (weekDiff == 1) {
      return zh ? (withVerb ? '上周阅读' : '上周') : 'Last week';
    }
    if (dayDiff < 30) {
      return zh
          ? (withVerb ? '$weekDiff周前阅读' : '$weekDiff周前')
          : '$weekDiff weeks ago';
    }

    final monthDiffRaw =
        (current.year - target.year) * 12 + current.month - target.month;
    final monthDiff =
        current.day < target.day ? monthDiffRaw - 1 : monthDiffRaw;
    if (monthDiff <= 1) {
      return zh ? (withVerb ? '上个月阅读' : '上个月') : 'Last month';
    }
    if (monthDiff < 12) {
      return zh
          ? (withVerb ? '$monthDiff个月前阅读' : '$monthDiff个月前')
          : '$monthDiff months ago';
    }

    final yearDiffRaw = current.year - target.year;
    final yearDiff = current.month < target.month ||
            (current.month == target.month && current.day < target.day)
        ? yearDiffRaw - 1
        : yearDiffRaw;
    if (yearDiff <= 1) {
      return zh ? (withVerb ? '去年阅读' : '去年') : 'Last year';
    }
    return zh
        ? (withVerb ? '$yearDiff年前阅读' : '$yearDiff年前')
        : '$yearDiff years ago';
  }

  static bool _isZh(Locale? locale) {
    final code = locale?.languageCode.toLowerCase() ?? 'zh';
    return code.startsWith('zh');
  }
}
