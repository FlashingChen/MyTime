# AGENTS.md — MyTime 开发规范

本文件供 AI 协作者和人类开发者共同遵循。所有提交到本仓库的代码与文档都应符合以下规范。

## 1. 项目定位

MyTime 是开源免费、纯本地、跨端的时间记录 APP。MVP 阶段专注 Android（Flutter），后期支持 iOS 与 WebDAV 同步。

## 2. 技术栈约定

- **框架**：Flutter (Dart)
- **状态管理**：BLoC（`flutter_bloc`）
- **本地存储**：Hive（记录数据）+ SharedPreferences（配置）
- **导航**：GoRouter
- **图表**：fl_chart
- 不得擅自引入新依赖，需先在 PR / 讨论中说明理由

## 3. 项目结构

```
lib/
├── core/
│   ├── theme/
│   ├── constants/
│   └── utils/
├── data/
│   ├── models/
│   ├── repositories/
│   └── providers/
├── blocs/
│   ├── timer/
│   ├── records/
│   └── settings/
├── ui/
│   └── pages/
│       ├── home/
│       ├── timeline/
│       ├── stats/
│       └── settings/
├── widgets/
└── main.dart
```

- 每个页面有独立目录，包含 `view`、`bloc`、子组件
- 公共组件放在 `lib/widgets/`
- 数据模型放 `lib/data/models/`，Repository 放 `lib/data/repositories/`

## 4. UI / 设计规范

### 必须遵守
- **不使用 emoji**，所有图标用 SVG（`flutter_svg`）或自绘 `CustomPainter`
- **必须以 `design-demos/mytime-prototype.html` 为 UI 锚点**：开发任何界面前先对照原型，确保布局、交互、配色、文案 100% 一致
- 设计风格：简洁、现代、大气，充足留白
- 配色：
  - 主深色 `#1a1a2e`
  - Accent 渐变 `#6366F1` → `#8B5CF6`
  - 背景浅色 `#F8F9FA`，卡片白 `#FFFFFF`
- 文案：简体中文，动词 + 名词命名页签（如"开始计时"、"记录详情"）

### 应该遵守
- 动画使用 Flutter 内置 Animation / Hero / AnimatedContainer，质感要流畅
- 毛玻璃效果用 `BackdropFilter`（`ImageFilter.blur`）
- 圆角统一 12px（卡片）/ 24px（弹窗）/ 50%（按钮）

## 5. 代码规范

### Dart 风格
- 遵循 `dart format` 默认风格
- 文件命名：小写下划线（`time_record.dart`）
- 类命名：大驼峰（`TimeRecord`）
- 私有成员带前缀下划线
- 每个 public 类有文档注释（`///`）

### BLoC 规范
- 事件命名：动词过去式（`TimerStarted`、`RecordAdded`）
- 状态命名：描述性（`TimerInitial`、`TimerRunInProgress`）
- 一个 BLoC 一个文件，配套 `events.dart` / `state.dart`

### Repository 规范
- Repository 对 BLoC 层暴露纯 Dart 接口，内部封装 Hive
- 数据库 / 存储切换不影响 BLoC 层

## 6. 开发流程（Superpowers 规范）

所有功能开发遵循：
1. **设计先行**：原型已固化于 `design-demos/`，改动需同步更新原型 + Spec
2. **Plan → Implement**：用 `writing-plans` skill 拆分实现计划 → `subagent-driven-development` 执行
3. **TDD**：关键逻辑用 `test` 包写单元测试后再实现（参考 `test-driven-development` skill）
4. **Systematic Debugging**：遇到 bug 先按 `systematic-debugging` skill 定位根因，不盲目改
5. **Verification Before Completion**：完成任务前必须跑 `flutter analyze`、`flutter test`，输出贴在 PR 描述里
6. **Receiving / Requesting Code Review**：较大改动需互相 Code Review

## 7. Git 规范

- Commit message 用英文祈使句：`Add timer bloc`、`Fix timeline card overlap`
- 一次 commit 一个逻辑变更，不混杂格式化和功能
- 不主动 push / 建 PR，除非用户明确要求
- 不在代码中硬编码 secrets

## 8. 测试

- 单元测试：`test/` 下，与 `lib/` 目录结构对应
- Widget 测试：关键交互（计时器、Bottom Sheet、时间线滚动）必须有
- 集成测试：MVP 末尾补一条"启动 → 计时 → 保存 → 在时间线看见"的端到端

## 9. 性能

- 时间线列表用 `ListView.builder`，避免一次性渲染所有事件
- 图表数据计算放 Repository / UseCase，不放 Widget build 里

## 10. 无障碍

- 所有交互元素最小 44x44 命中区域
- 关键文字用 `Semantics` 标注
- 支持 Flutter 内置的大字体缩放

## 11. 文档维护

- 新增功能必须更新 `CHANGELOG.md` 的 `[Unreleased]` 段
- 重大架构变动更新 `README.md` 和 Spec 文档
- 此文件（`AGENTS.md`）本身随规范演进更新