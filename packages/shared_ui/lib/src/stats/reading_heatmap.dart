import 'package:flutter/material.dart';

import 'stats_state.dart';

/// GitHub 风格阅读热力图(自绘,不依赖图表库)。
///
/// 列=自然周(旧→新,最后一列为本周),行=周一(顶)→周日(底);
/// 未来格渲染为底色且不可点;色阶 <15min/25% → <30min/50% →
/// <60min/75% → ≥60min/100% primary。
class ReadingHeatmap extends StatefulWidget {
  const ReadingHeatmap({
    super.key,
    required this.weeks,
    required this.secondsByDay,
    required this.now,
    required this.monthLabel,
    required this.weekdayLabels,
    required this.dayLabel,
    required this.lessLabel,
    required this.moreLabel,
    this.cellSize = 14,
    this.gap = 3,
  });

  final int weeks;
  final Map<String, int> secondsByDay;
  final DateTime now;

  /// 月份本地化(int month → '8月'/'Aug')。
  final String Function(int month) monthLabel;

  /// 7 个星期标签(一~日;建议仅一/三/五非空)。
  final List<String> weekdayLabels;

  /// 选中格的说明文案。
  final String Function(DateTime day, int seconds) dayLabel;

  final String lessLabel;
  final String moreLabel;

  final double cellSize;
  final double gap;

  @override
  State<ReadingHeatmap> createState() => _ReadingHeatmapState();
}

class _ReadingHeatmapState extends State<ReadingHeatmap> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final start = heatmapStart(widget.now, widget.weeks);
    final weekdayLabelWidth = 16.0;
    final columnsWidth =
        widget.weeks * (widget.cellSize + widget.gap) - widget.gap;

    final monthLabels = <Widget>[];
    var previousMonth = -1;
    for (var col = 0; col < widget.weeks; col++) {
      final firstOfDay = start.add(Duration(days: col * 7));
      if (firstOfDay.month != previousMonth) {
        previousMonth = firstOfDay.month;
        monthLabels.add(
          Positioned(
            left: col * (widget.cellSize + widget.gap),
            child: Text(
              widget.monthLabel(firstOfDay.month),
              style: TextStyle(
                fontSize: 10,
                color: onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          width: weekdayLabelWidth + 2 + columnsWidth,
          child: Stack(children: monthLabels),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: weekdayLabelWidth,
              child: Column(
                children: [
                  for (var row = 0; row < 7; row++)
                    Container(
                      height: widget.cellSize,
                      margin: EdgeInsets.only(bottom: widget.gap),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.weekdayLabels[row],
                        style: TextStyle(
                          fontSize: 9,
                          color: onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < widget.weeks; col++)
                  Row(
                    children: [
                      if (col > 0) SizedBox(width: widget.gap),
                      Column(
                        children: [
                          for (var row = 0; row < 7; row++)
                            _cell(
                              date: start.add(Duration(days: col * 7 + row)),
                              today: today,
                              colorScheme: colorScheme,
                            ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _selected == null
              ? ''
              : widget.dayLabel(
                  _selected!,
                  widget.secondsByDay[statsDayKey(_selected!)] ?? 0,
                ),
          style: TextStyle(
            fontSize: 11,
            height: 18 / 11,
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              widget.lessLabel,
              style: TextStyle(
                fontSize: 10,
                color: onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 4),
            for (final color in [
              colorScheme.surfaceContainerHighest,
              colorScheme.primary.withValues(alpha: 0.25),
              colorScheme.primary.withValues(alpha: 0.5),
              colorScheme.primary.withValues(alpha: 0.75),
              colorScheme.primary,
            ]) ...[
              const SizedBox(width: 2),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Text(
              widget.moreLabel,
              style: TextStyle(
                fontSize: 10,
                color: onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cell({
    required DateTime date,
    required DateTime today,
    required ColorScheme colorScheme,
  }) {
    final isFuture = date.isAfter(today);
    final seconds =
        isFuture ? 0 : (widget.secondsByDay[statsDayKey(date)] ?? 0);
    final color = isFuture
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
        : seconds <= 0
            ? colorScheme.surfaceContainerHighest
            : seconds < 15 * 60
                ? colorScheme.primary.withValues(alpha: 0.25)
                : seconds < 30 * 60
                    ? colorScheme.primary.withValues(alpha: 0.5)
                    : seconds < 60 * 60
                        ? colorScheme.primary.withValues(alpha: 0.75)
                        : colorScheme.primary;

    return GestureDetector(
      key: ValueKey('hm-${statsDayKey(date)}'),
      onTap: isFuture ? null : () => setState(() => _selected = date),
      child: Container(
        width: widget.cellSize,
        height: widget.cellSize,
        margin: EdgeInsets.only(bottom: widget.gap),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
