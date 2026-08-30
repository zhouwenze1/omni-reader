import 'package:flutter/material.dart';

/// 核心指标磁贴数据。
class StatsOverviewItem {
  const StatsOverviewItem({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    this.sub,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;
  final String? sub;
}

/// 核心指标网格:移动端 2×2(默认),桌面 1×4([columns]=4)。
class StatsOverviewGrid extends StatelessWidget {
  const StatsOverviewGrid({
    super.key,
    required this.items,
    this.columns = 2,
  });

  final List<StatsOverviewItem> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final divider = colorScheme.outlineVariant;
    final rows = <Widget>[];

    for (var start = 0; start < items.length; start += columns) {
      final rowItems = items.skip(start).take(columns).toList();
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 12));
        rows.add(Container(height: 1, color: divider));
        rows.add(const SizedBox(height: 12));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < rowItems.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(width: 12),
                  Container(width: 1, color: divider),
                  const SizedBox(width: 12),
                ],
                Expanded(child: _tile(rowItems[i], onSurface)),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _tile(StatsOverviewItem item, Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, size: 20, color: item.accent),
        const SizedBox(height: 6),
        Text(
          item.value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 12,
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
        if (item.sub != null) ...[
          const SizedBox(height: 2),
          Text(
            item.sub!,
            style: TextStyle(
              fontSize: 11,
              color: onSurface.withValues(alpha: 0.42),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
