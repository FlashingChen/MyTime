# Mock Data Audit Report

## 1. 数据模型概览

MyTime MVP 使用 Hive 本地存储，包含以下核心模型：

### TimeRecord

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 记录唯一标识，UUID v4 |
| categoryId | String | 关联分类 ID |
| startTime | DateTime | 开始时间 |
| endTime | DateTime | 结束时间 |
| note | String? | 可选备注 |

### Category

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 分类唯一标识 |
| name | String | 分类名称 |
| color | String | 十六进制颜色，如 `#6366F1` |
| isSystem | bool | 是否系统预设分类 |

### AppSettings

| 字段 | 类型 | 说明 |
|------|------|------|
| accentColor | String | 主题强调色 |
| themeMode | String | `light` / `dark` / `system` |
| aiApiKey | String? | AI 服务 API Key |
| aiModel | String? | AI 模型名称 |

## 2. 默认分类

应用首次启动时，`CategoryRepository` 会自动将以下系统分类写入 Hive：

- 工作 `#6366F1`
- 阅读 `#8B5CF6`
- 运动 `#10B981`
- 学习 `#F59E0B`
- 社交 `#EC4899`
- 休息 `#6B7280`
- 创作 `#3B82F6`
- 其他 `#9CA3AF`

系统分类不可删除、不可编辑，以保证数据一致性。

## 3. 数据导入导出格式

导出 JSON 包含以下字段：

```json
{
  "version": 1,
  "exportedAt": "2026-07-10T00:00:00.000",
  "categories": [...],
  "records": [...]
}
```

导入时会先写入分类，再写入记录；若字段缺失则跳过该条目。

## 4. 数据约束

- 分类颜色必须是 `#RRGGBB` 格式。
- 记录必须包含 `categoryId`、`startTime`、`endTime`。
- 系统分类 `isSystem` 为 `true`，用户自定义分类为 `false`。
