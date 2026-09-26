# M0 验证与交接记录

**M0 已获批准，In Verification，尚未达到 Done 门槛。** 本次起点 main @ f4e1806，工作区干净。以下规划记录保留为历史，当前结果见文末实施记录。规划检查只证明文档和工具接入；不能替代构建、测试、设备验收或发布批准。本文件是项目附加的验证记录，不是 OpenSpec 内建 artifact。

## 基线、输入与现有证据

- 日期：2026-09-26；根目录 `/Users/jxing/Desktop/my_projects/ZenPlayer`；分支 `main`；HEAD `a86d74a4b35d7aea330be48480727d8652210914`；初始 `git status --short` 无输出。没有已有未提交工作需要合并，后续仍不清理用户文件。
- 完整读取用户指定 `/Users/jxing/Desktop/ZenPlayer_PRD_v1.0.md` 和 `/Users/jxing/Desktop/ZenPlayer_Codex_OpenSpec_Bootstrap.md`；[PRD 仓库唯一版本](../../../Documents/PRD/prd.md) 原样保存。当前源码与 PRD 历史提交一致。
- 已读根 [AGENTS.md](../../../AGENTS.md)、[项目技能](../../../.codex/skills/zenplayer-project/SKILL.md) 及其 reference；在相关目录和父目录未发现适用 override。旧 reference 的宽屏 SplitView 说明与当前 `ContentView` 不符，规划采用实际 NavigationStack，不改旧 reference。
- 存储、播放器关键事实见 [proposal.md](proposal.md) 的证据表；均为发现实现、未验收。`RecentPlaybackRecord` 可兼容缺少位置字段，但不是完整迁移机制；`PlayerViewModel.restorePlaybackPositionIfNeeded` 忽略 seek 成功值，`reloadCurrentPlayback` 在实际收听前更新最近。
- `ZenPlayer/ContentView.swift` 和 `ZenPlayerApp.swift` 无共享播放会话注入；`PlayerView` 持有模型；`RecentPlaybackListView`／`CompletedDownloadListView` 直接构造播放页。`SeriesDetailViewModel.loadSpeechDetail` 使用 `data.rows`，`EpisodeRowView` 仅传单集和 serverUrl；没有完整系列快照。`HomeView` 仅分类加载分支。
- `DownloadManager.removeCompletedDownload`／`completedFileURL` 只管理下载文件与清单，没有进度删除调用；需回归验证，不凭源码标记 AT-19 通过。
- `project.pbxproj`：Swift 5，App target iOS 17／macOS 14，项目层 macOS 26.2 被 target 显式覆盖；Xcode 查询确认仅 `ZenPlayer` target／scheme，Debug／Release，无 XCTest target。没有更改任何构建配置。

## PRD → 规格场景 → 实施任务 → 验证追踪

R／S 定义见 [规格](specs/playback-progress/spec.md)，稳定任务编号见 [tasks.md](tasks.md)。下表为规划时追踪关系；当前状态以文末实施结果表为准。

| PRD 条目 | Requirement／Scenario | Task | 验证用例与 AT 子断言 |
| --- | --- | --- | --- |
| F2-03／F2-05 | R1 S1～S2 | 2.1、3.2、5.1 | U-03、I-01；AT-16：30 条长期／10 条最近／第 1 条重启恢复 |
| F2-06、D-01 | R2 S3～S4 | 1.1、1.2、3.1 | U-01、U-02；AT-20-key：原键、URL、可选字段、身份碰撞保护 |
| F2-06 | R3 S5～S7 | 3.1、5.2 | U-07、D-02；AT-20-normal／repeat／failure：正常映射、重入、每步失败 |
| F2-05／F2-06 | R4 S8～S9 | 1.2、2.2、3.1 | U-02、U-05；AT-20-missing／AT-21-corrupt：缺字段、单条损坏、主备恢复 |
| F2-05、D-02 | R5 S10～S11 | 2.2、2.3、4.4 | U-05、U-06、I-04；AT-21-write／retry：空间不足／替换失败／提示／重试 |
| F2-04、Q-01 | R6 S12～S13 | 2.1、4.1、5.2 | U-08、I-02、D-01；AT-17-save／restart：周期、暂停、拖动、停止、切目标、前后台、异常退出；AT-06-save |
| F2-04、D-02 | R7 S14～S15 | 4.2 | U-09、I-02；AT-17-restore：准备零保护、seek 失败、旧回调拒绝 |
| F2-04／F2-06 | R8 S16～S18 | 2.1、4.3 | U-04、I-03；AT-18-unknown／replay／near-end：未知时长、实际重听、近尾不完成 |
| F1-04、F2-04／F2-05 | R9 S19 | 4.3 | U-10、I-03；AT-11-switch：即时位置、暂停意图、失败不写 0 |
| F2-05、Q-01 | R10 S20～S21 | 4.1、5.1 | I-05；AT-19-delete：删除下载不删进度；列表变化不删除；搜索整合待 M4 |

