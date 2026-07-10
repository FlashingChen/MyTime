# CHANGELOG

本项目变更遵循 [Keep a Changelog](https://keepachangelog.com/) 风格。

## [Unreleased]

### Added
- “我的”新增记录管理页面，支持新增、编辑和删除本地记录。
- 日时间线支持双指捏合缩放，并保持缩放焦点时间稳定。

### Changed
- 时间线改为全天日视图，修复短记录相邻时的视觉重叠。
- 统计趋势按日、周、月使用小时、星期和日期粒度。
- 系统分类不可删除；删除自定义分类时可将关联记录迁移到替代分类。

### Added
- 新增 MyTime 品牌 Logo：PNG 源文件、Android/iOS 启动图标、应用内 Splash 页面及 Widget 测试；Android 应用标签统一为 MyTime
- 项目初始化（git 仓库 + GitHub 私有远端）
- 设计规格文档 `docs/superpowers/specs/2026-07-09-mytime-design.md`
- 高保真 HTML 原型 `design-demos/mytime-prototype.html`，覆盖四个主页面交互流程：
  - 首页：极简计时器，圆环缩放动画，结束确认 Bottom Sheet
  - 时间线：日/周视图，纵向时间轴定位事件卡片
  - 统计：本日/周/月切换，占比/趋势/AI建议三标签
  - 我的：头像、深色模式开关、设置列表
- `README.md`、`AGENTS.md`、`CHANGELOG.md` 项目基础文档
- 分类管理：新增 `CategoryRepository`、`CategoriesBloc`、`CategoryManagementPage`，分类数据持久化到 Hive，支持新增/编辑/删除
- 默认主题色配置：设置页可直接选择并持久化 accent color，AppTheme 动态应用
- 数据导入导出：设置页支持将记录与分类导出为 JSON 到剪贴板，或从剪贴板导入 JSON
- `CategoryLookup` 工具类，让分类消费者优先从 `CategoriesBloc` 读取真实数据，无 Bloc 时回退到系统默认

### Changed
- 设置页“分类管理”入口从占位提示改为真实页面
- 设置页“默认主题色”入口从占位提示改为颜色选择器
- 设置页“数据导入导出”入口从占位提示改为 JSON 导入/导出
- 设置页“关于 MyTime”从占位提示改为系统关于对话框
- `main.dart` 通过 `HiveHelper` 初始化并同时打开 `records` 与 `categories` 两个 Hive box，全局提供 `CategoriesBloc`

### Fixed
- `AppTheme.light` / `AppTheme.dark` 由 getter 改为接受 `accentColor` 的方法，支持主题色动态切换
- 修复 HiveObject 子类的 `must_be_immutable` 分析警告
