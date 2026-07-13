# MyTime AI 配置与建议设计规格

**文档状态：** 已按当前实现同步。此功能是可选的：未配置或请求失败时，统计页仍提供本地规则建议。

## 1. 目标

用户可以填写 OpenAI-compatible 服务地址、API Key 和模型名称，针对本日、本周或本月的统计生成简体中文总结与建议。

## 2. 安全与隐私约束

- 请求只能发往 HTTPS 服务地址；`AiInsightService` 会拒绝 HTTP、相对地址和无 host 地址。
- API Key 在静态存储时只保存在平台安全存储中，不保存在 SharedPreferences、导出 JSON、日志或版本控制文件中。
- 升级用户的旧版 SharedPreferences 明文 key 会在首次成功读取后迁移到安全存储，并删除旧值。
- 请求内容只包含统计周期、总时长、记录数、按分类标识聚合的时长/占比，以及最长单次时长；不包含原始备注、记录 ID 或完整数据库。
- API Key 可短暂存在于表单控制器和运行时 `AppSettings` 中以发起请求，但不应出现在 UI 摘要、错误文案或测试输出中。

## 3. 配置与持久化

`AppSettings` 包含 `aiBaseUrl`、`aiApiKey` 和 `aiModel`：

| 值 | 持久化位置 |
| --- | --- |
| 服务地址 | `PreferencesStore` / SharedPreferences |
| 模型名称 | `PreferencesStore` / SharedPreferences |
| API Key | `SecureKeyValueStore` / `flutter_secure_storage` |

`SettingsRepository` 负责跨两个存储边界读取、保存和迁移；BLoC 与 Widget 不直接访问安全存储。配置页以 24px 圆角 Bottom Sheet 提供服务地址、密码输入的 API Key、模型名称、测试连接和保存按钮。

## 4. 请求与错误处理

`AiInsightService`：

1. 将用户填写的 Base URL 规范为 `{baseUrl}/chat/completions`。
2. 以 `Authorization: Bearer <key>` 和 JSON Content-Type 发起 OpenAI-compatible `POST` 请求。
3. 使用用户提供的模型，并向模型要求“第一行总结，后续每行一条简短建议”。
4. 解析 `choices[0].message.content`，将第一行作为总结，其余行作为建议。
5. 将超时、网络、HTTP 状态和响应格式错误转换为不包含密钥的用户可见错误。

只有在用户已配置且当前周期有记录时，统计页会自动请求。未配置、请求失败或服务返回无法解析的数据时，UI 会继续展示本地规则建议；用户可以通过“重新生成建议”再次请求或轮换本地建议。

## 5. 文件边界

- `lib/data/models/app_settings.dart`：设置值对象。
- `lib/data/repositories/settings_repository.dart`：普通设置、安全 key 和旧 key 迁移。
- `lib/data/providers/preferences_store.dart`：普通偏好 Port 与 SharedPreferences Adapter。
- `lib/blocs/settings/`：加载和保存设置状态。
- `lib/data/services/ai_insight_service.dart`：HTTPS 请求、解析和安全错误映射。
- `lib/ui/pages/settings/widgets/ai_model_config_sheet.dart`：配置输入和连接测试。
- `lib/ui/pages/stats/widgets/ai_insight_view.dart`：加载、成功、失败和本地兜底视图。

## 6. 验收与限制

- API Key 在重新启动后能从安全存储读取，旧明文 key 不会被保留。
- 非 HTTPS 地址不能产生外部请求。
- 请求失败时不泄露 API Key，统计页仍能使用本地建议。
- 本功能不实现模型供应商账户、同步、请求缓存或费用控制；用户需自行管理 API 服务商、配额和数据处理政策。
