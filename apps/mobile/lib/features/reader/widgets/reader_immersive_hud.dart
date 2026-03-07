import 'package:flutter/material.dart';

class ReaderImmersiveHud extends StatelessWidget {
  const ReaderImmersiveHud({
    super.key,
    required this.timeText,
    required this.progress,
    required this.progressText,
    required this.darkMode,
    this.batteryLevel,
  });

  final String timeText;
  final double progress;
  final String progressText;
  final bool darkMode;
  final int? batteryLevel;

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        darkMode ? Colors.white.withValues(alpha: 0.88) : Colors.black87;
    final secondaryColor =
        darkMode ? Colors.white.withValues(alpha: 0.4) : Colors.black38;
    return Row(
      children: [
        _HudTextLine(
          color: foregroundColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_outlined, size: 14),
              const SizedBox(width: 4),
              Text(timeText),
              if (batteryLevel != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.battery_std, size: 15),
                const SizedBox(width: 4),
                Text('$batteryLevel%'),
              ],
            ],
          ),
        ),
        const Spacer(),
        _HudTextLine(
          color: foregroundColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: secondaryColor,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(progressText),
            ],
          ),
        ),
      ],
    );
  }
}

class _HudTextLine extends StatelessWidget {
  const _HudTextLine({
    required this.child,
    required this.color,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        color: color,
        fontSize: 13,
        height: 1,
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: _shadowAlpha(color)),
            blurRadius: 10,
          ),
        ],
      ),
      child: IconTheme(
        data: IconThemeData(
          color: color,
          size: 14,
        ),
        child: child,
      ),
    );
  }
}

double _shadowAlpha(Color color) {
  return color.computeLuminance() > 0.5 ? 0.16 : 0.38;
}
