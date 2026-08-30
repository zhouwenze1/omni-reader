import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';

import '../../../di/services_providers.dart';
import '../../../l10n/l10n.dart';
import 'package:shared_ui/shared_ui.dart';

/// 统计中心:核心指标 / 时长趋势 / 热力图 / 时段分布 / 书籍排行。
/// 排版规格见 docs/specs/2026-08-30-reading-stats-center.md §5.2。
class StatsCenterPage extends ConsumerStatefulWidget {
  const StatsCenterPage({super.key});

  @override
  ConsumerState<StatsCenterPage> createState() => _StatsCenterPageState();
}

class _StatsCenterPageState extends ConsumerState<StatsCenterPage> {
  StatsRange _range = StatsRange.week;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(statsCenterProvider(_range));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsCenterTitle)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(statsCenterProvider(_range)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data.totalSeconds == 0) {
            return EmptyView(
              title: l10n.statsEmptyTitle,
              message: l10n.statsEmptyMessage,
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _rangeSelector(l10n),
                      const SizedBox(height: 16),
                      StatsOverviewGrid(items: _overviewItems(l10n, data)),
                      const SizedBox(height: 16),
                      _trendCard(l10n, data),
                      const SizedBox(height: 16),
                      _heatmapCard(l10n, data),
                      if (_hourlyPoints(l10n, data) != null) ...[
                        const SizedBox(height: 16),
                        _hourlyCard(l10n, data),
                      ],
                      if (_topBooks(l10n, data) != null) ...[
                        const SizedBox(height: 16),
                        _topBooksCard(l10n, data),
                      ],
                      if (wide) ...[
                        // C5 在此实现桌面宽屏栅格排列;当前双端同构单列。
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _rangeSelector(MobileStrings l10n) {
    return SegmentedButton<StatsRange>(
      segments: [
        ButtonSegment(value: StatsRange.week, label: Text(l10n.statsRangeWeek)),
        ButtonSegment(
          value: StatsRange.month,
          label: Text(l10n.statsRangeMonth),
        ),
        ButtonSegment(value: StatsRange.year, label: Text(l10n.statsRangeYear)),
      ],
      selected: {_range},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          setState(() => _range = selection.first),
    );
  }

  String _duration(MobileStrings l10n, int seconds) {
    return formatReadingDuration(
      seconds,
      (hours, minutes) => hours > 0
          ? l10n.statsHoursMinutes(hours, minutes)
          : l10n.statsMinutes(minutes),
    );
  }

  List<StatsOverviewItem> _overviewItems(
      MobileStrings l10n, StatsCenterData data) {
    return [
      StatsOverviewItem(
        icon: Icons.timer_outlined,
        accent: const Color(0xFF26A69A),
        value: _duration(l10n, data.totalSeconds),
        label: l10n.statsTotalTime,
        sub: l10n.statsDaysWithReadingSuffix(data.heatDays.length),
      ),
      StatsOverviewItem(
        icon: Icons.local_fire_department,
        accent: const Color(0xFFFF7043),
        value: l10n.statsDaysShort(data.streak.currentDays),
        label: l10n.statsCurrentStreak,
        sub: l10n.statsLongestStreakSuffix(data.streak.longestDays),
      ),
      StatsOverviewItem(
        icon: Icons.menu_book_outlined,
        accent: const Color(0xFFE5484D),
        value: l10n.statsBooksCountShort(data.finishedBooks),
        label: l10n.statsFinishedBooksTile,
        sub: l10n.statsTotalBooksSuffix(data.totalBooks),
      ),
      StatsOverviewItem(
        icon: Icons.location_history,
        accent: const Color(0xFF26A69A),
        value: '${data.highlightsCount + data.notesCount}',
        label: l10n.statsNotesHighlightsTile,
        sub: l10n.statsHighlightsNotesBookmarks(
          data.highlightsCount,
          data.notesCount,
          data.bookmarksCount,
        ),
      ),
    ];
  }

  List<StatsBarPoint> _trendPoints(MobileStrings l10n, StatsCenterData data) {
    final now = DateTime.now();
    final window = statsWindowFor(_range, now);
    if (window.monthly) {
      final seconds = fillMonthlySeconds(data.monthly, window.from, 12);
      return [
        for (var i = 0; i < 12; i++)
          StatsBarPoint(
            value: seconds[i] / 60.0,
            label: l10n.statsMonthLabel(
                DateTime(window.from.year, window.from.month + i).month),
            tooltip:
                '${l10n.statsMonthLabel(DateTime(window.from.year, window.from.month + i).month)} · ${_duration(l10n, seconds[i])}',
            highlighted: i == _highlightIndex(seconds),
          ),
      ];
    }
    final days = _range == StatsRange.week ? 7 : 30;
    final weekdays = l10n.statsTrendWeekdayLabels;
    final seconds = fillDailySeconds(data.daily, window.from, days);
    return [
      for (var i = 0; i < days; i++)
        StatsBarPoint(
          value: seconds[i] / 60.0,
          label: _range == StatsRange.week
              ? weekdays[window.from.add(Duration(days: i)).weekday - 1]
              : (i % 5 == 0 ? '${window.from.add(Duration(days: i)).day}' : ''),
          tooltip:
              '${l10n.statsDateLabel(window.from.add(Duration(days: i)))} · ${_duration(l10n, seconds[i])}',
          highlighted: i == _highlightIndex(seconds),
        ),
    ];
  }

  int _highlightIndex(List<int> secondsList) {
    for (var i = secondsList.length - 1; i >= 0; i--) {
      if (secondsList[i] > 0) {
        return i;
      }
    }
    return secondsList.length - 1;
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  Widget _trendCard(MobileStrings l10n, StatsCenterData data) {
    final points = _trendPoints(l10n, data);
    final activeDays = points.where((p) => p.value > 0).length;
    final totalMinutes = points.fold<double>(0, (sum, p) => sum + p.value);
    final avgMinutes =
        activeDays == 0 ? 0 : (totalMinutes / activeDays).round();
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.statsTrendSection,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                l10n.statsDailyAvg(avgMinutes),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatsBarChart(points: points),
        ],
      ),
    );
  }

  Widget _heatmapCard(MobileStrings l10n, StatsCenterData data) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statsHeatmapSection,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ReadingHeatmap(
            weeks: 15,
            secondsByDay: data.heatDays,
            now: DateTime.now(),
            monthLabel: l10n.statsMonthLabel,
            weekdayLabels: l10n.statsHeatmapWeekdayLabels,
            dayLabel: (day, seconds) =>
                '${l10n.statsDateLabel(day)}:${_duration(l10n, seconds)}',
            lessLabel: l10n.statsLess,
            moreLabel: l10n.statsMore,
          ),
        ],
      ),
    );
  }

  /// 无数据(全 0)时返回 null,由调用方隐藏整节。
  List<StatsBarPoint>? _hourlyPoints(MobileStrings l10n, StatsCenterData data) {
    final hasData = data.hourly.any((it) => it.seconds > 0);
    if (!hasData) {
      return null;
    }
    HourlyReadingStat? peak;
    for (final it in data.hourly) {
      if (peak == null || it.seconds > peak.seconds) {
        peak = it;
      }
    }
    return [
      for (final it in data.hourly)
        StatsBarPoint(
          value: it.seconds / 60.0,
          label: it.hour % 6 == 0 ? '${it.hour}' : '',
          tooltip:
              '${it.hour.toString().padLeft(2, '0')}:00 · ${_duration(l10n, it.seconds)}',
          highlighted: peak != null && it.hour == peak.hour,
        ),
    ];
  }

  Widget _hourlyCard(MobileStrings l10n, StatsCenterData data) {
    final points = _hourlyPoints(l10n, data)!;
    final hasData = data.hourly.any((it) => it.seconds > 0);
    HourlyReadingStat? peak;
    for (final it in data.hourly) {
      if (peak == null || it.seconds > peak.seconds) {
        peak = it;
      }
    }
    final caption = hasData && peak != null
        ? l10n.statsPeakHour(peak.hour)
        : l10n.statsPeakHourNone;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.statsHourlySection,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatsBarChart(points: points, height: 140, maxBarWidth: 10),
        ],
      ),
    );
  }

  List<StatsTopBook>? _topBooks(MobileStrings l10n, StatsCenterData data) {
    if (data.topBooks.isEmpty) {
      return null;
    }
    final totalSeconds = data.topBooks.fold<int>(
      0,
      (sum, it) => sum + it.seconds,
    );
    final libraryRoot = data.libraryRootPath;
    return [
      for (final it in data.topBooks)
        StatsTopBook(
          title: it.title == '已删除的书籍' ? l10n.statsDeletedBook : it.title,
          coverPath: it.coverRelPath == null || it.coverRelPath!.isEmpty
              ? null
              : '$libraryRoot/${it.bookUid}/${it.coverRelPath}',
          progress: it.cachedProgress,
          secondsLabel: _duration(l10n, it.seconds),
          share: totalSeconds > 0 ? it.seconds / totalSeconds : 0,
        ),
    ];
  }

  Widget _topBooksCard(MobileStrings l10n, StatsCenterData data) {
    return _sectionCard(
      child: StatsTopBooksCard(
        title: l10n.statsBooksSection,
        items: _topBooks(l10n, data)!,
      ),
    );
  }
}
