# MyTime 数据模型与备份格式说明

**文档状态：** 已按当前实现同步。它替代早期 mock-data 审计中的 `isSystem`、强制分类和“逐条跳过非法导入”的过期描述。

## 1. 领域模型

MyTime 的领域模型是纯 Dart 对象；Hive 序列化仅存在于 DTO/Adapter 层，详见 [当前架构与存储边界](architecture.md)。

### TimeRecord

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | 记录唯一 ID；导入时必须唯一且非空。 |
| `categoryId` | `String?` | 可选分类 ID；删除分类后设为 `null`。 |
| `startTime` | `DateTime` | 开始时间。 |
| `endTime` | `DateTime` | 结束时间，必须晚于开始时间。 |
| `note` | `String?` | 可选备注。 |
| `createdAt` | `DateTime` | 本地创建时间。 |

### Category

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | `String` | 分类唯一 ID。 |
| `name` | `String` | 非空名称。 |
| `color` | `String` | `#RRGGBB` 格式。 |

默认八个分类仅在首次空库时写入。它们与用户新增分类完全平等，均可编辑或删除；应用始终至少保留一个分类。

### AppSettings

| 字段 | 存储位置 |
| --- | --- |
| `accentColor`、`themeMode`、`aiBaseUrl`、`aiModel`、`webDavEndpoint`、`webDavUsername` | SharedPreferences（通过 `PreferencesStore`） |
| `aiApiKey`、`webDavPassword` | 平台安全存储（通过 `SecureKeyValueStore`） |

## 2. JSON 备份格式

设置页将数据导出到剪贴板，格式版本为 `1`：

```json
{
  "version": 1,
  "exportedAt": "2026-07-10T00:00:00.000",
  "categories": [
    {"id": "work", "name": "工作", "color": "#6366F1"}
  ],
  "records": [
    {
      "id": "record-id",
      "categoryId": "work",
      "startTime": "2026-07-10T09:00:00.000",
      "endTime": "2026-07-10T10:00:00.000",
      "note": "示例"
    }
  ]
}
```

备份不包含 AI API Key、WebDAV 密码/地址、主题设置、活动计时会话或平台签名资料。

## 3. 导入规则

导入不会逐条忽略坏数据。服务会先完整解析和验证：

- 根对象版本必须为 `1`，且包含分类和记录数组。
- 分类数组至少包含一个有效分类，避免导入后无法新建记录。
- 分类和记录的 ID 必须非空且不重复。
- 分类名称与颜色、记录时间范围都必须通过 Repository 校验。
- 非空 `categoryId` 必须引用同一备份内存在的分类。

验证通过后，分类和记录才会替换本地数据。任何写入失败都会恢复导入前的两个数据集合，避免半导入状态。

## 4. 兼容性提示

当前备份格式未保存 `createdAt`，导入后的 `createdAt` 将按导入时创建。新增字段或版本时必须提升 `version`，保留旧版本解析策略并补充迁移测试。
