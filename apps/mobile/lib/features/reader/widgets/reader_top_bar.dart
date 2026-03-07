import 'package:flutter/material.dart';

class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.onBackPressed,
    required this.title,
    required this.actions,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final VoidCallback onBackPressed;
  final String title;
  final List<Widget> actions;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: borderColor),
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          height: kToolbarHeight,
          child: IconTheme(
            data: IconThemeData(color: foregroundColor),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBackPressed,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 18,
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