## 自动化、集成与真机方案

下表保留批准时的测试设计；已实现的测试和实际结果见文末，不将尚未执行的部分视为通过。采用隔离目录和专用 UserDefaults，禁止用真实用户历史做故障注入。

| ID／层级 | 输入和方法 | 必须观测的结果 |
| --- | --- | --- |
| U-01 单元 | 旧 JSON fixture，原 URL 尾斜线／大小写、相同标题不同键、缺媒体／系列字段、代表性跨系列样本 | 原始键和位置不变，缺字段兼容；确认样本身份边界，不用标题猜测 |
| U-02 单元 | 合法旧数组混正常／缺位置／缺关键上下文／重复键；另给整体破损来源 | 有效项独立恢复、缺位置 0、重复规则确定、损坏来源保留；不把整段解析失败当空历史写回 |
| U-03 单元＋文件重读 | 依次写 30 集并重新实例化，推进旧集，再注入准备失败；补更大规模样本计时 | 所有记录保留、最近仅 10、最近时间只随实际推进；无按时间淘汰；记录启动／查询成本 |
| U-04 单元 | 未知时长结束、已完成重听失败／未推进／首次推进、拖到 95%、无效数值、可信时长和元数据冲突 | 状态独立；只有自然结束完成；重听推进才更新；无效值不覆盖，时长优先级正确 |
| U-05 文件／故障注入 | 单文件损坏、备份有效／无效、未知高版本；临时写、备份、替换、读回逐点失败或中断 | 其他记录可读，旧主文件不先删；有效备份可恢复且损坏原件保留；不能确认未提交值为成功 |
| U-06 并发／故障注入 | 阻塞旧写入回执，提交更高修订；模拟不可写后恢复并重试 | dirty 新值不被旧回执清除，最终落盘最新值；错误状态解除仅在对应值成功后 |
| U-07 迁移 | 每一步中断重入、标记失败、迁移中用户写新值、损坏新文件与旧来源同时存在 | 覆盖集合对账、幂等、不回退新值、旧键／备份不删；隔离数和完成数真实 |
| U-08 保存调度 | 可控时钟推进和事件序列：播放、暂停、拖动到 0、切目标、stop、前后台 | 正常可写时成功提交间隔 ≤5 秒；动作即时采样提交而不等 tick，不靠终止回调 |
| U-09 恢复门控 | 120 秒旧值，准备时 stop、seek false、请求 A 后 B、A 的迟到 tick／seek／结束 | 保留旧值且身份不串写；恢复失败可重试，不把默认零落盘 |
| U-10 切源 | 上次存 100 秒、当前 103 秒暂停，切源成功／失败、目标时长更短 | 抓 103 秒而非 100，按可信时长限制，保持暂停；失败保留旧有效位置 |
| I-01 应用集成 | 历史／系列／下载三个入口、30 集记录、冷启动、迁移启动顺序 | 原接口使用同一仓库，最近展示不裁剪长期数据，无旧 singleton 提前删键 |
| I-02 应用集成 | iOS 原生控制、macOS VideoPlayer、锁屏拖动／暂停、切源、scenePhase 保存与强制退出 | 每条实际控件路径可观测到对应保存与恢复，初始零不覆盖；退出恢复最后成功值 |
| I-03 应用集成 | 音频／音视频／未知时长样本，重听和自然结束 | 与 U-04／U-10 规则一致，完成后 stop 不清掉完成，暂停切源不误播放 |
| I-04 应用集成 | 可控失败存储配合播放／历史页 | 指定繁体非阻断提示和重试有效；不能以播放错误页面遮住原有播放／浏览 |
| I-05 应用回归 | 删除下载后查／播、文件缺失映射清理、列表刷新；原分类排序、下载暂停恢复、分享、源回退、降噪／增强 | 进度／身份不变；旧能力不因 M0 改动回退；搜索 UI 场景留后续 |
| D-01 真机 | iPhone 后台／锁屏／PiP 下暂停拖动、保存后强制终止；macOS 实际窗口失焦、关闭／退出后重开 | 验证 M0 保存恢复，不把 M1 跨页持续／M2 自动切集算通过；记录平台生命周期差异 |
| D-02 升级演练 | 测试安装的可恢复旧样本升级、重复启动、故障后前向修复 | 有效记录键／数／位置／状态逐项对账，无丢失／重复，未解析项明确保留和报告 |

