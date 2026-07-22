# MyTime

开源免费、纯本地优先的跨端时间记录应用。MyTime 通过一次点击开始/结束记录时间，并提供时间线、统计、分类管理与可选的 AI 时间建议。

> 当前阶段：Android 已通过本地签名构建；iOS 已迁移到 Swift Package Manager 并通过无签名构建。仓库含隔离数据的真机持久化测试，实际部署取决于已连接且解锁的设备。

## 已实现功能

- 点击开始/结束计时；运行中的会话和待确认会话会持久化，进程被杀后可恢复。
- 停止时固定结束时间；只有记录成功保存后才清除会话，也可明确放弃记录。
- 全天日时间线、日期导航、双指缩放、双击恢复默认缩放；跨午夜记录会在相邻两天分别裁剪显示。
- 本日/本周/本月的占比、趋势和 AI 建议；无 AI 配置或请求失败时保留本地建议。
- 记录管理、分类新增/编辑/删除、主题色与深浅色模式。
- JSON 剪贴板导入/导出；导入会先验证版本、字段、ID、分类引用和时间范围，失败时恢复导入前的数据。
- WebDAV 同步：HTTPS 文档地址、用户名和密码可在设置中保存；密码使用系统安全存储。记录或分类变更会在网络可用时提交唯一后台同步任务，同一记录冲突时保留本机版本。

## 隐私与安全

- 记录、分类和普通设置默认仅存于本机。
- AI API Key 使用平台安全存储；历史明文设置会在首次读取时迁移并删除。
- WebDAV 密码同样使用平台安全存储；地址和用户名仅保存在本机偏好设置中。
- AI 请求只接受 HTTPS 服务地址；请求包含统计周期、时长、记录数、分类标识和最长时长，不发送原始备注、记录 ID 或完整本地数据库。
- 仓库不保存 Android keystore、`android/key.properties`、iOS 私有签名配置或 API Key。

## 架构概览

领域模型不依赖 Hive。Repository 对上暴露领域对象与 Port，对下通过 DataStore Adapter 访问 Hive；普通偏好通过 `PreferencesStore` 访问 SharedPreferences，敏感配置通过安全存储访问系统凭据库。

```
UI / BLoC
   ↓
Repository Port
   ↓
RecordDataStore / CategoryDataStore / PreferencesStore
   ↓
Hive DTO + Hive Adapter / SharedPreferences
```

WebDAV 通过 `SyncPort`、`WebDavSyncCoordinator`、Repository 变更追踪和 Android WorkManager 接入。每次本地变更会合并为一次网络约束的后台同步；远端以记录、分类和 90 天删除墓碑逐 ID 合并，同 ID 内容冲突时本机优先。同步使用 ETag 条件写入，并在服务支持时使用短时 WebDAV 锁。详细说明见 [架构说明](docs/architecture.md)。

## 开始开发

前置条件：已安装与 `pubspec.yaml` 兼容的 Flutter SDK，以及 Android SDK；iOS 构建还需要 macOS 与 Xcode。

```bash
flutter pub get
flutter run
```

质量检查：

```bash
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test
flutter build apk --debug
```

依赖治理：Dependabot 每月检查 Dart 包和 GitHub Actions 更新。合并任何升级前运行 `flutter pub outdated`、质量检查和目标平台构建；主要版本升级应单独提交，避免与功能改动混合。

## 本地发布配置

### Android

Release keystore 和密码必须只存在于发布负责人的本机安全存储中。复制 `android/key.properties.example` 为未跟踪的 `android/key.properties`，填写 keystore 路径和 alias；Gradle 会从 macOS 登录钥匙串读取以下服务名对应的密码：

| Keychain service | 用途 |
| --- | --- |
| `com.mytime.mytime.android.release.key-password` | key password |
| `com.mytime.mytime.android.release.store-password` | keystore password |

两个 Keychain 条目的账号均为 `MyTime Android Release`。不要把 keystore、密码、`key.properties` 或其备份提交到 Git。

先验证本机私有配置，再构建：

```bash
./scripts/verify-release-config.sh
./scripts/build-release-apk.sh
```

构建脚本不会输出密码；会在完成后输出 APK 的 SHA-256。不要把生成的 APK、keystore、密码、`key.properties` 或其备份提交到 Git。

### 真机持久化回归

`integration_test/timer_persistence_device_test.dart` 使用独立 Hive box 和带前缀的 SharedPreferences 键，验证“计时 → 停止 → 重建应用依赖 → 保存 → 时间线可见”。连接、解锁并启用开发者模式的 iPhone 后执行：

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/timer_persistence_device_test.dart \
  -d <device-id> \
  --publish-port
```

无线 iOS 设备在部分 Flutter 版本中不能通过 `flutter test` 启动集成测试；上述 Drive 命令是兼容的运行入口。优先使用 USB 连接，以免局域网调试通道中断。

设备级的“系统杀进程后重新启动”仍需人工确认：在真机上开始计时后，从系统任务切换器终止 MyTime，重新打开应用，确认运行/待确认会话恢复，再保存并检查时间线。该步骤不能安全地由测试进程自行终止用户设备上的 App，因此不在自动化用例中伪造为已验证结果。

### iOS

个人 Apple Team ID 和 Bundle ID 存于未跟踪的 `ios/Flutter/Private.xcconfig`。首次配置时：

```bash
cp ios/Flutter/Private.xcconfig.example ios/Flutter/Private.xcconfig
```

再填写 `MYTIME_DEVELOPMENT_TEAM` 与 `MYTIME_BUNDLE_ID`。不要把私有配置或签名资料提交到远端。

本项目使用 Swift Package Manager，不再保留 CocoaPods 工程文件。首次在一台开发机上构建 iOS 前运行：

```bash
flutter config --enable-swift-package-manager
flutter build ios --no-codesign
```

## 文档

- [当前架构与边界](docs/architecture.md)
- [MVP 设计规格](docs/superpowers/specs/2026-07-09-mytime-design.md)
- [计时可靠性设计](docs/superpowers/specs/2026-07-11-timer-reliability-design.md)
- [数据完整性设计](docs/superpowers/specs/2026-07-12-data-integrity-foundation-design.md)
- [全仓库整改审计报告（2026-07-13）](docs/repository-audit-2026-07-13.md)
- [交互原型](design-demos/mytime-prototype.html)
- [变更记录](CHANGELOG.md)

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。
