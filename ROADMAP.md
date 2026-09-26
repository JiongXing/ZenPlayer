# ZenPlayer 产品迭代路线图

更新日期：2026-09-26。唯一产品基线：[Documents/PRD/prd.md](Documents/PRD/prd.md) v1.0。产品价值顺序 **F1 连续播放 → F2 可靠续听 → F3 快速找课**；工程顺序 **M0 → M1 → M2 → M3 → M4**，先保住数据不改变产品优先级。五个里程碑不代表五个 App 发布版本；本页不承诺日期或工期。

## 文档职责与状态

| 入口 | 职责 |
| --- | --- |
| [PRD](Documents/PRD/prd.md) | 唯一维护的产品目标、边界和验收基线；不为现状静默改需求 |
| 本 ROADMAP.md | 阶段顺序、范围、依赖、状态、索引和决策 |
| [当前 M0 变更](openspec/changes/preserve-playback-progress/proposal.md) | 需求增量、设计；[tasks.md](openspec/changes/preserve-playback-progress/tasks.md) 是唯一实施清单，[verification.md](openspec/changes/preserve-playback-progress/verification.md) 是验证／交接记录 |
| `openspec/specs/` | 实施、验证和批准后同步的当前行为规格；当前无主规格，不放未来愿望 |
| [AGENTS.md](AGENTS.md)／[OpenSpec 配置](openspec/config.yaml) | 项目工作规则及简明规划上下文 |

阶段状态：`Planned → In Progress → In Verification → Done`；规划状态另记，阻塞另列。规划文档齐全、OpenSpec artifact done 都不等于业务 Done。只在阶段状态变化时更新本页，详细日志留在当前变更内。

PRD 来源：用户附件 `/Users/jxing/Desktop/ZenPlayer_PRD_v1.0.md`，首次原样复制到仓库时的字节 SHA-256 为 `c0f4c5b31d66dd1adf19daf4d4fd3eb978e1a5c4627192ff8b653e0d30d52eea`。后续只维护仓库版本。启动依据为用户附件 `ZenPlayer_Codex_OpenSpec_Bootstrap.md`；其安装步骤是首次接入任务，不是每次开发重跑的规则。

2026-09-26 用户决策：macOS 不要求多窗口，M1 改为单主窗口；验证聚焦播放、暂停、切集、续听、下载及正常退出等主流程，不扩展重复切换压力或极端组合。已有失败与未验证项继续如实记录；详见 M1／M2 verification.md。

## Now · M0 先保住进度

- 问题／价值：最近 10 条会挤掉旧进度，损坏／写入异常保护不足；长期收听记录需要先独立保护。
- 包含：长期存储、最近派生、原键迁移、失败恢复、保存时机与防零覆盖、完成／重听、现有播放器和历史最小适配、自动化与真机验证计划。
- 不包含：全局会话、迷你条、自动连播、首页卡、系列状态 UI／搜索定位、云同步、下载／降噪重构。
- 依赖：不等待 M1；获批后先建立测试 target，验证旧键身份，再迁移。
- PRD：F2-03～F2-06、D-01／D-02 进度子集、Q-01／Q-04 相关约束，F1-04 切源保护子集。
- 验收：AT-16／AT-17／AT-18／AT-20／AT-21；AT-19 仅删除下载；AT-11 切源和 AT-06 保存子断言。其余跨阶段部分见验证追踪表。
- 状态：**In Verification**；规划：**已批准**。代码及测试已接入，6/13 项满足完整完成条件。阻塞：iPhone Developer Mode 未开启；原生控件／后台／PiP、升级和旧能力操作回归待验。
- 变更：[preserve-playback-progress](openspec/changes/preserve-playback-progress/proposal.md)；[设计](openspec/changes/preserve-playback-progress/design.md)；[规格](openspec/changes/preserve-playback-progress/specs/playback-progress/spec.md)。
- 验证证据：两端构建与隔离自动化已通过，实际测试数量及未验项见[验证记录](openspec/changes/preserve-playback-progress/verification.md)。文档完成不改变阶段状态。

## Next · M1 统一会话

- 问题／价值：页面持有播放器，返回可能停播；让浏览和控制页面共享唯一会话。
- 包含：全入口会话路由、跨页面播放、迷你条、完整页／iOS 系统控制一致、暂停／停止／中断、请求版本隔离、平台生命周期。
- 不包含：系列自动连播、首页续听卡和搜索；不只删除 onDisappear 停止逻辑。
- 依赖：集成 M0 进度接口；macOS 采用单主窗口，保持本地优先与降噪回退。
- PRD：F1-01～F1-04、D-02、Q-01～Q-03；验收 AT-01～AT-06、AT-11，AT-12 的跨页／PiP／窗口部分；AT-04 首页续听整合留 M3。
- 状态：**In Verification**；代码 review／修复与两端自动化完成，本轮授权本地提交，4/6 项满足完成条件。跨页与主要迷你条 UI 已有局部证据；单窗口关闭／重启、可访问性及真实 iPhone 生命周期见当前验证记录；M0 设备验收缺口继续保留。
- 变更：[unify-playback-session](openspec/changes/unify-playback-session/proposal.md)；[验证记录](openspec/changes/unify-playback-session/verification.md)。

## 后续 · M2 系列连播