每次实际执行记录：代码提交及工作区差异、设备型号、系统版本、构建号、媒体样本标识／音视频类型／来源及可信时长、命令或操作步骤、预期／实际、通过／失败／未运行、日志或 xcresult 路径。只记本地必要诊断，不上传课程标题、媒体 URL、查询原文或收听轨迹。

## 跨阶段验收与完成门槛

- AT-16／AT-18／AT-20／AT-21 为 M0 直接主线；AT-17 的现有动作、切目标接口和退出恢复在 M0 测，M1／M2 新会话与自动切集再整合回归，不能预报后续路径通过。
- AT-19-delete 是 M0；AT-19-locate（系列定位及清搜索／高亮）由 M3／M4 实现和验证。不得以删除下载子断言通过将 AT-19 整项标记通过。
- AT-11-switch 是 M0 的必要切源保护；全局控制一致性由 M1 验证。AT-06-save 只验证进度落盘，中断后的播放意图规则由 M1 验证。
- AT-01～AT-06 其余部分、AT-12 会话／自动换集由 M1／M2；AT-07～AT-10 由 M2（AT-09 搜索整合 M4）；AT-13～AT-15 由 M3；AT-22～AT-26 由 M4。AT-04 首页续听在 M3 补齐。全部 AT-01～AT-26 当前均未验收。
- M0 Done 门槛：13 项实施任务有真实证据、对应 U／I／D 用例与两个平台构建通过，M0 全部子断言及受影响旧能力回归完成，迁移数据对账和故障保留通过，无数据丢失／进度清零等阻断项。缺设备或环境时保持 In Verification 并注明，不要求先实现 M1～M4。
- 整轮发布仍需 PRD AT-01～AT-26、进度／队列／搜索单元测试及原能力回归、iPhone 后台／PiP 和 macOS 生命周期真机证据；M0 完成不能冒充整轮发布可用。

## 本轮实际执行的规划检查

以下命令均在仓库根目录运行；OpenSpec 命令使用 `OPENSPEC_TELEMETRY=0`，仅影响当前命令，不改全局偏好。

| 命令／检查 | 实际结果与证据边界 |
| --- | --- |
| `git rev-parse --show-toplevel`、`git branch --show-current`、`git rev-parse HEAD`、`git status --short` | 初始根／分支／提交如上，工作区干净 |
| `openspec --version`、`node --version`、`npm --version` | 已有 CLI 1.8.0，Node v26.3.0、npm 11.16.0；未安装或升级工具 |
| `openspec --help` 及 init／new change／status／instructions／templates／validate 的 `--help` | 本机支持所用参数，无 force／全工具初始化 |
| `openspec init --tools codex --profile core --no-animation` | 退出 0；创建 config 和 `.agents/skills/` 下 6 个技能，原 `.codex/skills/` 保留 |
| `openspec templates --schema spec-driven --json` | 找到本机包 proposal／spec／design／tasks 模板并实际读取 |
| `openspec new change preserve-playback-progress` | 退出 0；生成 `.openspec.yaml`，schema 为 spec-driven |
| `openspec instructions proposal --change preserve-playback-progress --json`（design／specs／tasks 同式） | 逐步取得指引和模板，按依赖读取已保存 artifact 后写下一项；未执行 apply 指引 |
| `openspec status --change preserve-playback-progress --json` | 四个 artifact 均 done，`isPlanningComplete: true`；1.8.0 同时输出的 `isComplete: true` 仅指规划文件完整，不是实施完成 |
| `openspec validate preserve-playback-progress --strict --no-interactive` | 退出 0：`Change 'preserve-playback-progress' is valid`；只证明规格结构 |
| `xcodebuild -list -project ZenPlayer.xcodeproj -disableAutomaticPackageResolution -skipPackageUpdates` | 退出 0；仅 ZenPlayer target／scheme，Debug／Release；Xcode 拉取并检出 Kingfisher 8.6.2 到缓存，仓库锁文件未改；这是结构查询，不是 build 或 test |
| `git diff --check` | 退出 0；新增未跟踪文件另用下面的内容检查覆盖 |

