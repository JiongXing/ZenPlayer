# 阶段 UI 验证

此套 XCTest UI 测试运行真实 SwiftUI 页面和 AVPlayer。生产工程不增加 UI target，也不引入测试模式；脚本把当前工作区源码复制到新的仓库外目录，只在副本添加 UI target 并改用独立 bundle `com.jxing.ZenPlayer.StageValidation`。不会安装到真机或写生产 App 数据。请在同一模拟器上串行运行，不要同时手动操作验证 App。

```sh
python3 Scripts/run-stage-ui-tests.py \
  --destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' \
  --output /tmp/ZenPlayer-stage-ui-new-run \
  --package-cache /tmp/ZenPlayer-M0-ios/SourcePackages
```

用 `xcrun simctl list devices available` 选择本机实际可用的 iOS 模拟器 UUID。输出目录必须尚不存在；`--package-cache` 可省略，传入时目录须存在。脚本会构建、启动选定模拟器、安装独立验证 App、播种样本，再执行 UI 测试。可追加 `--appearance dark --content-size accessibility-extra-extra-extra-large` 验证深色和最大辅助字体。脚本在 `ui-settings.json` 记录原值、实测值与还原结果，测试成功或失败均尝试恢复原设置；仅修改选定模拟器，不修改 macOS 或真实设备的显示设置。测试并发关闭，并通过 `-collect-test-diagnostics never` 关闭本机 Xcode 27 曾卡住的额外 simctl diagnose 采集；XCTest 断言、日志及显式截图仍保留。输出包含源码 SHA-256／HEAD／目的地、工程和播种器快照、build/test 的日志及 xcresult；退出非 0 表示未通过，保留现场。

播种器会先核对模拟器容器的 bundle 身份，只更新此验证 App 内拥有的样本：`900001_mp3` 下载索引、180 秒静音 WAV、长标题和该集 30 秒进度，不清空其他记录。它不读取或复制生产数据。样本远端地址使用不可解析的 `.invalid` 域名，播放成功证明本地文件绑定有效；这不等于真实下载传输或断网验收。测试结束后保留验证 App 和容器用于调查；每次运行会重新播种同一条样本。

- 续听测试：冷启动无活动播放、首页本地续听、迷你条位于 Tab 上方且标题入口至少 44pt 高、切 Tab、暂停、完整页隐藏迷你条、历史／下载同集重进仍暂停、停止和重启保留续听入口。
- 列表末行测试：暂停本地会话后进入真实系列，定位最后一集，确认可滚到迷你条上方且会话保持暂停；截图记录末行及下载按钮。
- 搜索测试：真实分类数据的零结果／清词、阿弥陀经 `01-001` 系列过滤、不存在集数提示、`0012` 定位第 12 集、清筛选／收键盘、时长字段可读、不自动播放。

分类和系列测试依赖现有目录 API，以及 `01-001` 当前 21 集数据。服务不可达或内容变更时测试可能失败，须区分环境／数据变化与产品缺陷，不能将跳过当通过。播放测试使用本地样本，但首页仍会按正常流程请求目录。

截图保存在 xcresult，可导出复核：

```sh
xcrun xcresulttool export attachments \
  --path /tmp/ZenPlayer-stage-ui-new-run/tests.xcresult \
  --output-path /tmp/ZenPlayer-stage-ui-images --filter '*.png'
```

这套测试不替代 `ZenPlayerTests` 的两平台自动化，也不覆盖真实 iPhone 后台／锁屏／PiP、VoiceOver、所有字体／窗口尺寸组合、真实媒体听感或端到端性能。每次实际结果和剩余验收记录在相应 change 的唯一 `verification.md`；不能凭 UI target 通过标记整个阶段 Done。

## macOS 窗口与正常退出

```sh
python3 Scripts/run-mac-stage-ui-tests.py \
  --output /tmp/ZenPlayer-mac-stage-new-run \
  --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages
```

脚本仍复制工程，改为独立 `com.jxing.ZenPlayer.MacStageValidation` bundle，包括清除原工程 macOS 条件 bundle 覆盖；保持 App sandbox、验证签名和 entitlement 后才启动。生产工程／源码不修改，不需要从终端读取受 macOS 隐私保护的容器元数据。

