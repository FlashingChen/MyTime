# MyTime

开源免费的多端时间记录 APP。

## Android 发布签名

不要提交 keystore 或 `android/key.properties`。复制
`android/key.properties.example` 为 `android/key.properties`，并填入本机
keystore 信息后再运行 `flutter build apk --release`。

## 特性

- 开始/结束点击式时间记录
- 日 / 周时间线视图
- 丰富的统计分析（占比 / 趋势 / AI 建议）
- 纯本地存储，无需账号
- 深色 / 浅色主题切换
- 跨端支持（Android / iOS）

## 技术栈

- Flutter (Dart)
- BLoC 状态管理
- Hive 本地存储
- fl_chart 图表库

## 项目状态

当前阶段：MVP 设计与开发启动

- 设计规格文档：`docs/superpowers/specs/2026-07-09-mytime-design.md`
- 高保真原型：`design-demos/mytime-prototype.html`（浏览器打开即可交互体验）

## 开发

详见 `CHANGELOG.md` 了解开发进展，详见 `AGENTS.md` 了解开发规范。

## 许可证

待定（将采用开源协议）