补充执行 `python3 - <<'PY' ... PY` 内联文档审计（未向仓库加入测试代码）：读取全部 16 个新文件的 UTF-8 内容，逐项检查作者文档中的 47 个相对文件链接均存在；检查 13 个任务编号唯一且全部未勾选、10 条 requirement／21 个 scenario；核对 PRD 字节和 SHA-256 与附件一致、AGENTS 原内容完整保留。结果全部通过。

同一审计通过 Git 文件清单核实：已有跟踪文件只有 AGENTS.md 增量变化；业务代码、资源、Xcode 工程、依赖锁文件和原自定义技能均未修改；暂存区为空、main／HEAD 未变。`openspec/specs/` 为空，仅存在一个 M0 变更；6 个生成技能的元数据均为 OpenSpec 1.8.0。新文件除 CLI 所需 `.openspec-target` 外均为 Markdown／YAML。没有创建第二套任务框架或修改 CI。规划检查不计入实施任务完成数。

## 启动规划时的未执行项、阻塞和下一步（历史记录）

- 未执行 macOS／iOS 构建、XCTest、功能与真机验收：本轮限定文档和工具接入，尚未实现 M0，也无测试 target。AGENTS 的两端构建门槛适用于后续代码交付／PR，本轮不制造构建工作。
- 未执行 apply、sync、archive、commit、push、PR、分支切换、远端／用户级配置修改；没有访问真实 App 容器或清理播放／下载数据。
- 工具接入无阻塞；M0 实施尚未批准。当前无需要用户补充的产品决策。主要工程待验证项为旧键唯一性、原生暂停／拖动事件覆盖、后台写入完成窗口与音视频时长差异，详见 [design.md](design.md)。
- 下一步：用户评审并批准 M0 实施后，从 tasks 1.1 开始；不重跑 Bootstrap，不提前进入 M1。未来构建命令遵循 AGENTS；测试 target 建立后拟运行 `xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' test` 及 iOS Simulator 等价命令，执行前用可用设备名／ID 替换目的地，本轮未运行这些命令。

## 实际产物清单

- [PRD](../../../Documents/PRD/prd.md)、[ROADMAP.md](../../../ROADMAP.md)、[AGENTS.md 增量规则](../../../AGENTS.md)、[config.yaml](../../config.yaml)。
- [proposal.md](proposal.md)、[design.md](design.md)、[tasks.md](tasks.md)、本 verification、[能力规格](specs/playback-progress/spec.md)、[CLI 元数据](.openspec.yaml)。
- CLI 生成的项目集成：[propose](../../../.agents/skills/openspec-propose/SKILL.md)、[explore](../../../.agents/skills/openspec-explore/SKILL.md)、[update-change](../../../.agents/skills/openspec-update-change/SKILL.md)、[apply-change](../../../.agents/skills/openspec-apply-change/SKILL.md)、[sync-specs](../../../.agents/skills/openspec-sync-specs/SKILL.md)、[archive-change](../../../.agents/skills/openspec-archive-change/SKILL.md)，以及 [.openspec-target](../../../.agents/skills/.openspec-target)。仅读取并采用 propose 的规划流程；其余技能生成不代表执行授权。

## M0 实施记录（2026-09-26）

- 授权：仅 M0 实施及验证；不 sync、archive、commit、push、PR 或发布。
- 1.1 进行中：建立不启动 App 的独立 XCTest bundle；直接编译实际模型源文件，隔离数据。为此将 PlaybackContext／PlaybackMediaType 原样移至 Models，不改变行为。

### 1.1 通过

- macOS arm64、iPhone 17 模拟器 iOS 27.0 均运行并通过 `testLegacyKeyAndMissingPositionRemainCompatible`。XCTest bundle 无 TEST_HOST，不启动生产 App。
- 命令：`xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination <目的地> -derivedDataPath /tmp/ZenPlayer-M0-<平台> -resultBundlePath <结果路径> test`。
- macOS 目的地 `platform=macOS`，结果 `/tmp/ZenPlayer-M0-1-1-mac.xcresult`，日志同名前缀 `.log`。iOS 目的地 `platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425`，结果 `/tmp/ZenPlayer-M0-1-1-ios.xcresult`，日志同名前缀 `.log`。
- 两端均 `TEST SUCCEEDED`，App 构建随 scheme 通过；这不是 App 控件或设备功能验证。隔离 defaults／临时目录、TestClock 和 TestIOFaults 已建立，后两者待后续行为测试使用。

