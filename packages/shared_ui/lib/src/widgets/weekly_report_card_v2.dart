import 'package:flutter/material.dart';

/// 周报卡 v2 的文案包(shared_ui 不持有 l10n,由宿主注入)。
class WeeklyReportLabels {
  const WeeklyReportLabels({
    required this.coreDataTitle,
    required this.streakPrefix,
    required this.streakSuffix,
    required this.totalTimePrefix,
    required this.secondaryDataTitle,
    required this.finishedBooksLabel,
    required this.notesHighlightsLabel,
  });

  /// 「核心数据」
  final String coreDataTitle;

  /// 「坚持」/「共阅读」
  final String streakPrefix;
  final String streakSuffix;
  final String totalTimePrefix;

  /// 「次要数据」
  final String secondaryDataTitle;
  final String finishedBooksLabel;
  final String notesHighlightsLabel;
}

/// “我的”页周报卡 v2:粉色渐变 + 核心数据(连读/本周时长)+
/// 次要数据(已完成/笔记高亮),点击进入统计中心。
/// 排版规格见 docs/specs/2026-08-30-reading-stats-center.md §5.1。
class WeeklyReportCardV2 extends StatelessWidget {
  const WeeklyReportCardV2({
    super.key,
    required this.streakDays,
    required this.weekSeconds,
    required this.completedBooks,
    required this.notesHighlightsCount,
    required this.labels,
    required this.formatDuration,
    this.onTap,
  });

  final int streakDays;
  final int weekSeconds;
  final int completedBooks;
  final int notesHighlightsCount;
  final WeeklyReportLabels labels;
  final String Function(int seconds) formatDuration;
  final VoidCallback? onTap;

  static const Color _accentRed = Color(0xFFE5484D);
  static const Color _accentTeal = Color(0xFF26A69A);
  static const Color _accentOrange = Color(0xFFFF7043);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.54);
    final timeValueColor =
        isDark ? colorScheme.primary : const Color(0xFF0C7D69);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF3B2B33), Color(0xFF332B3E)]
              : const [Color(0xFFFCE7EE), Color(0xFFF6E3F8)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labels.coreDataTitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 20,
                      color: _accentOrange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      labels.streakPrefix,
                      style: TextStyle(fontSize: 14, color: onSurface),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streakDays',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _accentRed,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      labels.streakSuffix,
                      style: TextStyle(fontSize: 14, color: onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: _accentTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      labels.totalTimePrefix,
                      style: TextStyle(fontSize: 14, color: onSurface),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatDuration(weekSeconds),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: timeValueColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  labels.secondaryDataTitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labels.finishedBooksLabel,
                        style: TextStyle(fontSize: 14, color: onSurface),
                      ),
                    ),
                    Text(
                      '$completedBooks',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _accentRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.location_history,
                      size: 18,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        labels.notesHighlightsLabel,
                        style: TextStyle(fontSize: 14, color: onSurface),
                      ),
                    ),
                    Text(
                      '$notesHighlightsCount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _accentTeal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: onSurface.withValues(alpha: 0.42),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
