import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// AI insight card with weekly summary and suggestions based on real data.
class AiInsightView extends StatelessWidget {
  final List<TimeRecord> records;

  const AiInsightView({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final totalMinutes = records.fold<int>(0, (sum, r) => sum + r.duration.inMinutes);
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    if (records.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
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
              const Text('暂无数据', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 6),
              const Text(
                '还没有足够的记录来生成分析。开始记录你的时间吧！',
                style: TextStyle(fontSize: 12, color: Color(0xFFA5B4FC), height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    // Aggregate by category
    final categoryMinutes = <String, int>{};
    for (final r in records) {
      categoryMinutes[r.categoryId] = (categoryMinutes[r.categoryId] ?? 0) + r.duration.inMinutes;
    }

    // Find top category
    String topCategoryId = records.first.categoryId;
    int topMinutes = 0;
    for (final e in categoryMinutes.entries) {
      if (e.value > topMinutes) {
        topMinutes = e.value;
        topCategoryId = e.key;
      }
    }
    final topCat = CategoryLookup.byId(context, topCategoryId);

    // Count longest session
    int longestMinutes = 0;
    for (final r in records) {
      if (r.duration.inMinutes > longestMinutes) {
        longestMinutes = r.duration.inMinutes;
      }
    }

    // Generate dynamic suggestion
    final suggestions = <String>[];
    if (longestMinutes > 120) {
      suggestions.add('你最长的工作块持续了 ${longestMinutes ~/ 60}h${longestMinutes % 60}m，建议每隔 90 分钟休息一次以保持效率。');
    }
    if (topMinutes > 0) {
      final topPct = (topMinutes * 100 ~/ totalMinutes);
      suggestions.add('${topCat.name}占比 $topPct%，是耗时最多的活动。');
    }
    if (totalMinutes < 120) {
      suggestions.add('记录时间较短，建议增加专注时段。');
    }
    if (suggestions.isEmpty) {
      suggestions.add('继续保持当前的节奏！');
    }

    return SingleChildScrollView(
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
                  '本周你共记录 ${hours}h ${mins}m 的活动，共 ${records.length} 条记录。',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFA5B4FC), height: 1.6),
                ),
                const SizedBox(height: 10),
                ...suggestions.map((s) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFA5B4FC), height: 1.5),
                  ),
                )),
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
