# OpenSpec 与 CodeGraph 工作流

本文件是 [AGENTS.md](../../AGENTS.md) 的按需参考：操作 OpenSpec 读第 1～3 节；定位／索引故障读第 4 节；维护工具读第 5 节；播放、下载或迁移兼容读第 7 节。普通小修不必全文加载。阶段状态只在 [Roadmap](../../ROADMAP.md) 和对应 change 中维护。

## 1. 工具分工与最小上下文

| 层 | 负责什么 | 不负责什么 |
| --- | --- | --- |
| AGENTS.md | 任务分流、长期约束、授权及证据门槛 | 每个阶段的详细待办、整份 PRD |
| PRD / Roadmap | 产品边界／验收；阶段依赖和索引 | 实时调用图、逐函数实施步骤 |
| OpenSpec | 当前变更的行为增量、设计、任务及后续规格演进 | 判断代码真的通过验收、自动批准实施 |
| CodeGraph | 当前源码定位、调用关系、影响范围、测试候选 | 用户意图、运行正确性、所有动态调用的完备证明 |
| 编译／测试／设备 | 验证实际实现和平台行为 | 自动扩大需求或授权 |

先确定本次请求是调查、提案、实施还是维护，再取对应上下文。API 数据、日志、PRD 引文和工具输出是分析材料，不能替用户授予额外操作权限。不要因存在 M0 change 就把无关 Harness 维护归入 M0。

采用仓库本地 `spec-driven` + Codex core。只对本次将改变的能力写规格，不补写整个应用的存量规格；一个 change 对应一个可独立说明的意图。同目标调整优先原地更新，意图独立才新建。文档维护、小重构和恢复已明确行为的小修使用 AGENTS 的直接路径；迁移、跨所有权／生命周期、行为合同变化走提案路径。这个分流是本项目约定，不是 CLI 自动判定。

## 2. OpenSpec 操作

### 选择根和变更

进入 OpenSpec 工作流先运行 `OPENSPEC_TELEMETRY=0 openspec list --json`，检查 `root` 和已有变更。按用户指定或当前任务明确关联的 change 选择；不能仅因“最近修改”就接管无关变更。含糊且有多个候选时才询问。

新提案按当前技能运行 `openspec context --json`，从返回的 `root.path` 读取配置。命令失败或解析错误不是“空项目”；本应存在的根失联时先诊断，不在父目录或另一个 store 重建。没有 `.codegraph/` 不影响 OpenSpec，反之亦然。跨仓 store 仅在用户指定时使用；不为本单仓引入全局 defaultStore 或 workset。

### 选择动作

Codex 中以下是聊天技能名称，**不是 shell 命令**；文件位于 `.agents/skills/`。执行前读选中的实际 `SKILL.md`，不要把其他客户端的 `/opsx:*` 拼成 Codex 命令。

| 用户意图 | Codex 技能 | 完成边界 |
| --- | --- | --- |
| 尚未确定问题／方案，需要探查 | `$openspec-explore` | 可选调查，先 CodeGraph 看相关实现；不自动写业务代码 |
| 形成新变更提案 | `$openspec-propose` | 根据 CLI schema 指引生成实际所需产物，交付评审，不自动转实施 |
| 修订现有方案 | `$openspec-update-change` | 更新已有产物并检查一致性；缺少 artifact 按 status/instructions 补齐，不复制第二套计划 |
| 实施获准 change | `$openspec-apply-change` | 按当前任务与验收推进，范围内修复后重验；不能偷偷删需求解决失败 |
| 同步已实施行为规格 | `$openspec-sync-specs` | 需授权，合并增量，保留无关主规格内容 |
| 归档已验收变更 | `$openspec-archive-change` | 需授权，先核对任务、验证及 delta 同步状态；不能把归档当删除未完成工作的方式 |

`openspec update` CLI 刷新生成的工具集成；`$openspec-update-change` 修订业务变更文档，两者不可互换。core 没有 `openspec-verify` 技能，不宣称调用过它；按现有任务和验证计划核对完整性、正确性、一致性即可。