可追加 `--only-testing testCatalogSortingAndKeyboardJumpPreservePausedSession` 定向运行现有方法；脚本在创建输出前校验方法名，并在 `context.json` 记录选择。省略时运行全部 Mac 用例。每次使用新的 output 目录。

跳集输入默认 `0012`。`--jump-input '第１２集'` 可重跑 Unicode UI 输入路径，也接受 `12`；参数只写入临时 scheme 的 TestAction 环境并记录到 `context.json`。本机 Xcode 27 曾在 Unicode `typeText` 合成时超时；最新实际跳集面板复测已通过，但历史间歇失败根因仍未确定，不能概括为 XCTest 不支持 Unicode。具体结果见 M4 verification.md；默认运行通过仅证明实际使用的输入形式，不能推及所有变体。

`MacStageFixture.swift` 只复制进临时 App，并在临时 App 初始化播放器前加入播种调用；该文件不编入生产 target。只有 `--stage-seed` 启动时才创建自己的 180 秒静音 WAV、单条 30 秒进度和完成下载索引，且先断言 bundle 与 sandbox home。样本远端为不可解析的 `.invalid` 地址，必须通过真实 DownloadManager 的本地完成索引播放。它验证本容器内文件，不证明下载传输或外部文件的 security-scoped bookmark 授权。冷启动检查移除播种参数，读取上次实际保存的进度。删除场景的 `--stage-verify-deleted` 只读断言实际样本文件已删除、进度文件可解码且仍至少 30 秒；失败会使验证 App 启动失败，从而让测试失败。

测试启动参数 `--stage-primary-window` 让临时 fixture 在首个窗口成为主窗口时将其放到主屏可见区域，随即移除通知观察者。本机外接屏负坐标下曾出现点击未选中 Tab、搜索框未获焦点和拖窗失败；此设置只影响独立验证 App，不修改系统显示设置或生产 App 窗口。此配置不代表任意外接屏组合均已验收。

`MacStageUITests.swift` 使用实际窗口、快捷键和控件，覆盖十个用例（下列四个，加后文六项连播／分类／定位整合）：

- 两窗口暂停同步、关闭其中一个窗口保持会话、隐藏／失焦后媒体进度增加、Command-Q 退出、重开不自动播放并从已保存位置恢复。
- 最后一个窗口关闭后进程仍在，Command-N 重开继续同一会话并实际推进位置。
- 迷你条／完整页／历史／下载同集往返保持暂停，完整页无重复迷你条；停止并删除下载后冷启动，实际文件已删但进度保留；再次从历史打开，远端失败后重启也不清掉原位置。
- 暂停本地会话后检查分类编号升降序、清词保留降序、零结果和日期排序选中状态；系列过滤后用 Escape 取消、Return 提交非法／缺失集数，成功跳到被筛选隐藏的第 12 集并清词、收起面板，会话和位置保持暂停。

显式附件只记录本 App 各窗口的可访问性树，避免输出系统菜单中的无关最近项目。本机外接屏上窗口截图失败，App 截图只返回另一屏桌面，所以脚本不将截图作为窗口验收证据。它会临时将验证 App 带到前台，结束时终止验证 App；保留独立容器和 `/tmp` 构建／测试证据。`context.json` 同时记录生产工程 SHA-256，便于核对链接设置等工程修改。

本项仍不证明真实媒体听感、PiP／全屏、耳机／中断、异常强杀数据安全或所有 macOS 版本／窗口尺寸。完整矩阵以 change 的 verification.md 为准。

既有 Mac 搜索用例逐键发送并核对累计值，以区分输入是否送达与搜索结果是否正确。本机曾在批量 `typeText` 长 ASCII 文本时丢两个字符；原因尚未确定，逐键回归不覆盖连续快速输入可靠性或性能目标。新增批量输入用例见下文。


## Mac 系列连播与首页下一集

