import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Simulated, data-driven insight card for the currently selected period.
class AiInsightView extends StatefulWidget {
  final List<TimeRecord> records;
  final String periodLabel;

  const AiInsightView({
    super.key,
    required this.records,
    this.periodLabel = '本周',
  });

  @override
  State<AiInsightView> createState() => _AiInsightViewState();
}

class _AiInsightViewState extends State<AiInsightView> {
  int _suggestionOffset = 0;

  @override
  Widget build(BuildContext context) {
    final gradientColors = context.isDark
        ? const [Color(0xFF313152), Color(0xFF1E1E32)]
        : const [AppColors.primaryDark, Color(0xFF2D2D44)];

    if (widget.records.isEmpty) {
      return _buildEmptyState(gradientColors);
    }

    final categoryMinutes = <String, int>{};
    var totalMinutes = 0;
    var longestMinutes = 0;
    for (final record in widget.records) {
      final minutes = record.duration.inMinutes;
      totalMinutes += minutes;
      longestMinutes = minutes > longestMinutes ? minutes : longestMinutes;
      final categoryId = record.categoryId ?? 'uncategorized';
      categoryMinutes[categoryId] =
          (categoryMinutes[categoryId] ?? 0) + minutes;
    }
    final topEntry = categoryMinutes.entries.reduce(
      (current, next) => current.value > next.value ? current : next,
    );
    final topCategory = CategoryLookup.byId(context, topEntry.key);
    final suggestions = _suggestions(
      totalMinutes: totalMinutes,
      longestMinutes: longestMinutes,
      topCategoryName: topCategory.name,
      topCategoryMinutes: topEntry.value,
    );
    final visibleSuggestions = List.generate(
      suggestions.length > 1 ? 2 : 1,
      (index) => suggestions[(_suggestionOffset + index) % suggestions.length],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgIcons.sparkle(),
                const SizedBox(height: 8),
                Text(
                  '${widget.periodLabel}总结',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.periodLabel}你共记录 ${formatStatsDuration(Duration(minutes: totalMinutes))} 的活动，共 ${widget.records.length} 条记录。',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA5B4FC),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                for (final (index, suggestion) in visibleSuggestions.indexed)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      suggestion,
                      key: ValueKey('ai-suggestion-$index'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA5B4FC),
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(
                () => _suggestionOffset =
                    (_suggestionOffset + 1) % suggestions.length,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(color: context.colorScheme.outline),
              ),
              child: Text(
                '重新生成建议',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _suggestions({
    required int totalMinutes,
    required int longestMinutes,
    required String topCategoryName,
    required int topCategoryMinutes,
  }) {
    final topPercentage = topCategoryMinutes * 100 ~/ totalMinutes;
    return [
      '$topCategoryName占比 $topPercentage%，是当前最投入的活动。',
      if (longestMinutes > 120)
        '最长连续记录为 ${formatStatsDuration(Duration(minutes: longestMinutes))}，建议每 90 分钟安排一次短暂休息。'
      else
        '当前最长连续记录为 ${formatStatsDuration(Duration(minutes: longestMinutes))}，节奏保持得不错。',
      if (totalMinutes < 120)
        '记录时间较短，建议安排一个完整的专注时段。'
      else
        '保持规律记录，能让下一次分析更贴合你的时间分配。',
    ];
  }

  Widget _buildEmptyState(List<Color> gradientColors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgIcons.sparkle(),
            const SizedBox(height: 8),
            const Text(
              '暂无数据',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '还没有足够的记录来生成分析。开始记录你的时间吧！',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFA5B4FC),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