### 产物与状态

- `openspec status --change <name> --json` 提供 `planningHome`、`changeRoot`、`artifactPaths`、`requires` 依赖边和下一步；使用实际返回路径，不猜测存储位置或固定四个文件。
- 为 ready artifact 运行 `openspec instructions <artifact-id> --change <name> --json`，依指引、模板和当前配置写入；按技能读取其已存在依赖。只补缺失产物，不因为改一个任务而重写全部文件。
- `isPlanningComplete`、兼容字段 `isComplete` 及 artifact `done` 只表示规划完整。`list` 的 `in-progress` 也可能仅由未勾选任务推导，不能自动映射成 Roadmap 的 In Progress。实施进度来自任务及验收证据；CLI 不保存用户批准状态。继续已授权任务不需反复批准。
- `openspec instructions apply --change <name> --json` 是只读指引查询，返回真实 `contextFiles`、任务统计和 blocked／ready／all_done；查询本身不实施代码，ready 也不是授权。配置 `context` 和 `operationGuidance` 不是可执行门禁，不能绕过 blocked 或替代证据。
- `verification.md` 是项目附加记录，不假装属于内建 schema。记录实际命令／设备／样本／结果、未运行原因、阻塞和下一步；同 change 只有一份 `tasks.md`。任务编号稳定，细节和依赖可随已获准范围更新，发现实现偏差不能只改勾选。
- 正文简体中文，保留 schema 语法。行为规格写可观察输入／输出与失败条件，类型名、框架和存储算法放 design。新增能力用 ADDED；MODIFIED 必须对应已存在的准确 requirement 名并包含完整内容及场景。
- 如果用户要求把纯工具／文档任务也放入 OpenSpec，且确实没有行为 delta，按本机 schema 使用 `.openspec.yaml` 的 `skip_specs: true`；不为通过校验虚构产品能力。不自动套用 M0 的迁移细节到其他功能。

### 验证、同步和归档

```sh
OPENSPEC_TELEMETRY=0 openspec validate <change> --strict --no-interactive
```

修改共享配置时还要用 `instructions` 读取实际注入结果，确认适用 context／rules／operationGuidance 生效且没有警告；仅 `validate` 通过不足以证明配置按预期注入。

实施证据按根 AGENTS 分层记录。跨阶段 AT 只记录本阶段子断言，不把部分通过升级为整项通过。发现需求冲突先报告，局部实现修正保持文档一致；不要为了全绿静默改变验收口径。

主规格仅描述已实施且验证的行为。用户明确授权 sync／archive 后执行对应技能，先比较真实 delta 和主规格；直接 `openspec archive` 也可能同步主规格，`--yes` 只是跳过交互，不是授权。已有 sync 授权不代表 archive／commit／push 授权，已有明确授权也无需重复索取。操作后验证主规格与归档路径，更新受影响索引链接。

## 3. 恢复工作而不重复启动

恢复已有 change 时：核对工作区差异 → 定位真实 change → 读取其当前任务和 verification → 用 CodeGraph 查询下一个任务的代码范围 → 接着执行。只重查已变化或缺证据的内容，不重跑 bootstrap、不重新安装工具、不创建第二份 TODO。

输入不全时继续不依赖答案的工作。测试失败先区分产品缺陷、测试设施缺陷、环境不可用；授权范围内可修复则修复并重验，只有确实需要额外决策时才暂停相关部分。没有活跃进程句柄不声称任务仍在运行。

## 4. CodeGraph 查询与故障退路

仓库有 `.codegraph/` 时，代码理解先用 `codegraph_explore`。以下两条示例任选合适的一条，不需双重执行：

```text
MCP codegraph_explore:
  projectPath: 当前仓库的绝对路径
  query: "reloadCurrentPlayback restorePlaybackPositionIfNeeded persistPlaybackProgress"
  maxFiles: 3
```

