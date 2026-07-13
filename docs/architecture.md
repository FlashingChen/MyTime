# MyTime 当前架构与存储边界

本文描述仓库当前已实现的边界，而不是未来功能承诺。产品交互以 `design-demos/mytime-prototype.html` 为视觉锚点；已落地的行为以 Flutter 代码和测试为准。

## 分层

```text
Flutter UI → BLoC → Repository Port → DataStore Port → Adapter → 平台存储
```

| 层 | 当前职责 | 主要实现 |
| --- | --- | --- |
| UI / BLoC | 呈现状态、处理交互和调度业务操作 | `lib/ui/`、`lib/blocs/` |
| 领域模型 | 记录、分类和设置值对象；不依赖存储框架 | `lib/data/models/` |
| Repository | 校验记录和分类、排序/筛选、发布记录变更 | `lib/data/repositories/` |
| DataStore Port | 定义记录/分类的最小读写能力 | `lib/data/providers/hive_data_stores.dart` |
| Hive Adapter | 领域对象与 Hive DTO 双向转换 | `HiveRecordDataStore`、`HiveCategoryDataStore` |
| 偏好与密钥 | 普通偏好与敏感值分别保存 | `PreferencesStore`、`SecureKeyValueStore` |
| 同步编排 | 快照版本、冲突决策与远端协议 | `SyncLocalStore`、`SyncService`、`WebDavSyncCoordinator` |

`RecordsBloc` 和 `CategoriesBloc` 依赖 Repository Port，而非 Hive `Box`。记录写入会通过 `changes` 流使首页、时间线和统计刷新；删除分类会先清空相关记录的分类引用，再删除分类。

## 存储模型

### 领域模型与 Hive DTO

`TimeRecord`、`Category` 和 `AppSettings` 是纯 Dart 领域模型。Hive 注解和 `TypeAdapter` 仅存在于：

- `lib/data/dtos/hive_time_record.dart`
- `lib/data/dtos/hive_category.dart`

DTO 保留既有的 Hive type ID 和字段编号（记录为 `0`，分类为 `1`），以维持现有本地数据的序列化布局。任何字段演进都必须遵循 Hive 的兼容性规则：不重用字段编号、保留旧字段的可读性，并补迁移测试。

### 普通设置与敏感设置

- 主题色、主题模式、AI 服务地址/模型名及 WebDAV 地址/用户名通过 `PreferencesStore` 保存到 SharedPreferences。
- AI API Key 与 WebDAV 密码通过 `SecureKeyValueStore` 保存到平台安全存储。旧版 SharedPreferences 中的 AI 明文 key 会在首次读取时迁移，并在迁移成功后删除。
- 活动计时会话（开始时间与可选的固定停止时间）通过 `ActiveTimerStore` 保存，支持运行中和待确认两种恢复状态。

## 数据一致性约定

- `TimeRecord.endTime` 必须晚于 `startTime`。
- 分类名称不能为空，颜色必须为 `#RRGGBB`。
- `TimeRecord.copyWith` 可明确清空 `categoryId` 或 `note`；未传字段则保留原值。
- 导入先完整解析、验证并去重，再替换数据；替换失败会回滚导入前的记录和分类。
- 导入和同步快照都至少保留一个分类，避免产生无法新建记录的空分类库。
- 日时间线按区间重叠筛选，并在绘制前裁剪到所选日期，因此跨午夜记录会显示在两天中。

## 同步边界

`lib/data/sync/` 包含 `SyncPort`、`SyncSnapshot`、`WebDavSyncAdapter`、`WebDavSyncCoordinator` 与本地快照 Adapter：

- Adapter 只接受 HTTPS WebDAV 地址，并以一个版本化 JSON 文档进行 `GET` / `PUT`。
- 设置页允许保存文档地址、用户名和安全存储中的密码；只有用户点击“立即同步”时才连接远端。
- `PreferencesSyncRevisionStore` 记录本地快照水位；记录/分类的 Revision Tracking Decorator 仅在成功本地写入后前进水位。远端应用使用未经装饰的 Repository，避免把远端版本误记为本地改动。
- 冲突策略是整个快照的最后写入优先：远端 `updatedAt` 严格较新时应用远端；相等或本地较新时上传本地。单次同步会合并并发调用，远端写入或本地替换失败会保留或回滚本机快照。
- 同步错误在设置页按配置、网络/认证、远端格式和本机回滚失败分级显示；地址拒绝 URL 内嵌凭据，设置保存成功后才会显示成功或发起同步。
- 本地写入、导入和远端快照替换共享进程内写入锁。远端拉取完成后，替换会再次原子确认本地修订版本；期间有新本地写入时改为上传最新本机快照，避免覆盖用户刚新增的数据。

## 已知边界

- `DataTransferService` 依赖 `RecordsSnapshotRepository` / `CategoriesSnapshotRepository`，而非 Hive 具体类；新存储实现只需实现这些 Port。
- 同步采用整快照冲突策略；尚无 ETag/文件锁、后台自动同步或逐记录字段合并。因此多设备同时离线编辑时，较新的完整快照会覆盖较旧快照。
- iOS 与 Android 的签名配置均为本地私有配置；仓库只提交模板，不提交身份、私钥或密码。

## 演进规则

新增存储实现时，应先实现相应 Port 与 Adapter，再将其注入 Repository；不要把 Hive、SharedPreferences 或平台安全存储 API 重新引入 BLoC 或 Widget。任何影响用户数据的迁移都必须先增加兼容性测试，并在真实设备备份上验证恢复路径。
