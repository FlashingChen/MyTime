import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/services/ai_insight_service.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

void main() {
  final metrics = StatsMetrics.forRange(
    [
      TimeRecord(
        id: 'record',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 6, 9),
        endTime: DateTime(2026, 7, 6, 11),
      ),
    ],
    StatsRange.week,
    DateTime(2026, 7, 8),
  );
  const config = AiConfiguration(
    baseUrl: 'https://api.example.com/v1/',
    apiKey: 'secret',
    model: 'test-model',
  );

  test('normalizes endpoint and parses model content', () async {
    final service = AiInsightService(
      request: (uri, headers, body) async {
        expect(uri.toString(), 'https://api.example.com/v1/chat/completions');
        expect(headers['Authorization'], 'Bearer secret');
        expect(body, contains('test-model'));
        return const AiHttpResponse(
          200,
          '{"choices":[{"message":{"content":"模型总结\\n建议一\\n建议二"}}]}',
        );
      },
    );

    final insight = await service.generate(
      configuration: config,
      periodLabel: '本周',
      metrics: metrics,
    );

    expect(insight.summary, '模型总结');
    expect(insight.suggestions, ['建议一', '建议二']);
  });

  test('uses a safe message for HTTP errors', () async {
    final service = AiInsightService(
      request: (_, __, ___) async => const AiHttpResponse(401, '{}'),
    );

    expect(
      () => service.generate(
        configuration: config,
        periodLabel: '本周',
        metrics: metrics,
      ),
      throwsA(
        isA<AiInsightException>().having(
          (error) => error.message,
          'message',
          '服务返回 HTTP 401',
        ),
      ),
    );
  });
}
