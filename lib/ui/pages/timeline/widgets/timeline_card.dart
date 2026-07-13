import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';

/// A card representing a time record on the timeline.
class TimelineCard extends StatelessWidget {
  final TimeRecord record;
  final VoidCallback? onTap;

  const TimelineCard({super.key, required this.record, this.onTap});

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cat = CategoryLookup.byId(context, record.categoryId);
    final catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: catColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: catColor, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: catColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_formatTime(record.startTime)} - ${_formatTime(record.endTime)} · ${_formatDuration(record.duration)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
