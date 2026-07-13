# MyTime 全仓库整改审计报告（2026-07-13）

## 结论

本轮已完成所有可由仓库代码、文档和本机构建环境闭环的问题整改。领域存储耦合、计时会话丢失风险、统计计算位置、同步 Adapter 缺失、同步并发覆盖、敏感设置明文风险、发布签名边界、错误反馈和文档漂移均已落地修复并有自动化验证。

唯一不能在当前会话闭环的验证是物理 iPhone 的最终执行：设备曾被识别并开始安装调试应用，但在启动测试前从本机断开。该用例、Drive 入口和执行说明已提交到仓库；设备重新以 USB 连接、解锁并启用开发者模式后可直接复跑。

## 已解决的设计与质量问题

| 审计项 | 原问题 | 整改结果 |
| --- | --- | --- |
| 领域/存储边界 | `TimeRecord`、`Category` 带 Hive 注解，BLoC 间接依赖实现细节。 | 领域模型改为纯 Dart；`HiveTimeRecord`、`HiveCategory` DTO 与 DataStore Adapter 承担序列化；Repository Port 保持 BLoC 无感。旧 Hive 二进制数据兼容测试通过。 |
| 计时可靠性 | 停止后确认、重启恢复和异步写入可能竞争，100ms 刷新造成无效重建。 | 持久化会话区分运行/待确认并串行写入；失败保留可恢复会话并显示提示；刷新降为秒级。 |
| 导入一致性 | 非法或半失败导入可能留下不完整数据。 | 先完整校验再替换；写入失败回滚；禁止导入零分类快照。 |
| WebDAV 同步 | 只有 Port，没有用户配置、传输实现或冲突策略。 | HTTPS-only WebDAV Adapter、手动同步设置 UI、安全密码存储、版本水位、完整快照 LWW 与本地回滚均已实现；拒绝 URL 内嵌凭据，保存失败不会误报成功。 |
| 同步并发 | 慢速远端拉取可能覆盖同步期间新增的本地记录。 | 写入、导入和远端替换共享进程内锁；替换前原子复核本地修订，变更后上传最新本机快照。 |
| 性能结构 | 统计指标在 Widget `build` 路径内反复聚合。 | `StatsBloc` 负责预计算不可变指标，视图仅渲染。 |
| 用户可见错误 | 设置、分类和记录的存储失败可能被静默吞掉。 | 设置页错误状态/重试，以及分类、记录、计时、导入导出、同步的分级可见反馈已补齐。 |
| 秘密与发布 | AI Key 可在普通偏好中留存；发布签名缺少本机边界与可复现检查。 | AI Key/WebDAV 密码进入系统安全存储，旧明文 AI Key 迁移后删除；Android 签名信息仅从本机 Keychain 与忽略配置读取，并提供检查/构建脚本。 |
| iOS 工程 | CocoaPods 改动和私有签名配置混杂，难以安全提交。 | 迁移到 Swift Package Manager；私有签名由忽略的 `Private.xcconfig` 承载；无签名 iOS Release 构建通过。 |
| 治理与文档 | 无许可证、无依赖更新策略，原型/规格/README 与实现漂移。 | 添加 Apache-2.0、Dependabot 月度策略、质量 CI；README、架构、数据格式、规格、原型、CHANGELOG 同步当前行为。 |

## 已验证证据

| 检查 | 结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test test_driver` | 通过 |
| `flutter analyze` | 通过，无问题 |
| `flutter test --concurrency=1` | 通过，145 项 |
| `flutter build ios --no-codesign` | 通过，生成 `Runner.app`（21.5 MB） |
| `flutter test integration_test/timer_persistence_device_test.dart -d iPhone 17 Pro Simulator` | 通过，验证 iOS 模拟器中的计时持久化、依赖重建、保存与时间线展示 |
| `./scripts/build-release-apk.sh` | 通过，生成签名 APK |
| `apksigner verify --verbose --print-certs` | v2 签名通过，4096-bit RSA 证书 |

本次签名 APK 的 SHA-256：`b2ea45ff1293d79ae9be2c2cb17e82a7503f27ee5ec424208a85213bf3db1f8c`。

## 有意保留的产品边界

- 同步仅由用户明确点按触发，不做后台同步。
- WebDAV 使用完整快照的最后写入优先，不实现 ETag/文件锁或逐字段合并。因此多设备同时离线修改时，较新的完整快照会覆盖较旧快照；此限制已在 UI、README 和架构文档中明确告知。
- 发布凭据不进入 Git、CI 或远端仓库。Android 发布由授权设备上的本机脚本完成；iOS 签名同样保持本地私有。这是隐私边界，而非未修复缺陷。

## 待物理设备确认

物理真机的最终确认仍未完成：iPhone 无线连接曾中断。iOS Simulator 已通过同一设备目标的自动化用例；物理设备重新连接后使用 README 中的 `flutter drive` 命令即可执行，建议用 USB 保持调试通道稳定。自动化用例验证的是依赖重建而非真实杀进程；真实杀进程恢复需要按 README 的手工步骤在设备上确认。