新增 `MacQueueFixture.swift` 只复制进临时 App。`--stage-seed-queue` 写入固定 1／2／5 三集快照、10／120／15 秒本地静音 WAV、完成下载索引和单集进度（第 1 集 1 秒、第 2 集 7 秒）；远端均为 `.invalid`。仅写本验证 App 的三个专属单集键及一个固定快照版本，保留其他记录／下载。每次播种重新建立这些样本的起点；只有本验证 App 的 `playback.autoAdvance` 偏好被清除，以验证产品默认开启。`--stage-auto-off` 可设置已关闭的起点。

- `testNaturalQueueAdvanceControlsAndColdPreference`：首页一键启动本地第 1 集，真实 AVPlayer 自然结束进入第 2 集并恢复其进度；实际开关关闭不立即暂停、手动下一集到 5；连播开启时末集结束不循环；正常退出后只读验证完成状态／第二集进度／快照／关闭偏好，再从首页恢复第二集，手动上一集重听已完成的第一集，首尾按钮禁用。
- `testAutoAdvanceOffOffersNextWithItsOwnProgress`：连播关闭时首集自然结束不自动启动第二集；首页显示“繼續下一集”和第二集自身 7 秒进度，点击后直接播放并保留队列／关闭偏好；停止、退出后冷启动核实进度保留且未误播末集。

`--stage-verify-queue`／`--stage-verify-queue-off` 仅在重启时读取专属进度文件、快照与偏好并断言，失败会阻止验证 App 启动；不重新播种，不从测试直接发送结束通知。各用例仍可用 `--only-testing <方法名>` 独立重跑，实际结果写入 M2／M3／M4 的 verification.md。此样本不证明真实音视频听感、网络类型回退、物理断网、PiP 或锁屏换集。

## Mac 分类失败与历史定位

`MacCatalogURLProtocol.swift`／`MacCatalogFixture.swift` 仅复制进临时验证 App。脚本在副本的 `APIService` URLSession 配置中加入测试协议，继续运行真实请求、解码、错误处理和页面；协议只接管显式参数指定的精确分类 URL 或专属 `.invalid/series` URL，其他请求照常处理。未改生产 APIService、系统网络、代理或远端数据。临时配置注入记录在 `context.json`，匹配不到现有配置结构时脚本拒绝猜测位置。

- `testCategoryFailureKeepsLocalResumePlayable`：`--stage-seed --stage-category-failure` 播种原本的 30 秒本地媒体，并令分类请求返回带唯一文字的网络错误。实际首页同时显示错误与其上方续听卡，单击后不经完整页启动本地 WAV，媒体时间继续推进，错误仍独立保留。它验证注入网络失败下的实际 App UI，不等同物理断网或真实下载传输。
- `testHistorySeriesAndLatestLocationClearFilterWithoutPlayback`：`--stage-seed-catalog` 写入固定 21 集完整快照及专属原键 `900212|https://mac-catalog-validation.invalid/`（42 秒、最新收听）、`900218|https://mac-catalog-validation.invalid/`（较早完成）。历史返回系列后第 12 集滚入窗口；筛选展示第 18 集已听完、第 21 集未收听，再点“定位上次收聽”清筛选并回到第 12 集，始终不开播。退出后的 `--stage-verify-catalog` 只读比较两条进度文件与播种时的原始字节，涵盖位置、状态、修订和收听时间。

目录样本只写两个归它所有的进度键、固定快照 `8B1F35A0-DBA6-4465-9970-0B562ED97DAD` 和验证基线，不清空其他历史／下载，不读取生产容器。系列请求返回确定的 21 集响应；不是实际目录网络服务验收。窗口可访问性树和几何断言不替代 VoiceOver、缩短动画或高亮持续时间测量。

## Mac 搜索结果连播与目录边界

