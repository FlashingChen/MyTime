# AI Configuration and Real Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users configure an OpenAI-compatible model and generate real, range-scoped AI time insights with a local fallback.

**Architecture:** Persist endpoint, key, and model through `SettingsBloc`. Keep HTTP and response parsing in a data service behind an injectable request function. The settings sheet owns draft input and connection testing; `AiInsightView` uses the service while retaining the existing rules as an offline fallback.

**Tech Stack:** Flutter/Dart, flutter_bloc, SharedPreferences, `dart:io` HttpClient, flutter_test.

## Global Constraints

- Do not add dependencies; use `dart:io` for HTTP.
- All copy is Simplified Chinese; use existing 12px cards and 24px sheets.
- Use only `POST {baseUrl}/chat/completions` with an OpenAI-compatible JSON body.
- Never render, log, commit, or include the API Key in an error message.
- Submit only clipped current-range aggregates; never send notes, IDs, or raw timestamps.
- Preserve local rule suggestions for unconfigured and failed requests.
- Update the prototype and changelog; finish with `flutter analyze` and `flutter test`.

---

## File structure

- `lib/data/models/app_settings.dart`: adds `aiBaseUrl`.
- `lib/data/repositories/settings_repository.dart`: persists all AI fields.
- `lib/blocs/settings/*`: atomically applies AI settings.
- `lib/data/services/ai_insight_service.dart`: HTTP, prompt, parser, safe exceptions.
- `lib/ui/pages/settings/widgets/ai_model_config_sheet.dart`: validation, test, save UI.
- `lib/ui/pages/settings/settings_page.dart`: sheet launcher and model summary.
- `lib/ui/pages/stats/stats_page.dart` and `widgets/ai_insight_view.dart`: real and fallback insights.

### Task 1: Persist and expose AI configuration

**Files:**
- Modify: `lib/data/models/app_settings.dart`, `lib/data/repositories/settings_repository.dart`, `lib/blocs/settings/settings_event.dart`, `lib/blocs/settings/settings_bloc.dart`
- Create: `test/data/repositories/settings_repository_test.dart`, `test/blocs/settings/settings_bloc_test.dart`

**Interfaces:**
- Produces `AppSettings.aiBaseUrl: String` and `copyWith({String? aiBaseUrl, String? aiApiKey, String? aiModel})`.
- Produces `AiSettingsChanged({required String baseUrl, required String apiKey, required String model})`.

- [ ] **Step 1: Write failing persistence tests**

```dart
test('saves and loads complete AI configuration', () async {
  SharedPreferences.setMockInitialValues({});
  final repository = SettingsRepository();
  const expected = AppSettings(
    aiBaseUrl: 'https://api.example.com/v1',
    aiApiKey: 'test-key',
    aiModel: 'test-model',
  );
  await repository.save(expected);
  expect(await repository.load(), expected);
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `flutter test test/data/repositories/settings_repository_test.dart`

Expected: fails because `aiBaseUrl` does not exist.

- [ ] **Step 3: Implement model, persistence, and BLoC event**

```dart
class AiSettingsChanged extends SettingsEvent {
  const AiSettingsChanged({required this.baseUrl, required this.apiKey, required this.model});
  final String baseUrl;
  final String apiKey;
  final String model;
  @override
  List<Object?> get props => [baseUrl, apiKey, model];
}

final updated = current.copyWith(
  aiBaseUrl: event.baseUrl, aiApiKey: event.apiKey, aiModel: event.model,
);
await _repository.save(updated);
emit(SettingsLoaded(updated));
```

Read/write `ai_base_url`; write empty strings for cleared optional values.

- [ ] **Step 4: Verify persistence and BLoC**

Run: `flutter test test/data/repositories/settings_repository_test.dart test/blocs/settings/settings_bloc_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run: `git add lib/data/models/app_settings.dart lib/data/repositories/settings_repository.dart lib/blocs/settings test/data/repositories/settings_repository_test.dart test/blocs/settings/settings_bloc_test.dart && git commit -m "Persist AI model configuration"`

