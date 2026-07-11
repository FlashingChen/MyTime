import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/services/ai_insight_service.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Shows generated AI insight when configured, with local advice as fallback.
class AiInsightView extends StatefulWidget {
  const AiInsightView({
    super.key,
    required this.records,
    this.periodLabel = '本周',
    this.settings = const AppSettings(),
    this.service,
  });

  final List<TimeRecord> records;
  final String periodLabel;
  final AppSettings settings;
  final AiInsightService? service;

  @override
  State<AiInsightView> createState() => _AiInsightViewState();
}

class _AiInsightViewState extends State<AiInsightView> {
  int _suggestionOffset = 0;
  bool _loading = false;
  String? _error;
  AiGeneratedInsight? _generated;

  bool get _configured =>
      widget.settings.aiBaseUrl.isNotEmpty &&
      (widget.settings.aiApiKey?.isNotEmpty ?? false) &&
      (widget.settings.aiModel?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    if (_configured && widget.records.isNotEmpty) _generate();
  }

  Future<void> _generate() async {
    if (!_configured || widget.records.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final metrics = StatsMetrics.forRange(
        widget.records,
        _rangeForLabel(widget.periodLabel),
        now,
      );
      final generated = await (widget.service ?? AiInsightService()).generate(
        configuration: AiConfiguration(
          baseUrl: widget.settings.aiBaseUrl,
          apiKey: widget.settings.aiApiKey!,
          model: widget.settings.aiModel!,
        ),
        periodLabel: widget.periodLabel,
        metrics: metrics,
      );
      if (mounted) setState(() => _generated = generated);
    } on AiInsightException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  StatsRange _rangeForLabel(String label) => switch (label) {
    '今日' => StatsRange.day,
    '本月' => StatsRange.month,
    _ => StatsRange.week,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.isDark
        ? const [Color(0xFF313152), Color(0xFF1E1E32)]
        : const [AppColors.primaryDark, Color(0xFF2D2D44)];
    if (widget.records.isEmpty) return _empty(colors);

    final local = _localSuggestions(context);
    final shown =
        _generated?.suggestions ??
        List.generate(
          2,
          (index) => local[(_suggestionOffset + index) % local.length],
        );
    final total = widget.records.fold<int>(
      0,
      (sum, record) => sum + record.duration.inMinutes,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
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
                  _generated?.summary ??
                      '${widget.periodLabel}你共记录 ${formatStatsDuration(Duration(minutes: total))} 的活动，共 ${widget.records.length} 条记录。',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA5B4FC),
                    height: 1.6,
                  ),
                ),
                if (_generated != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '由模型生成',
                      style: TextStyle(fontSize: 10, color: Color(0xFFA5B4FC)),
                    ),
                  ),
                if (!_configured)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '尚未配置 AI 模型\n请前往“我的 → AI 模型配置”完成设置。',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA5B4FC),
                        height: 1.5,
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '连接失败：$_error',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFFC4C4),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                for (final (index, suggestion) in shown.indexed)
                  _suggestion(index, suggestion),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading
                  ? null
                  : (_configured
                        ? _generate
                        : () => setState(
                            () => _suggestionOffset =
                                (_suggestionOffset + 1) % local.length,
                          )),
              child: Text(_loading ? '生成中...' : '重新生成建议'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestion(int index, String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      key: ValueKey('ai-suggestion-$index'),
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFFA5B4FC),
        height: 1.5,
      ),
    ),
  );

  List<String> _localSuggestions(BuildContext context) {
    final categories = <String, int>{};
    var total = 0;
    var longest = 0;
    for (final record in widget.records) {
      final minutes = record.duration.inMinutes;
      total += minutes;
      longest = minutes > longest ? minutes : longest;
      final id = record.categoryId ?? 'uncategorized';
      categories[id] = (categories[id] ?? 0) + minutes;
    }
    final top = categories.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final name = CategoryLookup.byId(context, top.key).name;
    return [
      '$name占比 ${top.value * 100 ~/ total}%，是当前最投入的活动。',
      '最长连续记录为 ${formatStatsDuration(Duration(minutes: longest))}，建议每 90 分钟安排一次短暂休息。',
      '保持规律记录，能让下一次分析更贴合你的时间分配。',
    ];
  }

  Widget _empty(List<Color> colors) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '暂无数据',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '还没有足够的记录来生成分析。开始记录你的时间吧！',
            style: TextStyle(fontSize: 12, color: Color(0xFFA5B4FC)),
          ),
        ],
      ),
    ),
  );
}
