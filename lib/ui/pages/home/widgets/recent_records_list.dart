import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';

/// Displays the most recent time records on the home page.
class RecentRecordsList extends StatelessWidget {
  final List<TimeRecord> records;

  const RecentRecordsList({super.key, required this.records});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final recent = records.take(3).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('最近记录', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
        ),
        ...recent.asMap().entries.map((entry) {
          final i = entry.key;
          final record = entry.value;
          final cat = CategoryLookup.byId(context, record.categoryId);
          final catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 28,
                      decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          if (record.note != null)
                            Text(record.note!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(_formatDuration(record.duration), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (i < recent.length - 1) const Divider(height: 1, color: AppColors.divider),
            ],
          );
        }),
      ],
    );
  }
}