### Task 2: Build the OpenAI-compatible insight service

**Files:**
- Create: `lib/data/services/ai_insight_service.dart`, `test/data/services/ai_insight_service_test.dart`

**Interfaces:**
- Produces `AiConfiguration({required String baseUrl, required String apiKey, required String model})`.
- Produces `AiGeneratedInsight({required String summary, required List<String> suggestions})`.
- Produces `Future<AiGeneratedInsight> AiInsightService.generate({required AiConfiguration configuration, required String periodLabel, required StatsMetrics metrics})`.

- [ ] **Step 1: Write failing parser and HTTP tests**

```dart
test('normalizes endpoint and parses model content', () async {
  final service = AiInsightService(request: (uri, headers, body) async {
    expect(uri.toString(), 'https://api.example.com/v1/chat/completions');
    expect(headers['Authorization'], 'Bearer secret');
    return const AiHttpResponse(200, '{"choices":[{"message":{"content":"总结\\n建议一"}}]}');
  });
  final insight = await service.generate(
    configuration: const AiConfiguration(baseUrl: 'https://api.example.com/v1/', apiKey: 'secret', model: 'model'),
    periodLabel: '本周', metrics: fixtureMetrics,
  );
  expect(insight.summary, '总结');
  expect(insight.suggestions, ['建议一']);
});
```

- [ ] **Step 2: Run the test and verify it fails**

Run: `flutter test test/data/services/ai_insight_service_test.dart`

Expected: fails because `AiInsightService` is undefined.

- [ ] **Step 3: Implement service and safe failure handling**

```dart
final endpoint = Uri.parse(
  configuration.baseUrl.replaceFirst(RegExp(r'/+$'), '') + '/chat/completions',
);
if (response.statusCode < 200 || response.statusCode >= 300) {
  throw AiInsightException('服务返回 HTTP ${response.statusCode}');
}
final content = decoded['choices']?[0]?['message']?['content'];
```

Use `HttpClient` in a `try/finally` that closes it. Post `model` and Chinese system/user messages. The prompt contains only total duration, record count, category durations/percentages, and longest duration. Convert socket, timeout, malformed JSON, no choices, and empty content to fixed safe Chinese messages. First non-empty line is summary; later lines are suggestions; a single line is both summary and one suggestion.

- [ ] **Step 4: Verify service cases**

Run: `flutter test test/data/services/ai_insight_service_test.dart`

Expected: PASS for success, trailing slash, HTTP error, malformed JSON, empty choices, and empty content.

- [ ] **Step 5: Commit**

Run: `git add lib/data/services/ai_insight_service.dart test/data/services/ai_insight_service_test.dart && git commit -m "Add AI insight service"`

### Task 3: Add configuration sheet and settings entry

**Files:**
- Create: `lib/ui/pages/settings/widgets/ai_model_config_sheet.dart`
- Modify: `lib/ui/pages/settings/settings_page.dart`, `test/ui/pages/settings/settings_page_test.dart`

**Interfaces:**
- Produces `AiModelConfigSheet.show(BuildContext context, AppSettings settings, AiInsightService service)`.

- [ ] **Step 1: Write failing settings widget test**

```dart
await tester.tap(find.text('AI 模型配置'));
await tester.pumpAndSettle();
expect(find.text('服务地址'), findsOneWidget);
expect(find.text('API Key'), findsOneWidget);
expect(find.text('模型名称'), findsOneWidget);
expect(find.text('测试连接'), findsOneWidget);
expect(find.text('保存配置'), findsOneWidget);
```

- [ ] **Step 2: Run test and verify it fails**

Run: `flutter test test/ui/pages/settings/settings_page_test.dart`

Expected: fails because the current entry opens only a SnackBar.

- [ ] **Step 3: Implement form, validation, testing, and save**

```dart
final uri = Uri.tryParse(_baseUrl.text.trim());
final valid = uri != null && uri.hasAuthority &&
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    _apiKey.text.trim().isNotEmpty && _model.text.trim().isNotEmpty;

context.read<SettingsBloc>().add(AiSettingsChanged(
  baseUrl: _baseUrl.text.trim(), apiKey: _apiKey.text.trim(), model: _model.text.trim(),
));
```

