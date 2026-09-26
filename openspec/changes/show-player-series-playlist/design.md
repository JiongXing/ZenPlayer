# Design

## Context

动机见 [proposal.md](proposal.md)。`PlayerView` 已观察共享 `PlayerViewModel`，展示内容取自 `currentContext`；`PlaybackQueueControls` 已提供前后切集及连播开关。`QueueSnapshot` 保存原顺序和讲集元数据，`PlaybackContext.series` 为可选轻量引用。`SeriesDestination(reference:targetEpisodeID:)` 和 `ContentView` 已提供讲集详情值路由。

当前工作区含独立首页优化，涉及 `ContentView` 与 L10n；实施须局部合并，不覆盖已有改动。保留 M0～M4 原验证状态，本面板不承担关闭其设备缺口。

## Goals / Non-Goals

**Goals:** 在现有播放页增加轻量展示层，集中使用当前会话与队列；具体可观察行为见 [规格](specs/player-series-playlist/spec.md)。

**Non-Goals:** 不引入第二播放器、独立列表缓存、队列服务、远端元信息补齐或新的持久化格式。展示用状态只负责弹层与待导航目标，不参与业务播放状态机。

## Decisions

1. **共享面板内容、平台原生呈现。** `PlayerView` 添加按钮和呈现状态，新增 `PlayerPlaylistView` 使用 `List` 或惰性列表；iOS 使用可展开 sheet，macOS 使用按钮锚定的 popover，带关闭按钮和适当尺寸。顶部显示讲集名、已加载数量和详情入口，列表下方不复制下载／降噪等控制。按需弹出，保持播放页紧凑；不使用空间受限的普通菜单承载长列表。新增文案经 L10n／xcstrings 使用繁体中文，行与按钮沿用 44pt 可操作尺寸及完整可访问标题。

2. **数据以当前会话为准。** 面板观察 `viewModel.queue.snapshot` 和 `currentContext`，不从 `PlayerView.context` 的初次导航入参生成列表。讲集信息优先使用有效当前快照，缺失时使用当前轻量引用；没有快照时仅展示当前单集与说明。初次展开及异步队列首次恢复后定位当前行一次，后续连播只更新标记；用户滚动不被频繁抢回。停止会话时收起面板。打开面板不创建额外网络任务。

3. **选集入口放 ViewModel。** 增加一个最小的按单集身份选择当前队列目标的方法，点击时从最新队列查索引，再用 `snapshot.context(at:preferred:)` 构建上下文，传回原快照交由 `selectPlayback` 完成。使用单集身份和快照标识核对点击仍属于当前列表，避免已变化的列表索引误选。当前行显式视为无操作，仅让展示层收起；不同目标沿用现有准备、保存和最后选择保护。不修改只支持邻集的 `PlaybackQueueState.context(offset:)` 来制造任意偏移规则，不在视图中处理播放器。媒体偏好取点击时的 `selectedMediaType`。

4. **关闭后走值路由。** 点击详情时从当前关联与单集生成 `SeriesDestination`，由播放页保存一次性待导航值，iOS sheet 的 `onDismiss`／macOS popover 内容的 `onDisappear` 后通过值驱动导航进入已注册目的地；优先使用播放页的局部值导航，必要时接入现有根 `NavigationPath`。不在 sheet 内另建详情导航栈，不通过延时计时器协调关闭。返回页面不得重新选择初始 `context`；验证 `didSelect` 与视图身份保持，若实际往返会重建则局部修正该入口，不新增会话所有者。

5. **沿用现有测试注入。** 在 `PlayerQueueIntegrationTests` 或附近新增行为用例，复用隔离存储、测试音频和可控准备流程，验证跳选、当前集无操作、原快照保留和过期选择保护。现有进度保存及媒体回退测试继续覆盖，不为 sheet 单独建设测试框架。

## Risks / Trade-offs

- [历史无讲集关联] → 明确显示不可用，不凭标题猜测讲集；有轻量引用仍可去详情。
- [远端详情与旧快照内容不同] → 面板严格展示当前队列；详情加载沿用原行为，只有用户明确选集才改变播放。
- [弹层关闭与导航时序、返回旧播放入参] → 用关闭回调和一次性路由值；两端实际验证选集后详情往返、暂停往返。
- [播放中列表更新] → 观察共享状态，以身份核对选集；不复制快照到长期 UI 状态，不引入重试或定时器。
- [长讲集列表] → 惰性行与首次定位；不增加搜索／排序，完整可访问标题保留。

## 实施中确认的平台行为

macOS 实际 UI 测试与临时调用栈证实，`AVPlayerView.windowWillBeginSheet:` 经 `AVPlayerController.setPlaying:` 把正在播放的媒体 rate 置零；这也发生在直接使用原生 AVPlayerView 时。因此 macOS 使用 popover，继续保留原 SwiftUI VideoPlayer，避免引入自动恢复、暂停抑制或新的承载层。iOS sheet 未观察到该行为。规格的按需面板和同一会话约束不变。

## Migration Plan

没有数据迁移、存储重写或旧键变动。实施回退仅移除面板入口、视图与新增选集封装，既有队列和进度继续兼容。验收证据分别记录自动化、两端构建和 UI 主流程；播放生命周期相关 iPhone 设备路径若未运行如实保留缺口。
