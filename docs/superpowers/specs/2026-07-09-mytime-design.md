# MyTime — MVP 设计规格文档

**文档状态：** 已按当前实现同步。本文描述当前 MVP 的产品行为和技术边界；未来能力会明确标为“计划中”，不应被视为已发布功能。

## 1. 项目概述

MyTime 是开源免费、纯本地优先的时间记录应用。用户通过开始/停止记录一段时间，随后补充分类和备注；应用以时间线和统计帮助用户回顾时间分配。

当前重点是 Android MVP。iOS 工程使用本地私有签名配置并已通过无签名构建；真机部署仍取决于已连接、解锁的设备。WebDAV 提供显式手动同步，不提供后台自动同步。

## 2. 技术栈与边界

| 层面 | 当前选型 | 说明 |
| --- | --- | --- |
| 框架 | Flutter / Dart | 单代码库面向 Android 与 iOS。 |
| 状态管理 | BLoC (`flutter_bloc`) | 计时、记录、分类和设置分别管理。 |
| 领域模型 | Equatable 纯 Dart 值对象 | `TimeRecord` / `Category` 不依赖 Hive。 |
| 本地记录 | Hive CE DTO + DataStore Adapter | Hive 仅位于 DTO/Adapter 层。 |
| 普通设置 | SharedPreferences + `PreferencesStore` | 用于主题、非敏感 AI 配置和活动会话。 |
| 敏感设置 | `flutter_secure_storage` | 用于 AI API Key 与 WebDAV 密码。 |
| 导航 | `IndexedStack` + Material Navigator | 当前未使用 GoRouter。 |
| 图表 | fl_chart | 饼图和趋势图。 |
| AI | HTTPS OpenAI-compatible API | 只在用户完成配置后请求；本地规则建议兜底。 |

完整架构见 [当前架构与存储边界](../../architecture.md)。

## 3. 项目结构

```text
lib/
├── blocs/                  # timer / records / categories / settings
├── core/                   # 主题、默认分类、工具
├── data/
│   ├── models/             # 纯 Dart 领域模型
│   ├── dtos/               # Hive DTO 与生成的 Adapter
│   ├── providers/          # DataStore / PreferencesStore Port 与实现
│   ├── repositories/       # Repository Port 与业务校验
│   ├── services/           # AI 与导入/导出
│   └── sync/               # SyncPort、WebDAV Adapter、版本与冲突编排
├── ui/pages/               # home / timeline / stats / settings / splash
├── widgets/                # 公共 SVG 图标
└── main.dart               # 依赖组装与应用启动
```

## 4. 数据模型

### TimeRecord

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | UUID；导入时必须唯一。 |
| `categoryId` | `String?` | 可为空；分类删除后会清空。 |
| `startTime` | `DateTime` | 开始时间。 |
| `endTime` | `DateTime` | 结束时间，必须晚于开始时间。 |
| `note` | `String?` | 可选备注。 |
| `createdAt` | `DateTime` | 记录创建时间。 |

### Category

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | 唯一标识。 |
| `name` | `String` | 非空名称。 |
| `color` | `String` | `#RRGGBB` 颜色值。 |

首次启动会写入工作、阅读、运动、学习、社交、休息、创作、其他八个默认分类。所有分类都可编辑或删除，但系统必须始终保留至少一个分类；删除分类后，其历史记录显示为“未分类”。

### AppSettings

| 字段 | 类型 | 存储位置 |
| --- | --- | --- |
| `accentColor` | `String` | SharedPreferences |
| `themeMode` | `String` | SharedPreferences |
| `aiBaseUrl` | `String` | SharedPreferences |
| `aiModel` | `String?` | SharedPreferences |
| `aiApiKey` | `String?` | 平台安全存储 |
| `webDavEndpoint` | `String` | SharedPreferences |
| `webDavUsername` | `String` | SharedPreferences |
| `webDavPassword` | `String?` | 平台安全存储 |

## 5. 页面与交互

### 5.1 首页 — 计时器

