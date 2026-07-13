# MyTime 第一阶段：记录完整性与状态一致性设计

> 文档状态：本文件保留第一阶段的原始决策与验收范围。后续已在同一分支完成领域模型/Hive DTO 分离、Repository Port、DataStore Adapter、安全设置存储和同步 Port；这些后续边界以 [当前架构与存储边界](../../architecture.md) 为准。

## 目标

消除当前计时确认、分类删除、跨午夜时间线和统计交互中的数据丢失、错误时长、过期状态与崩溃风险，同时建立最小的记录变更边界，为后续 Repository Port / Adapter 改造铺路。

本阶段不迁移 Hive schema、不调整现有 iOS 工程配置、不引入依赖、不实施 WebDAV 或完整 Clean Architecture。

## 范围

本阶段包含：

1. 可靠完成一次计时会话。
2. `TimeRecord` 与 `Category` 的输入校验及可空 `copyWith` 语义修复。
3. 记录变更传播，保证分类删除后所有消费者刷新。
4. 跨午夜记录的日视图裁剪。
5. 饼图选中项、AI 零分钟数据、月度上一周期计算的统计修复。
6. 上述行为的单元与 Widget 回归测试。

本阶段不包含：AI Key 安全存储、导入导出事务、发布签名、GoRouter、文档/原型全面同步；它们保留给后续独立阶段。

## 方案选择

采用轻量工作流层，而非局部 UI 补丁或一次性全面重构。

- 局部补丁会继续将跨仓库事务分散在 Widget 与多个 BLoC。
- 全面拆分领域实体、Hive DTO 与全部 Port 会扩大改动面，并与现有统计/iOS 未提交改动重叠。
- 本方案只增加完成计时这一跨边界 UseCase，并以 Repository 变更流统一刷新读取状态。

## 1. 完成计时会话

### 1.1 会话状态

活动计时器持久化从“仅开始时间”扩展为可区分的会话状态：

- `running`：保存 `startTime`；重启后继续计时。
- `pendingConfirmation`：保存 `startTime` 与固定的 `stoppedAt`；重启后恢复为待确认记录。

读取旧的仅开始时间键时，兼容解释为 `running`，使已有用户不会丢失正在进行的计时。

### 1.2 保存协议

`TimerStopped` 捕获一次 `stoppedAt`，生成 `pendingConfirmation` 并持久化。确认页使用这个固定时刻，绝不在页面构建或确认点击时重新读取 `DateTime.now()`。

新增 `CompleteTimerSession` UseCase：

1. 校验记录。
2. 写入记录 Repository。
3. 成功后清除 pending session。
4. 只有全部成功才令计时器回到初始状态。

失败时维持 `TimerRunComplete` 与 pending session，UI 显示可重试错误，不能静默丢失会话。

### 1.3 确认 UI

底部 Sheet 改由 `BlocListener` 在状态首次进入 `TimerRunComplete` 时打开，不能在 `build` 注册回调。

Sheet 禁用手势关闭；提供明确的“放弃记录”入口，并在确认放弃后清除 pending session 与重置计时器。保存中禁用重复提交。

## 2. 模型与 Repository 校验

`TimeRecord.copyWith` 使用内部 sentinel 区分“不修改可空字段”和“将其设为 null”，使修改备注不会丢失分类，也允许清空备注或分类。

`RecordRepository.add` 与 `update` 拒绝 `endTime <= startTime` 的记录。`CategoryRepository.add` 与 `update` 拒绝空白名称和非 `#RRGGBB` 颜色。边界校验覆盖 UI、未来导入和程序调用三类入口。

## 3. 记录变更传播与分类删除

`RecordRepository` 暴露只读记录变更流。所有写操作，包括分类删除时调用的 `clearCategory`，均触发该流。

`RecordsBloc` 在构造时订阅变更流并重载全量记录；关闭时取消订阅。这样分类删除、记录新增编辑删除都会使首页、时间线和统计得到同一份新状态。

`CategoriesBloc` 的记录 Repository 依赖改为必需；删除分类时先清除记录引用，再删除分类。保留“至少一个分类”的业务规则。未找到分类统一显示“未分类”，不再伪装成默认“其他”。

## 4. 时间线跨午夜裁剪

时间线以所选日 `[dayStart, nextDayStart)` 与记录区间是否重叠来筛选：

```text
record.startTime < dayEnd && record.endTime > dayStart
```

显示前构造仅用于布局的裁剪记录：开始时间取较晚者，结束时间取较早者。23:00–01:00 的记录会在首日显示 23:00–24:00、次日显示 00:00–01:00。

Repository 的按日查询采用同一重叠语义。

## 5. 统计稳定性

- 饼图保存选中的 `categoryId`，每次数据更新后若该分类不存在则清除选中态。
- AI 本地建议在总分钟数为零时不计算百分比，展示安全的通用建议。
- 月度上一周期用日历月边界计算，例如 3 月的上一周期为完整 2 月。

本阶段不移动 `StatsMetrics` 目录，也不做统计性能重构；保留用户当前的统计裁剪修复。

## 6. 测试

先新增失败测试，再实现：

1. 停止后等待确认不会改变保存的结束时间。
2. 确认保存失败保留待确认会话；成功才清除。
3. `copyWith` 保留与清空可空字段。
4. 非法记录、非法分类被 Repository 拒绝。
5. 删除分类后记录状态与界面消费者刷新为未分类。
6. 跨午夜记录在两天均以正确时间段显示。
7. 饼图切换到更少分类不会越界。
8. AI 面对少于一分钟的记录不崩溃。
9. 月度上一周期使用正确日历边界。

每次完成后运行 `flutter analyze` 与 `flutter test`；不修改用户现有的统计与 iOS 未提交改动。

## 风险与兼容性

- 活动计时持久化需要兼容旧 key；迁移失败时不能删除旧会话。
- Hive 无跨 box 事务，因此保存记录成功、清除 pending 失败时应保留可幂等重试状态，不能创建重复记录。
- 记录变更流应避免订阅自身触发无限重载；只由 Repository 写操作发出通知。
- 底部 Sheet 行为和原型发生变化时，实施结束后必须更新原型与 CHANGELOG。

## 验收标准

- 计时器在确认前退出或保存失败时不会丢失会话。
- 保存记录的结束时间等于真正停止时间。
- 分类删除后所有页面显示“未分类”。
- 跨午夜记录在两天的时间线均正确显示。
- 上述边界场景均有自动化测试。
- `flutter analyze` 与 `flutter test` 通过。

## 实施后的扩展

第一阶段完成后，存储边界继续演进：

- `TimeRecord` 与 `Category` 已成为不带 Hive 注解的领域模型；Hive 序列化移动到 DTO 和 DataStore Adapter。
- `RecordsBloc` 与 `CategoriesBloc` 通过 Repository Port 访问数据，记录 Repository 的变更流继续驱动各消费者刷新。
- 普通设置和活动计时通过 `PreferencesStore` 访问 SharedPreferences；AI API Key 通过平台安全存储保存并迁移旧明文值。
- HTTPS WebDAV 已演进为显式手动同步：设置页保存配置，完整快照以确定性的最后写入优先策略同步；不提供后台自动同步。
