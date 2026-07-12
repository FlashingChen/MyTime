# CHANGELOG

本项目变更遵循 [Keep a Changelog](https://keepachangelog.com/) 风格。

## [Unreleased]

### Added
- AI API Key 改由平台安全存储保存；旧版 SharedPreferences 明文 Key 会在首次读取时迁移并删除。
- JSON 导入增加版本、结构、重复 ID、分类引用和时间范围校验；完整验证后执行，失败时恢复导入前数据。
- 新增 GitHub Actions 质量门禁，覆盖格式化、分析、测试与 Debug APK 构建。
- Android 发布签名支持通过未提交的 `android/key.properties` 注入，并提供安全模板。
- 计时器状态持久化：开始计时立即启动前台计时，并异步保存启动时间；APP 重启后自动恢复正在运行的计时器，实现退出后继续计时。
- `ActiveTimerRepository`：负责活动计时器启动时间的持久化与恢复。
- `RestoreTimer` 事件：APP 启动时派发，从持久化存储恢复运行中的计时器。
- 计时持久化操作串行执行，避免异步保存与停止/重置清理竞争而错误恢复已停止的计时。
- `TimerRunInProgress` / `TimerRunComplete` 状态改为携带绝对 `startTime` 时间戳，确保跨重启时长计算准确。
- “AI 模型配置”支持保存 OpenAI-compatible 服务地址、API Key 与模型名，并可测试连接。
- AI 建议在完成配置后调用所选模型生成当前统计周期的总结；未配置或请求失败时保留本地建议兜底。
- AI 建议基于当前统计周期的记录生成模拟总结，并支持重新生成不同建议。
- 统计占比饼图支持点击高亮、浮动提示、图例联动和无障碍说明。
- 新增主题快捷扩展，供页面使用语义化颜色适配深色模式。
- 分类管理页支持编辑/删除所有分类（包括默认分类）。
- “我的”新增记录管理页面，支持新增、编辑和删除本地记录。
- 日时间线支持双指捏合缩放，并保持缩放焦点时间稳定。
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
- 趋势图的提示信息与原型数据统一使用小时/分钟格式，移除面向用户的小数小时显示；本日和本月视图会抽样展示横轴标签以避免拥挤。
- 统计页将裁剪后的周期记录统一提供给占比和 AI 建议，跨周期记录不再被重复计入。
- 完善浅色/深色组件主题；首页、时间线、统计、设置和底部导航改用语义化主题颜色。
- 数据导入导出结果改为主题化圆角对话框提示。
- 删除分类后，关联记录保留为「未分类」状态。
- 移除「系统分类」概念，所有分类完全平等。
- 创建记录时必须选择分类；仅剩一个分类时禁止删除。
- 时间线改为全天日视图，修复短记录相邻时的视觉重叠。
- 统计趋势按日、周、月使用小时、星期和日期粒度。
- 设置页“分类管理”入口从占位提示改为真实页面
- 设置页“默认主题色”入口从占位提示改为颜色选择器
- 设置页“数据导入导出”入口从占位提示改为 JSON 导入/导出
- 设置页“关于 MyTime”从占位提示改为系统关于对话框
- `main.dart` 通过 `HiveHelper` 初始化并同时打开 `records` 与 `categories` 两个 Hive box，全局提供 `CategoriesBloc`

### Fixed
- AI 服务仅允许 HTTPS 地址，避免 Bearer Token 经明文 HTTP 传输。
- 停止计时后的待确认会话会持久化固定结束时间；仅在记录保存成功后清理，避免退出、保存失败或确认延迟造成记录丢失和时长漂移。
- 记录更新不再意外清空可空分类/备注；记录和分类输入会在 Repository 边界校验。
- 删除分类后记录消费者会自动刷新；跨午夜记录会在相交的两个日时间线中正确裁剪显示。
- 修复统计上月比较边界、饼图筛选在数据变化后的失效状态，以及 AI 建议面对少于一分钟记录的除零异常。
- 修复冷启动后统计分类标签错误显示为「其他」的问题。
- `AppTheme.light` / `AppTheme.dark` 由 getter 改为接受 `accentColor` 的方法，支持主题色动态切换
- 修复 HiveObject 子类的 `must_be_immutable` 分析警告
