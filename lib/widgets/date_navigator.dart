import 'package:flutter/material.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';

/// Date navigation widget with prev/next arrows.
class DateNavigator extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const DateNavigator({
    super.key,
    required this.date,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const dayNames = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final dayName = dayNames[date.weekday - 1];
    final arrowColor = context.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Text(
              '‹',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
            ),
            color: arrowColor,
          ),
          Column(
            children: [
              Text(
                '${date.month}月${date.day}日',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface,
                ),
              ),
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: onNext,
            icon: const Text(
              '›',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
            ),
            color: arrowColor,
          ),
        ],
      ),
    );
  }
}
