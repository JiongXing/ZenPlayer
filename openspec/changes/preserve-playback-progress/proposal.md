## Why

现有断点续播与最近 10 条展示共用一份数据，第 11 条起可能挤掉旧进度；解码或编码异常还会删除整个旧键。M0 先保护长期收听记录，供后续全局会话和首页续听复用，不等待 F1 重构。

状态：**In Verification · 已批准**。已完成代码接入，验收尚不完整；逐项证据见 verification.md。产品依据：[PRD](../../../Documents/PRD/prd.md) F2-03～F2-06、D-01／D-02、Q-01／Q-04；阶段入口：[Roadmap](../../../ROADMAP.md)。

## What Changes

- 长期进度与最近展示分离；最近按实际收听时间查询 10 条，长期记录不自动淘汰。
- 保留 `recentPlayback.records` 和 `episode.id + "|" + serverUrl` 原始识别关系；逐条容错、可重入迁移、校验后标记完成，保留旧数据备份。
- 对单条损坏、空间不足、保存失败提供隔离、保留原文件、非阻断提示和重试；不承诺找回旧版已经淘汰或无法解析的历史。
- 复用当前恢复链路，补齐动作保存、准备／恢复失败防零覆盖、独立完成状态、实际重听后更新、媒体切换抓取即时位置。
- 最小适配播放器与历史列表，保留媒体偏好及可选系列关联；增加独立测试入口和迁移／故障／恢复测试（已获批准，实施证据见 verification.md）。

### 当前证据与非目标

本次读取 `main @ a86d74a4b35d7aea330be48480727d8652210914`，开始时 Git 干净，与 PRD 历史源码基线一致。

| 当前代码事实（发现实现，未验收） | 剩余缺口 |
| --- | --- |
| `ZenPlayer/Services/RecentPlaybackStore.swift`：`upsertRecord` 仅存 `prefix(10)`；`loadRecords`／`persistRecords` 异常删除旧键 | 无独立长期记录、逐条容错和可验证写入失败保护 |
| `ZenPlayer/Models/RecentPlaybackRecord.swift`：`recordID` 保留原 URL，缺位置字段默认 0；完成通过元数据时长推导 | 缺独立完成状态和可信媒体时长，未知时长结束不能可靠表达 |
| `ZenPlayer/ViewModels/PlayerViewModel.swift`：`persistPlaybackProgress` 有有限数检查、5 秒媒体位置差阈值；`stopPlayback` 强制保存；恢复期间有门控 | seek 回调忽略成功值；最近时间在构建 player 后就更新；暂停／拖动／前后台立即保存不足；切源先读旧位置再 stop 保存 |
| `ZenPlayer/Views/PlayerView.swift`：页面持有模型，离开前台页面会 stop | 跨页会话为 M1，不在此变更修复 |
| `ZenPlayer/ViewModels/DownloadManager.swift`：`removeCompletedDownload` 只清下载记录／文件 | 保留其边界并做回归，不改造下载系统 |

非目标：全局播放器、迷你条、队列／自动连播、首页续听卡、系列进度行／搜索定位、云同步、下载或 RNNoise 重构。M0 不承诺 AT-01～AT-26 全部通过。

## Capabilities

### New Capabilities

- `playback-progress`：长期进度保护、最近派生、兼容迁移与保存／恢复约束。首次纳入正式规格使用 ADDED，不表示原代码没有断点续播。

### Modified Capabilities

无。当前 `openspec/specs/` 无既有能力规格；本轮仅写变更内的规格，不 sync 或 archive。

## Impact

主要涉及 `RecentPlaybackStore`／`RecentPlaybackRecord`、`PlayerViewModel` 保存恢复、`PlayerView` 的生命周期与现有系统控件事件接入、`RecentPlaybackListView` 的数据适配，以及新增 `Models/PlaybackProgress`、`Services/PlaybackProgressStore` 和存储／迁移实现。`Localization`／字符串资源已接入必要保存／恢复反馈。

已建立最小 `ZenPlayerTests` target；不引入第三方持久化依赖或后端。原始旧键继续保留，旧 App 降级不自动读取新存储；故障优先前向修复。

验收主线 AT-16／AT-17／AT-18／AT-20／AT-21，加 AT-19 的删除下载子断言。详细追踪和跨阶段边界见 [verification.md](verification.md)，实施唯一清单为 [tasks.md](tasks.md)，推荐方案见 [design.md](design.md)。
