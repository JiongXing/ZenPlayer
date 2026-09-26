# ZenPlayer Agent Harness

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## 开始任务：只加载需要的上下文

1. 检查 `git status --short`、当前分支和 HEAD，保留已有暂存、未暂存和未跟踪文件；按本次请求确定范围，不把工作区全部改动视作本次工作。
2. 根据下表选择路径。只有产品迭代才读 [ROADMAP.md](ROADMAP.md) 的当前阶段、[PRD](Documents/PRD/prd.md) 的相关章节和相关 change；不要每轮全读 PRD、所有历史规格或全部技能。
3. 涉及应用代码时使用 [zenplayer-project](.codex/skills/zenplayer-project/SKILL.md)。需要 OpenSpec 操作／工具故障处理时，按需读 [工作流](Documents/Development/agent-workflow.md) 对应章节及实际生成的技能。

| 请求 | 执行路径 |
| --- | --- |
| 解释、定位、审查 | 用 CodeGraph 查目标符号／文件及调用关系；给证据，不自动改代码或创建提案 |
| 文档／工具维护；无行为变化的小重构；恢复明确既有行为的小修 | 按用户授权直接修改并做适当验证；不强制创建 change。若触及已有 change，仍维护该 change 的相关产物 |
| 新功能、行为／接口变更、数据迁移、跨模块生命周期或所有权调整 | 先查相关规格和已有 change；复用同目标变更，否则用 `$openspec-propose` 建立聚焦提案；获批后实施 |
| 修改已有方案 | `$openspec-update-change`；保持 proposal、specs、design、tasks 一致，不创建同义副本 |
| 实施／继续已批准变更 | `$openspec-apply-change`；读取 CLI 返回的实际 contextFiles，从未完成任务继续，沿用已有授权 |

“调查”“提案”“修改计划”不等于实施授权；普通可逆工程选择自行处理。已明确批准的范围不重复确认；只有需求冲突、行为扩张或不可逆操作所需信息不足时，暂停受影响部分并说明依据。

## 用 CodeGraph 获取代码事实

- 查询带上具体符号／文件或调用链两端；MCP 明确 `projectPath`，先限制少量相关文件，截断时按缺失符号补查。
- 图谱返回的当前源码已算读取，不再用 `rg` 重读同一内容。文档、配置、字符串、工程设置和图谱未覆盖的细节可直接读／用 `rg`。
- 遇 stale／auto-sync disabled／changed-on-disk 提示，只对受影响范围读磁盘或增量 `codegraph sync`；MCP 不可用先试 CLI，再退回定向查找。没有索引不自动 init，不反复全量 index，不操作运行中的锁／守护进程。
- 调用边是影响范围线索，SwiftUI 生命周期、通知、异步回调、协议派发和平台条件仍需实际验证；“未找到边／测试”不证明无调用／无需测试。不要把 CodeGraph sync 和 OpenSpec 规格同步混为一谈。

## 文档与授权边界

- PRD 管产品基线；Roadmap 管阶段顺序；`openspec/specs/` 管已实施且验证后同步的行为；当前获准 change 管本次增量、设计及唯一 `tasks.md`。代码是现状证据，发现差异须明确记录，不静默改需求迁就实现。
- 阶段状态和当前授权从 Roadmap、change 与本次会话获取，不写死在全局上下文。只有阶段状态变化才更新 Roadmap；任务、检查、阻塞和下一步写该 change 的 `verification.md`，无 change 的小任务在交付回复说明即可。
- 规划文件完整不等于实现完成。任务满足自己的完成条件才勾选；阶段 `Planned → In Progress → In Verification → Done` 需要对应范围证据，跨阶段 AT 按子断言跟踪。
- 未获授权不 sync 主规格、archive、commit、push、创建 PR 或进入下一里程碑。安装技能、CLI 的 ready/all_done 提示都不增加授权。Git 提交授权与推送授权分别判断。
- 不覆盖／丢弃用户工作，不 reset、clean、stash 或删除文件来获得干净状态；同名文件先读后合并。不改真实 App 数据容器来测试迁移，不顺手改签名、版本、依赖或用户级配置。

## 实现约定

- `ZenPlayer/` 按 `Models / ViewModels / Views / Services / Utilities / Localization` 分层；SwiftUI 视图保持轻量，异步业务放 ViewModel／Service，UI 状态遵循 `@MainActor`／`@Observable`。
- Swift 5、4 空格、类型 UpperCamelCase、成员 lowerCamelCase，一文件一个主要类型；沿用附近代码，不引入无现有配置的格式化全仓动作。文档简体中文，新增 App 文案通过现有 L10n／xcstrings 使用繁体中文。
- App target 当前 iOS 17+／macOS 14+；版本、标识、签名以 `ZenPlayer.xcodeproj/project.pbxproj` 和 `ZenPlayer/Info.plist` 为准。保持值路由、媒体本地优先／远端回退、处理失败原声回退、下载与进度身份兼容。
- 优先复用或局部修复；新增状态、重试、缓存或抽象必须解决可指出的需求／可达故障。播放／迁移改动追清创建者、所有者、结束清理和媒体／请求身份；`weak` 引用不能代替过期回调检查。

## 验证与交付

| 改动 | 必要验证 |
| --- | --- |
| 仅文档／Harness | 链接、配置／技能解析、命令 smoke、Git 范围；不为文档变动构建 App |
| OpenSpec artifact | `OPENSPEC_TELEMETRY=0 openspec validate <change> --strict --no-interactive`；核对行为／任务／证据一致，不能仅看 status |
| 应用代码／工程／依赖 | 对应行为测试和受影响平台构建；提交 PR 前两端构建及相关手动流程验证 |
| 播放／迁移／生命周期 | 隔离数据自动化及相关设备路径；iPhone 后台／锁屏／PiP、macOS 窗口／退出不能仅凭静态检查或模拟器构建过关 |

构建命令：

```sh
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' build
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=iOS Simulator,name=iPhone 16' build
```

目的地不可用时用 `xcodebuild -showdestinations -project ZenPlayer.xcodeproj -scheme ZenPlayer` 选择现有兼容模拟器并记录实际目的地，不为验证修改部署版本。仅需查工程结构时用 `xcodebuild -list -project ZenPlayer.xcodeproj`；SPM 解析／查询不是编译证据。

当前基线未提交 XCTest target；测试增补按任务风险决定，优先 `ZenPlayerTests/`、按行为命名（如 `testPlayerFallsBackToRemoteURL()`），不为每次小修搭测试框架。已有测试不适用或未运行须说明原因。内容、基线和相关依赖未变时复用本轮证据，修复后只重跑受影响检查及必需门槛。

收尾审查 `git diff --check`、暂存／未暂存差异及新增文件内容（`git diff` 不含未跟踪内容）。报告改了什么、实际检查结果、未运行项、剩余风险和下一步；明确区分规格校验、编译、自动化、真机、提交和推送。满足当前授权范围后结束，不机械进入下一阶段。
