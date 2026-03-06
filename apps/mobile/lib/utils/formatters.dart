class AppFormatters {
  const AppFormatters._();

  static String percent(double value, {int digits = 0}) {
    final normalized = (value * 100).clamp(0, 100);
    return '${normalized.toStringAsFixed(digits)}%';
  }

  static String date(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String dateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${date(value)} $hour:$minute';
  }
}
