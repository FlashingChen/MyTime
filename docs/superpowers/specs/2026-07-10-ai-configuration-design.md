# MyTime 真实 AI 配置与建议设计规格

## 1. 目标

将当前统计页的本地规则建议升级为可配置的 OpenAI-compatible AI 建议：用户可在设置页填写服务地址、API Key 和模型名，并在本日、本周、本月统计范围内生成中文时间总结与改进建议。

## 2. 范围与约束

- 不新增第三方依赖；请求使用 Dart `dart:io` 的 `HttpClient`。
- 保留现有 BLoC、Hive 与 `SharedPreferences` 结构。
- 配置保存于本地 `SharedPreferences`；API Key 仅以密码输入框显示，不出现在页面摘要、日志或错误文案中。
- 支持 OpenAI-compatible `POST {baseUrl}/chat/completions` 接口；`baseUrl` 可带或不带尾部 `/`。
- 未配置、网络失败、HTTP 非 2xx 或响应无法解析时，显示具体但不泄露密钥的状态，并继续提供本地规则建议作为兜底。
- 不在客户端内置任何 API Key、默认供应商地址或模型名称。

## 3. 方案选择

采用通用 OpenAI-compatible API（推荐）：一个配置页兼容 OpenAI 及其兼容服务，避免将产品绑定到单一供应商。仅支持官方 OpenAI 会限制用户选择；只保存配置而不发请求无法满足真实 AI 建议的目标。

## 4. 配置与数据流

### 4.1 数据模型与持久化

`AppSettings` 新增不可空的 `aiBaseUrl`（默认空字符串）；保留可空 `aiApiKey`、`aiModel`。`SettingsRepository` 读取并保存 `ai_base_url`、`ai_api_key`、`ai_model`。新增 `AiSettingsChanged` BLoC 事件，原子保存三个值并更新 `SettingsLoaded`。

### 4.2 设置页

点击“AI 模型配置”打开 24px 圆角 Bottom Sheet，包含：

1. 服务地址（必填，URL 键盘）；
2. API Key（必填，密码输入，可切换可见性）；
3. 模型名称（必填，例如由用户的服务商提供）；
4. “测试连接”次级按钮和“保存配置”主按钮。

字段为空或服务地址不是绝对 `http/https` URL 时禁用测试与保存，并显示输入校验文案。测试连接以当前未保存输入发送最小 `chat/completions` 请求；成功显示“连接成功”，失败显示 HTTP 状态或网络错误，不显示响应体和 Key。保存不自动测试。

### 4.3 AI 请求服务

新增 `AiInsightService`，构造参数为 `AiConfiguration`。它负责：

- 标准化 endpoint 为 `{baseUrl}/chat/completions`；
- 以 `Authorization: Bearer <key>` 和 JSON Content-Type 发起 POST；
- 传入模型名，以及只含已聚合时间数据的中文 prompt（周期、总时长、记录数、各分类时长与占比、最长单次记录）；
- 从 OpenAI 响应的 `choices[0].message.content` 读取文本；
- 将空内容、无 choices、格式错误和 HTTP 错误转化为可显示的 `AiInsightException`。

模型返回内容按两段中文纯文本显示：第一段为总结，其余为建议。为避免模型格式差异，若内容没有换行，整段作为一条建议显示。客户端不执行模型返回的指令，也不发送原始备注、记录 ID 或 API Key。

### 4.4 统计页 AI 视图

`AiInsightView` 接收当前 `AppSettings` 和 `AiInsightService`。加载状态显示按钮内进度；已配置时首次进入及“重新生成建议”都会调用真实服务。调用成功后显示模型总结和建议，并标注“由模型生成”；调用失败时显示失败原因与本地规则建议。未配置时显示“尚未配置 AI 模型”，并保留本地规则建议，同时提供引导用户前往“我的 → AI 模型配置”的文案。

本地规则建议继续只使用裁剪后的当前周期记录，作为无网络和无配置时的可靠兜底。

## 5. 文件边界

- `lib/data/models/app_settings.dart`：配置值对象。
- `lib/data/repositories/settings_repository.dart`：本地配置读写。
- `lib/blocs/settings/*`：设置保存事件和状态更新。
- `lib/data/services/ai_insight_service.dart`：HTTP、请求/响应解析与异常；不依赖 Widget 或 BLoC。
- `lib/ui/pages/settings/widgets/ai_model_config_sheet.dart`：配置输入、校验、测试连接。
- `lib/ui/pages/settings/settings_page.dart`：打开配置 Sheet，显示已配置模型名。
- `lib/ui/pages/stats/widgets/ai_insight_view.dart`：真实结果、加载/失败/未配置和本地兜底 UI。
- `design-demos/mytime-prototype.html`、`CHANGELOG.md`：原型与变更记录同步。

## 6. 测试与验收

### 单元测试

- `SettingsRepository` 能保存并重新读取 Base URL、Key、模型名。
- `AiInsightService` 对 endpoint 规范化、请求头、成功响应、空响应、HTTP 错误和 JSON 格式错误进行测试。服务通过可注入 HTTP 客户端/请求函数隔离网络。

### Widget 测试

- 点击“AI 模型配置”打开配置 Sheet；无效地址和空字段不可保存。
- 保存后设置列表展示模型名，重启/重建 BLoC 后配置仍存在。
- `AiInsightView` 在成功、加载、未配置和失败时显示相应文案；失败时仍显示本地建议。

### 验收

- 以任意 OpenAI-compatible 服务填写 Base URL、Key、模型名，测试连接成功。
- 在统计的本日/本周/本月切换后，模型提示只使用对应周期的聚合数据。
- API Key 不出现在 UI 摘要、错误消息、测试输出或版本控制文件中。
- 运行 `flutter analyze` 与 `flutter test` 均通过。
