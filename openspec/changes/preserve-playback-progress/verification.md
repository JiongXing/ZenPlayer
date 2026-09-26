# M0 验证与交接记录

**功能尚未实施／本轮未执行功能验收。** 阶段 Planned，提案待评审。规划检查只证明文档和工具接入；不能替代构建、测试、设备验收或发布批准。本文件是项目附加的验证记录，不是 OpenSpec 内建 artifact。

## 基线、输入与现有证据

- 日期：2026-09-26；根目录 `/Users/jxing/Desktop/my_projects/ZenPlayer`；分支 `main`；HEAD `a86d74a4b35d7aea330be48480727d8652210914`；初始 `git status --short` 无输出。没有已有未提交工作需要合并，后续仍不清理用户文件。
- 完整读取用户指定 `/Users/jxing/Desktop/ZenPlayer_PRD_v1.0.md` 和 `/Users/jxing/Desktop/ZenPlayer_Codex_OpenSpec_Bootstrap.md`；[PRD 仓库唯一版本](../../../Documents/PRD/prd.md) 原样保存。当前源码与 PRD 历史提交一致。
- 已读根 [AGENTS.md](../../../AGENTS.md)、[项目技能](../../../.codex/skills/zenplayer-project/SKILL.md) 及其 reference；在相关目录和父目录未发现适用 override。旧 reference 的宽屏 SplitView 说明与当前 `ContentView` 不符，规划采用实际 NavigationStack，不改旧 reference。
- 存储、播放器关键事实见 [proposal.md](proposal.md) 的证据表；均为发现实现、未验收。`RecentPlaybackRecord` 可兼容缺少位置字段，但不是完整迁移机制；`PlayerViewModel.restorePlaybackPositionIfNeeded` 忽略 seek 成功值，`reloadCurrentPlayback` 在实际收听前更新最近。
- `ZenPlayer/ContentView.swift` 和 `ZenPlayerApp.swift` 无共享播放会话注入；`PlayerView` 持有模型；`RecentPlaybackListView`／`CompletedDownloadListView` 直接构造播放页。`SeriesDetailViewModel.loadSpeechDetail` 使用 `data.rows`，`EpisodeRowView` 仅传单集和 serverUrl；没有完整系列快照。`HomeView` 仅分类加载分支。
- `DownloadManager.removeCompletedDownload`／`completedFileURL` 只管理下载文件与清单，没有进度删除调用；需回归验证，不凭源码标记 AT-19 通过。
- `project.pbxproj`：Swift 5，App target iOS 17／macOS 14，项目层 macOS 26.2 被 target 显式覆盖；Xcode 查询确认仅 `ZenPlayer` target／scheme，Debug／Release，无 XCTest target。没有更改任何构建配置。

## PRD → 规格场景 → 实施任务 → 验证追踪

R／S 定义见 [规格](specs/playback-progress/spec.md)，稳定任务编号见 [tasks.md](tasks.md)。下表所有功能用例状态均为 **未运行**。

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

所有下列测试为拟建立／拟执行，不存在已通过的测试代码。采用隔离目录和专用 UserDefaults，禁止用真实用户历史做故障注入。

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

## 未执行项、阻塞和下一步

- 未执行 macOS／iOS 构建、XCTest、功能与真机验收：本轮限定文档和工具接入，尚未实现 M0，也无测试 target。AGENTS 的两端构建门槛适用于后续代码交付／PR，本轮不制造构建工作。
- 未执行 apply、sync、archive、commit、push、PR、分支切换、远端／用户级配置修改；没有访问真实 App 容器或清理播放／下载数据。
- 工具接入无阻塞；M0 实施尚未批准。当前无需要用户补充的产品决策。主要工程待验证项为旧键唯一性、原生暂停／拖动事件覆盖、后台写入完成窗口与音视频时长差异，详见 [design.md](design.md)。
- 下一步：用户评审并批准 M0 实施后，从 tasks 1.1 开始；不重跑 Bootstrap，不提前进入 M1。未来构建命令遵循 AGENTS；测试 target 建立后拟运行 `xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' test` 及 iOS Simulator 等价命令，执行前用可用设备名／ID 替换目的地，本轮未运行这些命令。

## 实际产物清单

- [PRD](../../../Documents/PRD/prd.md)、[ROADMAP.md](../../../ROADMAP.md)、[AGENTS.md 增量规则](../../../AGENTS.md)、[config.yaml](../../config.yaml)。
- [proposal.md](proposal.md)、[design.md](design.md)、[tasks.md](tasks.md)、本 verification、[能力规格](specs/playback-progress/spec.md)、[CLI 元数据](.openspec.yaml)。
- CLI 生成的项目集成：[propose](../../../.agents/skills/openspec-propose/SKILL.md)、[explore](../../../.agents/skills/openspec-explore/SKILL.md)、[update-change](../../../.agents/skills/openspec-update-change/SKILL.md)、[apply-change](../../../.agents/skills/openspec-apply-change/SKILL.md)、[sync-specs](../../../.agents/skills/openspec-sync-specs/SKILL.md)、[archive-change](../../../.agents/skills/openspec-archive-change/SKILL.md)，以及 [.openspec-target](../../../.agents/skills/.openspec-target)。仅读取并采用 propose 的规划流程；其余技能生成不代表执行授权。