### 1.2 通过（代表样本范围）

- 三份仓库抓包提取响应字段，不复制请求凭据：13-009（5 集）、13-001（6 集）、17-013（5 集），16 个原始键均唯一。`identity-ledger.json` 逐条记录来源、num、原键；不推断全站唯一。
- 已建立正常、缺位置／偏好、重复、坏上下文、未知时长和整体破损 fixture。3 个 XCTest 在 macOS 通过，结果 `/tmp/ZenPlayer-M0-1-2-mac.xcresult`。U-01 通过；U-02 的解码边界通过，实际迁移去重／隔离须在 3.1 重验。
- 未发现需改变身份合同的冲突；继续 2.1。

### 2.1 通过

- 版本化 PlaybackProgress：长期集合查询／最近派生、独立 completed、实际收听时间、时长优先级、非法数值拒绝、完成后未推进保护。
- U-03 内存查询与 U-04 状态规则通过；5 个 XCTest（含已有 3 个）通过，`/tmp/ZenPlayer-M0-2-1.xcresult`。30 条冷启动文件重读待 2.2。
- 1.2 iOS 复验 3 个测试通过：`/tmp/ZenPlayer-M0-1-2-ios.xcresult`。

### 2.2 通过

- 单队列执行逐条 JSON 写入，候选读回验证→有效旧值原子备份→同卷 rename→主文件读回；没有先删主文件。损坏主文件只能从有效备份恢复并保留损坏字节，高版本拒绝覆写。
- U-03 的 30 条磁盘冷读及 U-05 的单条损坏／有效备份／未知版本／临时写、读回、备份、替换故障注入通过。共 7 测试通过：`/tmp/ZenPlayer-M0-2-2.xcresult`。故障测试验证旧主文件字节不变。真实进程各中断点演练仍属 D-02，未运行。

### 2.3 通过

- 主 actor 维护最新记录与 dirty；串行磁盘回执仅确认相同修订；写入失败不删除内存，重试批次只取最新值。
- U-06 延迟旧回执＋较新修订＋失败、恢复可写重试通过。9 个测试通过：`/tmp/ZenPlayer-M0-2-3.xcresult`。保存错误只在 dirty 清空后撤销。

### 3.1 通过

- 原始源摘要备份先行；逐项容错、最新 playedAt 去重、同时间保留前项，检测 num 冲突停止歧义映射；已有新记录优先，损坏占用键禁止旧值覆盖；覆盖集合核对后才写原子完成标记。
- U-01／U-02／U-07：混合数组、备份字节、去重、重入、新值保护、坏来源、身份冲突、坏新文件，以及备份／写入／读回／替换／标记失败重试均通过。13 个测试通过：`/tmp/ZenPlayer-M0-3-1.xcresult`。旧键始终保留。

### 3.2 接口测试通过，任务待完整 I-01 验证

- RecentPlaybackStore 已变为唯一长期仓库的薄适配器，不再读取／写入或异常删除旧键；启动先读新库再迁移。未知时长展示不再编造百分比；独立 completed 展示与恢复生效。
- U-03＋I-01 的接口级测试：16 条旧记录迁移后最近 10 条，另外写入 30 条并重建仓库，46 条均保留，第 1 条可查询，旧键字节不变；系列可选字段往返通过。14 个测试通过：`/tmp/ZenPlayer-M0-3-2.xcresult`。三个真实 UI 入口操作仍待 5.1；未把接口测试记作人工操作通过。

### 4.1～4.4 实现已接入，验证未完成

