# Timer Reliability Design

**文档状态：** 已按当前实现同步。

## Goal

让前台计时立即开始并按秒更新，同时在 Android 后台、进程终止和“停止但尚未确认保存”三种情况下保留正确的会话状态。

## Decision

`TimerBloc` 拥有内存 ticker。开始事件必须同步进入 `TimerRunInProgress`，持久化绝不能阻塞可见计时；持久化操作按顺序排队，以避免开始、停止、重置之间的异步写入竞争。

活动会话通过 `ActiveTimerStore` 保存完整的 `PersistedTimerSession`：

- `running`：只有 `startTime`，启动后按当前时间恢复计时。
- `pendingConfirmation`：保存 `startTime` 和固定 `stoppedAt`，启动后恢复待确认的记录详情。

旧版本仅保存开始时间的内容按 `running` 兼容读取。

## Required behavior

- 开始时立即发出运行状态、启动秒级 ticker，并异步保存开始时间。
- 运行中的计时从绝对 `startTime` 计算，不依赖已经过的 ticker 次数。
- 停止时只读取一次 `DateTime.now()` 作为 `stoppedAt`，待确认状态和后续保存都使用这一固定值。
- 确认记录时先写入记录 Repository；成功后才触发 `TimerReset` 清除会话。
- 保存失败时保留待确认会话，以便用户重试；放弃记录时显式清除会话。
- 存储故障不得中断前台计时；延迟恢复不得覆盖用户后来手动开始的计时。

## UI contract

`HomePage` 仅在状态进入 `TimerRunComplete` 时打开不可手势关闭的记录详情 Bottom Sheet，不能在 `build` 中注册副作用。确认页显示固定的开始、结束和时长，允许选择分类、填写备注、确认保存或放弃记录。持久化失败会以页面提示反馈，但不会中断当前可见计时或丢弃待确认会话。

## Verification

Timer BLoC 与首页回归测试覆盖运行恢复、待确认恢复、停止时间固定、保存成功后清理、保存失败保留、放弃清理和并发持久化顺序。每次涉及计时状态的变更都应运行：

```bash
flutter analyze
flutter test
```