- 问题／价值：播完需手动找下一集；按真实系列顺序继续收听。
- 包含：完整已加载系列快照及完整性标记、顺序／前后切集、持久化连播设置、类型回退、失败暂停和手动重试、防重复推进。
- 不包含：搜索结果作为队列、静默跳过坏集、猜测缺集、复杂自定义队列或下载重构。
- 依赖：M1 会话、M0 进度；M3 入口继续传递上下文，M4 搜索不改变快照。
- PRD：F1-05～F1-07、D-01／D-02、Q-01／Q-02／Q-04；验收 AT-07～AT-10、AT-12 自动切集；AT-09 搜索整合在 M4 重验，AT-15 下一集候选在 M3 整合。
- 状态：**In Verification**；代码、review 修复和两端 58 项测试通过，5/6 项完成；真实连播／锁屏／PiP、UI 与 M4 搜索整合待验。M0／M1 设备验收缺口保留。
- 变更：[play-series-in-order](openspec/changes/play-series-in-order/proposal.md)；[验证记录](openspec/changes/play-series-in-order/verification.md)。

## 后续 · M3 首页与系列续听

- 问题／价值：首页缺直达续听，系列内看不到听到哪；减少找回内容的操作。
- 包含：本地独立续听卡、明确候选规则、单集状态、系列上次收听定位、历史／下载／首页系列上下文传递。
- 不包含：云同步、远端行为埋点、搜索引擎和队列重构。
- 依赖：M0／M1，与 M2 队列集成；清筛选定位与 M4 联调。
- PRD：F2-01／F2-02，复用 F2-03～F2-06，F3-03 定位联动；验收 AT-13～AT-15、AT-19 定位部分，复验 AT-04 首页续听及 AT-16／AT-18 展示。
- 状态：**In Verification**；代码、review 修复和两端 71 项测试通过，5/6 项完成；实际首页／系列 UI、可访问性与 M4 清筛选联调待验。M0～M2 设备缺口保留。
- 变更：[surface-listening-progress](openspec/changes/surface-listening-progress/proposal.md)；[验证记录](openspec/changes/surface-listening-progress/verification.md)。

## 后续 · M4 搜索与总验收

- 问题／价值：长列表找课慢；页内确定性搜索、集数直达并验证整轮质量。
- 包含：当前分类／系列检索、简繁／全半角／多词匹配、episode 精确定位、未完整加载／离线／零结果反馈、性能与可访问性、全量 AT 和旧能力回归。
- 不包含：全站抓取／搜索、拼音／语义搜索、目录离线缓存、AI 推荐。
- 依赖：搜索可独立开发，持续目标已批准本阶段实施；整合验收依赖 M0～M3，搜索不得改动 M2 队列。
- PRD：F3-01～F3-04、Q-01～Q-04、第 09～12 节；验收 AT-22～AT-26，整合 AT-09／AT-19，最终 AT-01～AT-26 全量及下载／分享／降噪／音量增强等回归。
- 状态：**In Verification**；搜索／定位实现、review 修复和两端 86 项测试通过，5/6 项完成；总验收矩阵已登记，真机／实际 UI／端到端性能及旧能力回归待验，不能标 Done。
- 变更：[search-loaded-catalog](openspec/changes/search-loaded-catalog/proposal.md)；[验证记录](openspec/changes/search-loaded-catalog/verification.md)。

## 当前代码基线与差异

读取基线 `main @ a86d74a4b35d7aea330be48480727d8652210914`，开始时工作区干净，和 PRD 的历史源码提交一致，没有为匹配附件切分支或回退。

发现实现但未验收：`RecentPlaybackStore.upsertRecord` 把持久化数据截为 10 条，读取／编码异常删除旧键；`RecentPlaybackRecord.recordID` 沿用原 URL；`PlayerViewModel` 已有恢复、每 5 秒媒体位置差保存和 stop 保存，但无独立 completed，seek 结果未检查，切源先读存储再保存当前位置。`PlayerView` 持有播放器，`HomeView` 只有分类，`SeriesDetailViewModel` 直接使用 rows，播放上下文无队列。详见 M0 提案／验证记录。

仓库旧参考说明提到宽屏 `NavigationSplitView`，当前 `ContentView` 实际是 `NavigationStack + TabView`；规划按代码事实，不修改旧参考文档。App target 显式 iOS 17／macOS 14（project 层另有 macOS 26.2，target 覆盖）；工程仅一个 app target／scheme，无测试 target。此差异不影响产品方向。

## 候选区与决策记录

候选区暂无新增项；云同步、账号、收藏／笔记、倍速／睡眠定时等 PRD 非目标不自动进入本轮。

| 日期 | 决策 | 原因及影响 |
| --- | --- | --- |
| 2026-09-26 | 采用 PRD + Roadmap + OpenSpec；只细化 M0 | 产品方向已确定，避免并行任务数据库 |
| 2026-09-26 | 复用 OpenSpec 1.8.0，Codex/core 项目接入 | 不升级 CLI，不修改用户级配置，保留原有自定义技能 |
| 2026-09-26 | M0 推荐逐条原子文件与最近派生 | 隔离单条损坏、复用原接口；细节和风险在设计中，待评审 |
| 2026-09-26 | M0 维持 Planned／待评审 | 本轮仅工具与规划；不 apply、sync、archive 或进入 M1 |