- 4.1：周期按单调时钟每 4 秒发起提交，暂停 rate 变化、显式 seek 完成、切源／stop／scenePhase 即时采样；iOS 有限后台任务窗口，macOS 退出通知同步提交。成功提交间隔的可控时钟测试通过，但正常设备运行时 ≤5 秒尚待 D-01 实测，不能以请求间隔冒充成功提交间隔。
- 4.2：当前 player／item／token 三重检查，ready 且 seek true 才开放门控；准备期间 stop、失败 seek、旧 token 事件单元验证通过。显式连续 seek 另有请求身份；实际准备／恢复失败的 UI 路径尚未操作验收。
- 4.3：独立 ended 状态、重听首个真实推进、拖动不更新收听时间、切源先采即时位置和暂停意图；未知时长和切源数据规则已测，真实音视频切源暂停意图待 I-03。
- 4.4：播放器和历史页内联繁体保存／恢复提示及重试；与媒体错误分离，无 alert。存储故障／重试自动化通过，实际 UI 故障注入待 I-04。
- `/tmp/ZenPlayer-M0-4-gate.xcresult`、`/tmp/ZenPlayer-M0-4-player.xcresult`：macOS 16 个测试通过。`/tmp/ZenPlayer-M0-4-ios.xcresult`：iPhone 17 模拟器 iOS 27.0 构建及 16 个测试通过。
- `/tmp/ZenPlayer-M0-review-mac.xcresult`：macOS 20 个测试通过，包含真实 AVPlayer 本地 4 秒静音 WAV 的 ready、seek 成功、TimeJumped、rate 暂停和自然结束信号。仅证明 AVPlayer API，不证明 AVKit 原生控件、锁屏或 PiP。
- 1000 条记录 macOS 本地测试：冷读 0.0676 秒，最近查询 0.0029 秒（一次样本，非 P95）；没有据此承诺真机全量性能。
- 4.1～4.4 保持未勾选，因为它们要求的 I／D 验证尚不完整；不降低完成门槛。

## 当前交付证据与剩余门槛

本次结束状态 **In Verification，6/13 项完成**。1.1／1.2／2.1／2.2／2.3／3.1 已勾选；3.2 接口实现和测试通过，但 I-01 要求的实际入口流程未完整运行，最终核对时保留未勾选。4.1～4.4 已实现，因 I／D 门槛未齐保持未勾选；5.1／5.2 未完成。不修改原有验收标准，不建议标记 M0 Done。

### 最终命令及结果

代码基线 `main @ f4e1806ce2bf8d85135a820f6b67312b0d23c626` 加本次未提交变更；App 1.1.0（110），部署版本仍 iOS 17／macOS 14。macOS 主机 27.0（26A428）、arm64；模拟器 iPhone 17／iOS 27.0。真实 AVPlayer 测试媒体为测试内生成的 4 秒、8 kHz、单声道 PCM 静音 WAV，位于每个测试的临时目录，播放器 muted，不使用远端媒体或真实收听记录。

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| macOS `xcodebuild … test` | **通过**：App 与独立测试 bundle 编译；25 测试、0 失败 | `/tmp/ZenPlayer-M0-acceptance-mac.log`、`/tmp/ZenPlayer-M0-acceptance-mac.xcresult` |
| iPhone 17 Simulator `xcodebuild … test` | **通过**：App 与独立测试 bundle 编译；25 测试、0 失败 | `/tmp/ZenPlayer-M0-remote-token-ios.log`、`/tmp/ZenPlayer-M0-remote-token-ios.xcresult` |
| 已连接 iPhone 的独立 bundle 测试尝试 | **环境失败／测试未运行**：目的地超时，Xcode 明确报告 `Developer Mode disabled` | `/tmp/ZenPlayer-M0-device.log`、`/tmp/ZenPlayer-M0-device.xcresult` |
| OpenSpec 严格校验及 apply context smoke | **通过**；规划完整不等于功能完成 | `OPENSPEC_TELEMETRY=0 openspec validate preserve-playback-progress --strict --no-interactive`；apply 返回实际未完成项 |
| 工程与范围审计 | **通过**：原 App target 对象及 Debug／Release buildSettings 逐项不变；PRD 原 SHA-256 不变，Info.plist／entitlements／依赖锁／DownloadManager 原字节不变 | 本轮 Python 对比 HEAD 与工作区；只新增测试 target／scheme 及实施所需文件 |

可复现的最终测试命令（结果 bundle 目标需要选用尚不存在的路径）：

```sh
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' -derivedDataPath /tmp/ZenPlayer-M0-mac -resultBundlePath /tmp/ZenPlayer-M0-acceptance-mac.xcresult test
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' -derivedDataPath /tmp/ZenPlayer-M0-ios -resultBundlePath /tmp/ZenPlayer-M0-remote-token-ios.xcresult test
```

真实 iPhone 尝试使用目的地 `platform=iOS,id=00008140-000C5C903E33001C`，独立 derivedData `/tmp/ZenPlayer-M0-device`，命令行签名参数 `DEVELOPMENT_TEAM=NTWSTCY88A CODE_SIGN_IDENTITY='Apple Development' CODE_SIGN_STYLE=Automatic`。未使用允许自动更新 provisioning 的参数，未更改项目签名，未开启设备 Developer Mode。命令在目的地可用性检查失败，没有运行测试或安装本次 App。

