import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// AI insight card with weekly summary and suggestions.
class AiInsightView extends StatelessWidget {
  final List<TimeRecord> records;

  const AiInsightView({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final totalMinutes = records.fold<int>(0, (sum, r) => sum + r.duration.inMinutes);
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, Color(0xFF2D2D44)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgIcons.sparkle(),
                const SizedBox(height: 8),
                const Text('本周总结', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  '本周你共记录 ${hours}h ${mins}m 的活动。建议适当增加休息间隔，保持专注效率。',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFA5B4FC), height: 1.6),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '建议：尝试番茄工作法，25 分钟专注 + 5 分钟休息，预计可将深度工作时间提升 20%。',
                    style: TextStyle(fontSize: 11, color: Color(0xFFA5B4FC), height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: const Text('重新生成建议', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