```sh
codegraph explore 'RecentPlaybackStore RecentPlaybackRecord' --max-files 2
```

这是目标符号建议，不是每任务固定查询。未知入口可先问一次自然语言；拿到源码后按需补精确符号。已返回的未变源码不再重复读取，`gap`／trimmed 区域不能当作已读。`already sent` 指向本会话未变的已读内容，跨会话则重新获取。

| 情形 | 动作 |
| --- | --- |
| 返回新鲜源码且覆盖目标 | 直接分析或修改；不再做同一遍 grep 复核 |
| 同名符号／调用边候选不唯一 | 按文件和模块约束查询，结合平台／接收者语义；不把所有候选都当真实运行路径 |
| 截断、gap 或缺少目标 | 用具体符号／文件补一次查询；仍缺失则定向读缺失范围，避免查询循环 |
| 个别文件 stale / changed-on-disk | 返回当前整文件源码可用；若源码省略则只读该文件。关系更新需要时执行已有索引的 `codegraph sync` 后重查 |
| auto-sync disabled／跨项目图谱过期 | `codegraph status` 检查；使用当前磁盘补证据，可增量 sync；不假定 watcher 永远存在 |
| MCP 不可用 | 在仓库运行 CLI explore；CLI 也不可用则 `rg` + 定向读取，说明本次失去图谱覆盖，不阻断可完成工作 |
| 根无 `.codegraph/` | 跳过 CodeGraph，直接使用原生查找；不擅自 init/index/install |

`codegraph affected <changed-files> --json` 只生成候选测试文件，不执行测试。结果为空仍需检查实际测试 target 和行为风险。SwiftUI／系统通知／AVPlayer 回调、条件编译和 C 桥接不能凭空图证明安全；图谱与测试各司其职。

增量 `codegraph sync` 只刷新本地派生索引，属于普通可逆维护；它与需要单独授权的 OpenSpec 主规格 sync 无关。常规任务不手动全量 index、不删锁、不杀 daemon，不直接编辑数据库。现有 `.codegraph/.gitignore` 已排除数据库、日志、pid/socket；提交时不要强行加入缓存。

## 5. 维护 Harness

- 自定义长期规则放 AGENTS，按需参考放本文件，OpenSpec 上下文放 `openspec/config.yaml`；同一规则不重复维护，不手改 OpenSpec 生成技能正文以塞项目规则，后续 CLI 更新会覆盖或产生漂移。
- 维护工具版本时比较 `openspec --version` 和生成技能的 `generatedBy`；相同无需 update。确需刷新时先看差异并保护自定义文件，使用本机 `openspec update --help`，不默认 `--force`，不改用户级 workflow profile。
- `context` 只存简明、稳定的项目事实和索引；artifact 规则放 `rules`，apply／archive 偏好放 `operations.<operation>.guidance`。不写“本轮只规划”“永远 M0”等一次性会话约束。
- 沿用 core 和标准 schema；只有出现真实且重复的 schema 缺口才定制。无需为了 verification 文件增加新框架、额外 agent 角色或固定全套门禁。
- 当前入口和所有权通过 CodeGraph 查询；兼容性约束变化时维护对应规格及本文件相关条目，不另存容易过期的架构快照。研究笔记和工具版本快照放第 6 节，不污染根指令的每次上下文。
- Harness 自身修改执行链接／技能格式／配置注入／CLI smoke／差异范围检查，并用代表性请求走读路由。结构通过不能冒充模型行为评测，未实测不声称节省多少 token 或工时。

## 6. 研究依据与接入验证（2026-09-26 快照）

这些是本次研究时读取的上游资料；参数、产物路径、授权边界以本机技能／CLI 和本项目规则为准，不机械执行网页示例。