### 验证覆盖及明确的未验证项

| 用例 | 当前证据与限制 |
| --- | --- |
| U-01／U-02 | 通过：3 系列 16 键对账、旧缺字段、混合损坏、整体坏源、稳定去重、已知终点推断完成并保留原始超长位置；仅代表样本 |
| U-03 | 通过：30 条及迁移后共 46 条的重建读取、最近 10 条、真实收听时间排序；1000 条大样本读取／查询计时 |
| U-04 | 通过：未知时长结束、完成与重听保护、拖动近末尾、非法数值、可信时长优先；真实媒体操作见 I-03 未验 |
| U-05 | 通过：各提交故障点、坏主备、未知高版本只读有效备份且拒绝覆写、孤立临时文件、其他记录保持可读；没有冒充硬件断电测试 |
| U-06／U-07 | 通过：旧回执不能清新 dirty、失败保留内存和旧文件、恢复可写重试最新值；中断迁移后写新进度再重入、标记失败、坏新键保护 |
| U-08／U-09／U-10 | 门控／存储事件模型通过：可控时钟提交间隔、动作即时采样、合法 0、恢复失败／过期 token 拒绝、即时 103 秒切源值及短时长夹限；未将其等同 PlayerViewModel 全链路或真实控件测试，暂停意图等集成证据仍缺 |
| AVPlayer 平台信号探针 | 两端通过 ready、成功 seek、TimeJumped、rate 暂停、自然结束；未模拟 AVKit 手势的完整结束／取消序列 |
| I-01 | 部分通过：真实仓库＋旧接口适配、迁移启动顺序、30 条重建；历史／系列／下载三个 UI 入口操作未运行 |
| I-02／I-03／I-04 | 部分静态核对／组件自动化通过；原生控件、锁屏、音视频切源及暂停意图、失败横幅交互未运行 |
| I-05 | 静态核对 DownloadManager 删除／缺失映射清理不引用进度仓库，原文件字节未改；删除下载后播放、远端回退、下载暂停恢复、分享、RNNoise／增强的实际回归未运行 |
| D-01／D-02 | **未运行**：iPhone Developer Mode 阻塞；后台／锁屏／PiP、macOS 窗口关闭／退出、测试安装升级／异常退出故障演练均待执行 |

额外回归：自然结束后的迟到暂停回调不得撤销 completed；不足一个 tick 的实际播放暂停，不能被先到的 paused tick 吞掉。两项均加入 `PlaybackProgressGateTests` 并在最终两端运行通过。

性能单次测量：最终 macOS 1000 条冷读约 0.0651 秒、最近查询约 0.0033 秒；最终模拟器约 0.0963 秒／0.0030 秒。此前模拟器冷读出现约 1.40 秒，说明波动明显；未测真机 P95，也未证明主 actor 启动枚举在大历史量下满足交互目标。未用自动淘汰掩盖规模问题。

### 下一步与风险

- 先补 I-01～I-05 的隔离 App 集成和 D-01／D-02 的设备操作证据。iPhone 需可用于开发的测试设备；保留旧样本／备份，不对真实用户容器注入迁移故障。
- 原生控件时间跳变与拖动完成／取消的对应关系、正常设备成功提交间隔 ≤5 秒、后台执行窗口、退出保存及音视频时间轴差异仍需实测。测试探针与编译通过不能代替这些门槛。
- 无法恢复旧版已经淘汰或主备均不可解析的数据；未知高版本拒绝覆写，保持来源和诊断。macOS 多窗口播放竞争仍属 M1；M0 使用共享串行存储，不宣称已统一会话。
- M1 可复用 `PlaybackProgressStore.record/update/flush` 及进度门控合同；M2／M3 可读取／保留可选系列字段。未实施 M1～M4，未同步主规格、归档、commit、push、PR 或发布。

最终收尾：锁屏命令异步处理也校验当前媒体请求 token，防止移除旧命令后已排队回调作用于新媒体；此 iOS 分支修改后重新构建并运行 25 个测试、0 失败（`/tmp/ZenPlayer-M0-remote-token-ios.xcresult`）。macOS 条件分支未受此修改影响，复用其最终 25 测试证据。真实锁屏操作仍未验。

