import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'stats_state.dart';

/// 统计中心通用柱状图(时长趋势 / 时段分布共用)。
///
/// 值为分钟;x 轴稀疏标签(空串不画);触摸显示反色 tooltip;
/// 最新有数据柱(由调用方标 [StatsBarPoint.highlighted])用 primary。
class StatsBarChart extends StatelessWidget {
  const StatsBarChart({
    super.key,
    required this.points,
    this.height = 200,
    this.maxBarWidth = 18,
  });

  final List<StatsBarPoint> points;
  final double height;
  final double maxBarWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = points.fold<double>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    final maxY = maxValue <= 0 ? 10.0 : maxValue * 1.15;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colorScheme.inverseSurface,
              tooltipRoundedRadius: 6,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = points[group.x];
                if (point.tooltip.isEmpty) {
                  return null;
                }
                return BarTooltipItem(
                  point.tooltip,
                  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onInverseSurface,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 ||
                      index >= points.length ||
                      points[index].label.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(
                      points[index].label,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].value,
                    width: maxBarWidth,
                    color: points[i].highlighted
                        ? colorScheme.primary
                        : colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
