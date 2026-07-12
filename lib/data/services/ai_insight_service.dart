import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mytime/ui/pages/stats/stats_metrics.dart';

/// Saved connection values for an OpenAI-compatible chat completion service.
class AiConfiguration {
  const AiConfiguration({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isComplete =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;
}

/// The summary and suggestions returned by a configured AI model.
class AiGeneratedInsight {
  const AiGeneratedInsight({required this.summary, required this.suggestions});

  final String summary;
  final List<String> suggestions;
}

/// A safe, user-displayable error generated while requesting AI insight.
class AiInsightException implements Exception {
  const AiInsightException(this.message);

  final String message;
}

/// A small HTTP response abstraction that keeps requests testable.
class AiHttpResponse {
  const AiHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

typedef AiRequest =
    Future<AiHttpResponse> Function(
      Uri uri,
      Map<String, String> headers,
      String body,
    );

/// Requests and parses time insights from an OpenAI-compatible endpoint.
class AiInsightService {
  AiInsightService({AiRequest? request}) : _request = request ?? _httpRequest;

  final AiRequest _request;

  Future<AiGeneratedInsight> generate({
    required AiConfiguration configuration,
    required String periodLabel,
    required StatsMetrics metrics,
  }) async {
    final endpoint = _endpoint(configuration.baseUrl);
    if (!configuration.isComplete || endpoint == null) {
      throw const AiInsightException('请先完成 AI 模型配置');
    }

    try {
      final response = await _request(
        endpoint,
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer ${configuration.apiKey}',
        },
        jsonEncode({
          'model': configuration.model,
          'messages': [
            {
              'role': 'system',
              'content': '你是时间管理助手。只用简体中文输出：第一行是总结，后续每行是一条简短建议。',
            },
            {'role': 'user', 'content': _prompt(periodLabel, metrics)},
          ],
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiInsightException('服务返回 HTTP ${response.statusCode}');
      }
      return _parse(response.body);
    } on AiInsightException {
      rethrow;
    } on TimeoutException {
      throw const AiInsightException('请求超时，请稍后重试');
    } on SocketException {
      throw const AiInsightException('网络连接失败，请检查服务地址和网络');
    } on HttpException {
      throw const AiInsightException('服务连接失败，请检查服务地址');
    } on FormatException {
      throw const AiInsightException('服务返回的数据格式无效');
    } catch (_) {
      throw const AiInsightException('生成建议失败，请稍后重试');
    }
  }

  /// Verifies that the configured endpoint accepts a minimal chat request.
  Future<void> testConnection(AiConfiguration configuration) async {
    final endpoint = _endpoint(configuration.baseUrl);
    if (!configuration.isComplete || endpoint == null) {
      throw const AiInsightException('请填写有效的 AI 配置');
    }
    try {
      final response = await _request(
        endpoint,
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer ${configuration.apiKey}',
        },
        jsonEncode({
          'model': configuration.model,
          'messages': [
            {'role': 'user', 'content': '请回复“连接成功”。'},
          ],
          'max_tokens': 8,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiInsightException('服务返回 HTTP ${response.statusCode}');
      }
    } on AiInsightException {
      rethrow;
    } on TimeoutException {
      throw const AiInsightException('请求超时，请稍后重试');
    } on SocketException {
      throw const AiInsightException('网络连接失败，请检查服务地址和网络');
    } on HttpException {
      throw const AiInsightException('服务连接失败，请检查服务地址');
    } catch (_) {
      throw const AiInsightException('连接失败，请检查配置信息');
    }
  }

  static Uri? _endpoint(String baseUrl) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      return null;
    }
    return Uri.parse('$normalized/chat/completions');
  }

  static String _prompt(String periodLabel, StatsMetrics metrics) {
    final categories = metrics.byCategory.entries
        .map((entry) {
          final percentage = metrics.total.inMinutes == 0
              ? 0
              : entry.value.inMinutes * 100 ~/ metrics.total.inMinutes;
          return '${entry.key}：${formatStatsDuration(entry.value)}（$percentage%）';
        })
        .join('；');
    final longest = metrics.records.fold<Duration>(
      Duration.zero,
      (value, record) => record.duration > value ? record.duration : value,
    );
    return '$periodLabel时间统计：总时长 ${formatStatsDuration(metrics.total)}，'
        '记录 ${metrics.records.length} 条，分类分布：$categories，'
        '最长单次记录 ${formatStatsDuration(longest)}。请给出总结和可执行建议。';
  }

  static AiGeneratedInsight _parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const AiInsightException('服务返回的数据格式无效');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const AiInsightException('服务未返回建议内容');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const AiInsightException('服务未返回建议内容');
    }
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) throw const AiInsightException('服务未返回建议内容');
    return AiGeneratedInsight(
      summary: lines.first,
      suggestions: lines.length == 1 ? [lines.first] : lines.skip(1).toList(),
    );
  }

  static Future<AiHttpResponse> _httpRequest(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 15));
      headers.forEach(request.headers.set);
      request.write(body);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await utf8.decoder.bind(response).join();
      return AiHttpResponse(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }
}
