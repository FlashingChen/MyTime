import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

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
            color: AppColors.textPrimary,
          ),
          Column(
            children: [
              Text(
                '${date.month}月${date.day}日',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                dayName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
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
            color: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }
}
