# Import Recovery Worker Gate Report

## 修复内容

- 在后台 WebDAV Worker 的实际业务流程最前端调用 `ImportRecoveryJournal.hasPendingRecovery()`。
- 恢复日志待处理时，Worker 安全完成，不读取设置、同步快照，也不创建 WebDAV 网络操作。
- 损坏恢复日志继续向 callback 的既有通用错误处理传播，callback 返回 `false`，由 WorkManager 重试；后续设置、快照与网络步骤不会执行。
- 保留既有前台 heartbeat 准入、Hive-free Worker、只读不可变快照和远端优先冲突策略。

## TDD 证据

- 先新增 `webdav_background_task_test.dart`，运行失败：`WebDavBackgroundTask` 尚不存在。
- 最小实现后，focused tests 通过。
- 覆盖 pending 日志仅检查日志、无日志配置到快照到同步的顺序、未配置不读取快照、损坏日志在后续操作前失败。

## 验证

- `flutter test test/data/sync/webdav_background_task_test.dart test/data/sync/webdav_background_runner_test.dart`：通过（7 tests）。
- `flutter analyze`：通过，无问题。
- `flutter test`：通过（237 tests）。
- `flutter build apk --debug`：通过。首次 Gradle 下载 `androidx.test:runner` 时 Maven TLS 握手失败，Flutter 自动重试后成功生成 APK。
- `git diff --check`：通过。

## 风险

- 损坏恢复日志会持续请求 WorkManager 重试，直至前台恢复流程修复或清除日志；这是为了避免在恢复状态不可信时上传快照的保守行为。
- 未修改现有 iOS 未提交文件。