- 空闲状态显示当前日期、`00:00`、开始按钮和最近记录。
- 运行状态显示渐变圆环、秒级更新的计时数字和红色停止按钮；开始时间会立即异步持久化。
- 停止时捕获固定的结束时间，进入待确认状态。确认页展示该固定的开始/结束/时长，用户可选择分类、填写备注、确认保存或放弃记录。
- 运行中或待确认会话会在应用重启后恢复；记录成功保存才清除会话。

### 5.2 时间线 — 全天日视图

- 日期导航、0:00–24:00 的纵向时间轴和按时间定位的事件卡片。
- 支持双指缩放、双击恢复默认比例和滚动浏览全天。
- 记录按时间区间与所选日期是否重叠来显示；跨午夜记录会裁剪为当日可见片段。

周视图与记录详情 Sheet 仍是计划项，不应在原型或功能说明中标为已完成。

### 5.3 统计

- 支持本日 / 本周 / 本月范围。
- 三张摘要卡、分类占比饼图、趋势图和 AI 建议。
- 饼图的选中项由分类 ID 追踪，数据变更后安全清除无效选中态。
- AI 未配置、网络失败或服务返回异常时，仍显示本地规则建议。

### 5.4 我的与设置

- 深色/浅色模式和自定义主题色。
- 记录管理：新增、编辑和删除本地记录。
- 分类管理：新增、编辑和删除分类。
- AI 模型配置：服务地址、API Key、模型名称和连接测试；实际请求仅允许 HTTPS。
- 数据导入导出：JSON 剪贴板导出，或从剪贴板导入经过完整校验的 JSON。
- WebDAV 同步：保存 HTTPS 服务器地址、用户名和密码后可手动同步；服务器地址自动追加 `/sync.json`（以 `.json` 结尾时视为完整文档地址）。合并与冲突裁决详见 [前台持有 WebDAV 同步设计](2026-07-24-foreground-owned-webdav-sync-design.md)。
- 关于页面显示应用版本与项目说明。

### 5.5 底部导航

首页 / 时间线 / 统计 / 我的四个 Tab，通过 `IndexedStack` 保留页面状态。

## 6. 设计风格

- 主深色：`#1A1A2E`；强调渐变：`#6366F1` → `#8B5CF6`。
- 背景：`#F8F9FA`；卡片：`#FFFFFF`。
- 卡片圆角 12px，弹窗和 Bottom Sheet 顶部圆角 24px，主按钮为圆形或 12px 圆角。
- 使用 SVG 图标或 Flutter 图标，不使用 emoji。
- 支持深浅色主题；关键点击区域需保持至少 44 × 44 的命中面积。

## 7. MVP 状态

| 功能 | 状态 |
| --- | --- |
| 开始/停止/确认计时与会话恢复 | 已实现 |
| 分类、备注、记录管理 | 已实现 |
| 全天日时间线与跨午夜显示 | 已实现 |
| 统计、趋势、AI 本地兜底 | 已实现 |
| HTTPS OpenAI-compatible AI 请求 | 已实现（用户自行配置） |
| JSON 导入导出与回滚 | 已实现 |
| HTTPS WebDAV 手动同步与完整快照冲突策略 | 已实现（用户自行配置） |
| Android 本地 Release 签名配置 | 已实现（私有 keystore） |
| iOS 无签名构建 | 已验证（Swift Package Manager） |
| iOS 真机/发布验证 | 取决于已连接、解锁设备 |
| 周视图、记录详情 Sheet | 计划中 |
| WebDAV 后台同步、ETag/锁与逐记录合并 | 计划中 |
| 设备级持久化端到端测试 | 已提供隔离数据测试；真机执行取决于设备连接 |

## 8. 原型与验证

交互原型位于 `design-demos/mytime-prototype.html`。原型需要与用户可见的计时确认、时间线、设置入口和手动 WebDAV 同步保持一致；Hive DTO、Keychain 和具体冲突编排仍只在文档中说明。

自动化验证基线：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```