Use a 24px bottom sheet with URL, obscured key with visibility toggle, and model fields. Disable test/save for invalid input and while a test is active. Test unsaved controller values; render only `连接成功` or `连接失败：<safe message>`. Saving closes the sheet and the list trailing value renders the model name.

- [ ] **Step 4: Verify settings UI**

Run: `flutter test test/ui/pages/settings/settings_page_test.dart`

Expected: PASS for validation, save, and model-name summary.

- [ ] **Step 5: Commit**

Run: `git add lib/ui/pages/settings/widgets/ai_model_config_sheet.dart lib/ui/pages/settings/settings_page.dart test/ui/pages/settings/settings_page_test.dart && git commit -m "Add AI model configuration sheet"`

### Task 4: Generate configured insights with offline fallback

**Files:**
- Modify: `lib/ui/pages/stats/stats_page.dart`, `lib/ui/pages/stats/widgets/ai_insight_view.dart`
- Create: `test/ui/pages/stats/widgets/ai_insight_view_test.dart`

**Interfaces:**
- `AiInsightView` consumes `AppSettings settings`, `StatsMetrics metrics`, `String periodLabel`, and injectable `AiInsightService service`.

- [ ] **Step 1: Write failing AI view tests**

```dart
expect(find.text('模型总结'), findsOneWidget);
expect(find.text('模型建议'), findsOneWidget);
expect(find.text('由模型生成'), findsOneWidget);

expect(find.textContaining('连接失败'), findsOneWidget);
expect(find.byKey(const ValueKey('ai-suggestion-0')), findsOneWidget);
```

Use a fake success service for the first expectation and a fake failing service for the second.

- [ ] **Step 2: Run test and verify it fails**

Run: `flutter test test/ui/pages/stats/widgets/ai_insight_view_test.dart`

Expected: fails because the widget only rotates local suggestions.

- [ ] **Step 3: Implement generation lifecycle**

Compose `RecordsBloc` metrics and `SettingsBloc` settings in `StatsPage`. In `AiInsightView`, call `_generate()` in `initState` when Base URL, key, and model are all non-empty, and call it from “重新生成建议”. Render a button progress state; on success render model output and `由模型生成`; on exception render `连接失败：<safe message>` plus the existing local suggestions; on missing config render `尚未配置 AI 模型` and `请前往“我的 → AI 模型配置”完成设置。` plus local suggestions.

- [ ] **Step 4: Verify stat-page behavior**

Run: `flutter test test/ui/pages/stats/widgets/ai_insight_view_test.dart test/ui/pages/stats/stats_page_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

Run: `git add lib/ui/pages/stats/stats_page.dart lib/ui/pages/stats/widgets/ai_insight_view.dart test/ui/pages/stats/widgets/ai_insight_view_test.dart && git commit -m "Generate configured AI insights"`

### Task 5: Synchronize documentation and verify

**Files:**
- Modify: `design-demos/mytime-prototype.html`, `CHANGELOG.md`

- [ ] **Step 1: Update the prototype**

Add a configuration-sheet mock for Base URL, hidden key, model, connection result, and save. Make the AI tab distinguish configured model content, request failure with local fallback, and unconfigured guidance.

- [ ] **Step 2: Update changelog**

Add `[Unreleased]` entries for configuration, connection testing, model-generated insights, and offline fallback.

- [ ] **Step 3: Run full verification**

Run: `flutter analyze && flutter test`

Expected: both commands exit 0.

- [ ] **Step 4: Commit**

Run: `git add design-demos/mytime-prototype.html CHANGELOG.md && git commit -m "Document configurable AI insights"`

## Plan self-review

- Persistence and BLoC: Task 1; safe compatible HTTP and parsing: Task 2; configuration UX: Task 3; real-generation states and fallback: Task 4; prototype, changelog, and full checks: Task 5.
- The public names used by later tasks are declared by earlier tasks.
- No deferred work markers or incomplete steps remain in this plan.