- `testFilteredEpisodeNaturallyAdvancesThroughFullSeries`：组合 `--stage-seed-queue --stage-queue-catalog`，协议把现有 1／2／5 本地媒体对应的完整目录返回给真实系列页。实际输入 `1` 后只显示首集，点击此结果进入播放；返回列表保留筛选，真实 10 秒 WAV 自然结束后迷你条进入被隐藏的第 2 集，首集显示已听完。暂停并清筛选仍保持暂停，完整页手动下一集到 5，证明从搜索入口带入的是完整队列。没有 seek 或伪造结束通知，手动 2→5 与自然 1→2 分开断言。
- `testPartialCatalogAndDuplicateOrZeroEpisodeLocation`：`--stage-seed-catalog --stage-catalog-edge-cases` 仍只拥有原目录样本的两个进度键；响应声明 24 集但只返回 21 条，第一条的真实 episode 为 0，第 18 条的 episode 改为 12（与第 12 条同集数、不同 id）。实际 UI 验证部分加载及零结果保留范围说明、清词恢复全部已加载条目、重复集数等待用户选择而不自动跳第一条、选择第二候选后按其 id 定位，以及存在的第 0 集可达。退出冷启继续逐字节核实进度未被浏览／定位修改。

这些参数仅用于临时验证 App，不注入生产可执行文件。目录和媒体来自同一份夹具元数据，默认已有用例的 1／2／5、时长、进度和完整性均不变；边界变体仅在显式参数存在时启用。已有 Unicode／连续输入异常仍以 verification.md 的实际记录为准，单次绿色测试不代表输入可靠性或端到端性能门槛已关闭。

## Mac 批量输入与原生对照

`testBatchSearchInputRetainsExactText` 加入默认阶段套件，使用隔离目录样本，在实际搜索框一次 `typeText` 输入整个查询，不逐键补发。依次验证 `1`、长 ASCII 零结果词、`12`、`MAC-CATALOG 21` 的逐字保留、结果数与不开播；查询 `1` 应命中 12 条，精确项优先不代表只保留精确项。每次输入前后保留窗口树，供间歇失败调查。