内容审计通过：39 个修改／新增文本文件（包含未跟踪文件）、49 个相对链接，shared scheme XML、新增繁体文案、正常 JSON fixture 可解析；`legacy-broken.json` 是有意保留的非法 JSON 故障样本，未错误当作有效配置。fixture 未包含抓包请求凭据。`git diff --check` 通过，暂存区为空，HEAD 仍为 `f4e1806`，主规格未同步。没有自动提交或推送。

## 当前阶段提交前审查（2026-09-26）

本次用户明确授权“review 并提交当前阶段代码”，仅增加本地提交授权，不包含推送、主规格同步、归档或 M0 完成确认。审查覆盖全部 39 个修改／新增文件、迁移／原子写入／dirty 修订、播放器身份门控与 UI 接入、独立测试 target 及文档状态。此前记录中的“未提交”描述其所在实施轮次，不再作为本次提交限制。

发现并修复：

- **P1 迁移重试与未落盘进度竞争**：首次迁移备份失败后，用户产生新进度，直接重试迁移会先把旧位置写入缺失键并标记迁移成功；若随后最新进度落盘失败，重启会看到旧值。新增 `testMigrationRetryDoesNotWriteLegacyValueWhileNewProgressIsDirty`，修复前实际失败（2 个断言）；现迁移在 dirty 非空时推迟，手动重试先等待最新进度提交后再迁移。
- **P2 极大旧位置显示崩溃**：迁移允许保留有限非负原始秒数，但显示层直接转换为 Int，会在超出整数范围时 trap。现在仅显示转换做边界保护，原始位置不裁剪；新增有限极大值／NaN／无穷的显示回归测试。

实际检查：

| 检查 | 结果／证据 |
| --- | --- |
| 修复前迁移定向回归 | **失败（预期复现）**：`/tmp/ZenPlayer-M0-review-regression-red.log`、同名前缀 `.xcresult`；随后修复，不作为最终未解决失败 |
| macOS 最终构建＋测试 | **通过**，27 测试／0 失败；`/tmp/ZenPlayer-M0-commit-review-mac.log`、同名前缀 `.xcresult` |
| iPhone 17 模拟器 iOS 27.0 最终构建＋测试 | **通过**，27 测试／0 失败；`/tmp/ZenPlayer-M0-commit-review-ios.log`、同名前缀 `.xcresult` |
| OpenSpec 严格校验、`git diff --check` | **通过** |
| 完整变更范围／文件审计 | **通过**：39 个文本文件含未跟踪内容；相对链接、scheme XML、文案 JSON、正常 fixture 可解析；故意损坏 fixture 单独保留。原 App target／Debug／Release 配置对象、PRD、签名、版本、依赖锁和 DownloadManager 与 HEAD 保持一致 |

本轮未复跑真机及 UI 集成操作，既有 Developer Mode 阻塞和 I／D 验证缺口仍有效。审查修复未降低任务完成条件，任务仍 **6/13**，Roadmap 仍 **In Verification**。本地阶段提交不等于 M0 验收或发布批准；尚缺原生控件、后台／锁屏／PiP、升级故障演练及下载／分享／源回退／降噪实际回归证据。

暂存后 `git diff --cached --check` 首次发现两个新模型文件末尾多余空行，已移除并重验通过；只有空白变化，复用上述构建／测试证据。

## 2026-09-26 macOS 删除下载与失败恢复补验

持续目标的 M1～M4 回归补充 M0 S20／AT-19-delete 的 macOS 子断言，未改存储／迁移／DownloadManager 生产实现。隔离验证 App 通过自己的完成下载索引播放静音 WAV（远端 .invalid），暂停／停止后在下载列表右键删除。无播种冷启动的只读断言确认实际文件已不存在、进度文件仍可解码且至少 30 秒；首页保留删除前位置。再从历史打开同集，远端失败出现重试，退出后重开位置仍未变。

最终 `/tmp/ZenPlayer-mac-entry-final-r4/tests.xcresult` **3 项、0 失败、118.909 秒**，其中 `testHistoryDownloadEntryAndDeletionRetainsProgress` 73.411 秒。构建、原生完整页崩溃修复、两端 86 项回归及复现／限制详见 [M1 记录](../unify-playback-session/verification.md#2026-09-26-mac-完整播放页崩溃与入口回归)。样本只在独立 bundle／sandbox 中生成，没有修改真实用户数据。

该证据不覆盖 iPhone 删除下载、外部目录书签授权、实际传输／分享、强杀／升级中断或真实媒体听感。5.1 及整个 M0 保持未完成验收，不因一个数据安全子断言通过改为 Done。