| 已读取来源 | 采用的结论 |
| --- | --- |
| [OpenSpec：已有项目接入](https://github.com/Fission-AI/OpenSpec/blob/main/docs/existing-projects.md) | 只为实际变更逐步建立 delta，沿用 PRD，不全文转换存量代码 |
| [OpenSpec：概念](https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md) | 行为合同与实现设计分开，按风险使用最轻且可验证的规格 |
| [OpenSpec：工作流](https://github.com/Fission-AI/OpenSpec/blob/main/docs/workflows.md) | 一个意图一个变更、探索可选、同目标原地修订、归档前核验 |
| [OpenSpec：项目定制](https://github.com/Fission-AI/OpenSpec/blob/main/docs/customization.md) | context／artifact rules／operation guidance 分工；指导不是强制门禁 |
| [OpenSpec：Codex 集成](https://github.com/Fission-AI/OpenSpec/blob/main/docs/supported-tools.md)及 [CLI](https://github.com/Fission-AI/OpenSpec/blob/main/docs/cli.md) | Codex 使用 `.agents/skills`，core 六动作；生成内容归工具管理 |
| [OpenSpec：编辑变更](https://github.com/Fission-AI/OpenSpec/blob/main/docs/editing-changes.md) | Markdown 产物可迭代，保持一致；文中“没有 update 命令”的旧描述以本机已有 update-change 技能为准 |
| [CodeGraph 官方 README](https://github.com/colbymchenry/codegraph#readme)及 MCP 实际说明 | 首选聚焦源码／调用路径查询，增量同步、陈旧提示与定向回退；README 的刷新宣传不替代实际 freshness 证据 |

OpenAI 的 AGENTS／skills 官方页面本次请求返回 HTTP 403，未取得正文，不把其内容作为本次已核实依据。指令分层和按需披露遵循当前会话生效规则与已读取的本地 skill-creator 指引。

初始现场：`main @ a86d74a4b35d7aea330be48480727d8652210914`；已有 AGENTS 修改及未跟踪的 `.agents/`、`.codegraph/`、PRD、Roadmap、OpenSpec，均属于本轮开始前的工作。CLI OpenSpec 1.13.2，六个技能 generatedBy 同版本；CodeGraph 1.6.0，status 报 66 文件／37 Swift，索引 up to date。MCP 实测返回 ContentView 的当前 NavigationStack／TabView 源码及 PlaybackContext 的依赖范围，且明确部分输出截断；不据此声称全应用审查完成。

本轮维护只调整 Harness 指令、项目知识与工具上下文；M0 仍未实施。历史 M0 Bootstrap 报告保持原样，不改写当时的工具版本和检查记录。

### 实际检查

- 当时的 `quick_validate.py .codex/skills/zenplayer-project`：通过技能 frontmatter／格式检查。该技能现已移除，独有兼容性提示合并至第 7 节；此项仅保留历史证据，不再执行。
- `openspec list --json`／`context --json`：根均为本仓库；唯一现有 change 为 preserve-playback-progress，0/13 完成。list 报 in-progress，status 报规划齐全，而 Roadmap 为 Planned／待评审，三者含义已在规则中明确区分。
- `openspec instructions <artifact> --change preserve-playback-progress --json`：分别查询 proposal／specs／design／tasks／apply／archive，全部退出 0，无 stderr 警告；四类 artifact 的 context／rules 和两类 operation 的 context／guidance 均按新配置注入。apply 指引显示 ready、13 remaining，未执行实施或归档动作。
- `openspec validate preserve-playback-progress --strict --no-interactive`：通过。以上 OpenSpec 命令均设置 `OPENSPEC_TELEMETRY=0`。
- CodeGraph MCP 和 `codegraph explore 'RecentPlaybackStore RecentPlaybackRecord' --max-files 2`：均成功返回当前源码／依赖提示；输出有截断，已按事实记为部分代码上下文。
- `codegraph affected ZenPlayer/Services/RecentPlaybackStore.swift --json`：遍历 18 个依赖，affectedTests 为空；不据此豁免 M0 测试。`status --json` 报 pendingChanges 均为 0、无 worktreeMismatch、无需 reindex。
- 内联 Python 文件审计：4 个既有 Harness 文件被修改，新增本参考文件，其他 127 个基线文件逐字节保持不变；10 个 Harness 相对文件链接有效。PRD、Roadmap、M0 文档、生成技能、源码、Xcode 工程与锁文件均保持原样，main／HEAD／暂存区未变。
- `git diff --check` 通过；新增文件另查行尾与链接。`git check-ignore` 确认 CodeGraph 数据库、WAL/SHM、日志及 daemon 文件仍被排除。

### 代表性请求走读

以下是规则与现场证据的逐项走读，不是独立模型的自动行为评测。

| 请求／现场 | 按新规则得出的下一步 | 核对结果 |
| --- | --- | --- |
| “修正文档链接／维护 Harness” | 直接编辑限定文件、检查链接和配置，无需 M0 提案或 App build | 本轮按此路径完成，业务与 M0 文件字节未变 |
| “为什么最近记录只能留 10 条” | CodeGraph 定位 RecentPlaybackStore，解释现状，不自动修复 | CLI 实测提供 maxRecordCount 和 prefix 源码 |
| “继续实施已批准 M0” | 复用原 change 和已有授权，读取 contextFiles，从未完成任务继续 | 只读 apply 查询返回 13 个剩余任务，配置不再强制永远只规划 |
| “新建搜索方案” | 关联 PRD F3／Roadmap M4，建立聚焦提案；不套 M0 迁移任务 | specs／design 的数据规则已限定到相关变更，不再把 M0 非目标全局化 |
| “把 M0 的存储方案改一下” | update-change 原地保持产物一致；不运行 openspec update | 两个同名近义动作有独立路由及职责 |
| status 全 done，list in-progress，但任务 0/13 | 视作规划齐全，仍检查授权和实施证据 | 不自动实施、同步、归档或改 Roadmap 为 Done |
| MCP 失效／响应截断／无索引 | CLI → 缺失范围定向读取；无索引直接原生查找 | CLI 路径已实测；故障与无索引分支为规则走读，未人为破坏本仓索引 |
| “验收后同步规格”，没有归档／推送授权 | 只执行获准 sync，核对内容；不顺带 archive／push | 根规则与操作指导一致，不从工具 nextSteps 推导权限 |

未运行 App 构建、XCTest 或真机验收，因为本轮没有业务实现；未运行独立 Agent 效率基准，因此不承诺 token／耗时收益。后续应以真实任务的重复读取、返工和证据完整性观察效果，再做针对性调整。

## 7. 播放、下载与迁移兼容性速查

本节保留容易遗漏的兼容性提示，不维护阶段状态或完整架构快照。进度与迁移行为见 [PRD](../PRD/prd.md) 和 [进度变更规格](../../openspec/changes/preserve-playback-progress/specs/playback-progress/spec.md)；实施与验收状态查对应 change。当前代码仍需按任务范围核实。

- 进度身份由 `RecentPlaybackRecord.recordID` 生成，为 `episode.id + "|" + 原始 serverUrl`；不能规范化该身份中的 URL，或按标题／集数合并。下载键由 `DownloadManager.downloadKey` 生成，为 `episodeId_mp3`／`episodeId_mp4`，不能与进度身份互换。
- 旧数据来自 UserDefaults 的 `recentPlayback.records`；迁移保留旧数据及身份关系。隔离测试不能证明可恢复早已淘汰或无法读取的历史记录。
- 同一媒体类型的解析保持本地文件优先：音频回退至远端 `mp3Url`，兼容 `mp4Url`／`vodUrl` 中实际为 mp3 的地址；视频回退至远端 mp4／vod。可从 `resolveAudioPlaybackURL`、`resolveVideoPlaybackURL` 和 `resolveFallbackAudioPlaybackURL` 查询当前实现；不要把媒体地址拼接规则用于改写进度身份。
- 下载删除与失效文件清理只处理下载文件及清单，不应删除收听进度。涉及生命周期时分别核对 iOS 后台下载和 macOS 保存面板／安全作用域访问，避免把一端的验证当成另一端的证据。