`--native-input-probe` 则单独选用 `MacNativeInputTests.swift`，在临时 App 的原生 `NSTextField` 验证 `12` 和 `第１２集`。它不经过搜索、解析或 SwiftUI Binding，结果不计入产品阶段通过数；与 `--only-testing` 互斥，组合时在创建输出前拒绝。`MacNativeInputProbe.swift` 仅复制进验证 App，显式参数才显示窗口，原生产 target 不变。测试结束终止验证 App；沿用独立 bundle、sandbox 和专属样本边界。

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-input-new --only-testing testBatchSearchInputRetainsExactText
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-native-new --native-input-probe
```

输出目录须不存在，可加 `--package-cache` 复用现有 SourcePackages；Mac GUI 测试应串行运行。本轮同一批量输入测试重复 5 次、原生对照及实际 Unicode 跳集各 1 次均通过，不等同真实输入法组合输入、长时间可靠性或端到端性能验收。

## Mac 首页候选边界

`MacResumeFixture.swift` 仅复制进临时 App。显式 `--stage-resume-case` 配合 `--stage-resume-run <UUID>` 将共享进度与队列仓库切换到独立验证容器内的 `StageValidation/resume-<UUID>/`；关闭此模式时沿用原共享路径和原迁移来源。临时源文件替换必须精确命中现有初始化表达式，否则脚本停止。首页、历史等仍使用同一真实共享仓库；不清空其他验证数据，不修改生产容器。每次播种要求 UUID 目录不存在，样本保留供调查。

- `testEmptyHistoryHidesResumeCard`：空历史首次启动和冷启动，分类错误已显示后观察两秒，续听卡／下一集按钮保持隐藏，不自动播放。
- `testCompletedImmediateNextIsNotSkipped`：三个独立目录场景均首次启动和冷启动。`next` 正对照为最近完成第 1 集、紧邻第 2 集未完成，首页显示“繼續下一集”和第 2 集自身 7 秒；`blocked` 把紧邻第 2 集也设为已完成，虽第 3 集未听也不得跳过推荐，无其他记录则隐藏卡片；`fallback` 增加较早的另一条未完成记录，首页显示其 42 秒和“總時長未知”，不显示下一集按钮。

测试不播放媒体；完成状态只是固定起点，真实自然完成另由现有队列测试验证。共享仓库从真实文件读入，候选计算和 UI 未替换。`--stage-verify-resume` 冷启动只读比较播种时的所有进度／快照字节与进度条数，不能重新播种掩盖变更。窗口树供结果核对；两秒无卡片断言是该观察窗口的证据，不等同异步任意时序、真实输入法或可访问性验收。

## Mac 超出最近十条的旧进度

`MacLongHistoryFixture.swift` 在 `--stage-resume-case long-history` 的独占 UUID 目录内播种 14 条长期记录：旧系列第 12 集 42 秒、第 18 集较早已完成，再加 12 条较新的无系列记录。最近页应仅显示较新的第 12～3 条，旧系列两项均不在其中。分类／系列／单集响应仅在此模式下由 URLProtocol 接管三条精确 URL；仍运行真实请求、解析、值路由、检索和定位。

`testEvictedHistoryStillLocatesAndResumesFromSeries` 与 `testEvictedHistoryResumesFromDownload` 各用全新目录，均先检查最近页的 10 条和底部第 3 条、旧系列记录不可见；再经首页分类进入旧系列，检查旧完成状态，筛选 21 隐藏 12 后定位上次收听，清词／滚回 12 且保持 42 秒、不播放。第一次冷启动以 `--stage-verify-resume` 比较全部 14 条原始进度字节，定位不能抬升最近次序。

随后分别从系列行、下载完成行打开旧第 12 集，使用真实 120 秒本地 WAV 恢复位置，返回首页读取活动会话时间并暂停。第二次冷启动增加 `--stage-verify-long-history-played`，仅允许目标同原键的状态／修订／位置随真实收听更新，其余 13 条字节不变，总记录仍 14 条；首页显示更新后的旧目标且不开播。此处下载清单只合并夹具自己的 `910012_mp3` 键，保留其他下载，样本媒体在本次 UUID 目录中；不代表真实下载传输或物理离线验收。WAV 生成复用现有 MacQueueFixture。

## Mac 实际播放三十集后恢复首集

`testThirtyActualPlaysPreserveFirstProgressAfterRestart` 对应 PRD AT-16 的操作顺序，加入默认 Mac 阶段套件，也可通过 `--only-testing` 单跑。`--stage-resume-case thirty-plays` 仍要求全新 UUID 目录；`MacThirtyPlayFixture.swift` 只准备 30 集目录快照、每集 120 秒的本地静音 WAV 和自有下载键 `911001_mp3`～`911030_mp3`，保留其他下载，断言初始进度仓库为空。目录响应复用 `MacLongHistoryFixture`，只在该显式模式返回专属 `.invalid` URL／标题／单集；原 long-history 变体保留。

用例从系列行开始，通过完整页“下一集”依次实际播放 1～30 集。每集核对标题、播放状态及媒体时间推进，首集暂停记录至少 12 秒，其余各集至少 2 秒；不 seek、不伪造结束事件、不写入样本进度。随后最近页摘要为 10，滚到底部第 21 集，首集不在最近列表；返回系列首集确认原位置，再正常退出重开。首页不自动播放，从系列行恢复首集，使用“媒体位置减去操作经过时间”的下限断言排除从零播放到阈值的假通过。暂停后再次重开，首集位置保留且没有自动播放。

第一次 `--stage-verify-resume --stage-thirty-first-position <UI 观察秒数>` 冷启动读取真实 30 条进度及最近 30～21 顺序，并把文件字节另存为 `thirty-before-resume.json` 证据副本；它不向进度仓库重新播种。第二次增加 `--stage-thirty-resumed`，核对首集实际新位置、最近次序及其他 29 条进度逐字节未变。样本和证据写入仅在验证容器中；测试串行运行并保留目录。

首页出现续听卡后，分类卡可能部分落在窗口外；用例会实际滚动到完整可见再点击，并保存前后窗口树。本测试证明所述 macOS 本地媒体和正常退出路径，不替代实际下载传输、真实媒体听感、iPhone／锁屏／PiP、异常强杀或升级迁移验收。各次通过、失败及未运行项以 change 的 verification.md 为准。

本机曾出现进程冷启动后无窗口；单独对照通过 Command-N 新建窗口后可显示原进度。用例等待窗口 5 秒后，如确认窗口数为 0，保留 `mac-thirty-cold-launch-no-window` 文本附件，再实际发送 Command-N，等待窗口出现后继续核验。这个分支不修改生产生命周期、不重新播种，也不证明冷启动必定自动开窗；具体触发情况与尚未确定的根因保留在验证记录中。
