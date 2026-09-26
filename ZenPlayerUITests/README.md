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

跳集输入默认 `0012`。`--jump-input '第１２集'` 可重现 Unicode UI 输入路径，也接受 `12`；参数只写入临时 scheme 的 TestAction 环境并记录到 `context.json`。本机 Xcode 27 的 Unicode `typeText` 在事件合成时超时，当前不能将此路径算通过；纯解析单测通过不替代该 UI 缺口。默认运行通过仅证明实际使用的输入形式，不能推及所有变体。

`MacStageFixture.swift` 只复制进临时 App，并在临时 App 初始化播放器前加入播种调用；该文件不编入生产 target。只有 `--stage-seed` 启动时才创建自己的 180 秒静音 WAV、单条 30 秒进度和完成下载索引，且先断言 bundle 与 sandbox home。样本远端为不可解析的 `.invalid` 地址，必须通过真实 DownloadManager 的本地完成索引播放。它验证本容器内文件，不证明下载传输或外部文件的 security-scoped bookmark 授权。冷启动检查移除播种参数，读取上次实际保存的进度。删除场景的 `--stage-verify-deleted` 只读断言实际样本文件已删除、进度文件可解码且仍至少 30 秒；失败会使验证 App 启动失败，从而让测试失败。

测试启动参数 `--stage-primary-window` 让临时 fixture 在首个窗口成为主窗口时将其放到主屏可见区域，随即移除通知观察者。本机外接屏负坐标下曾出现点击未选中 Tab、搜索框未获焦点和拖窗失败；此设置只影响独立验证 App，不修改系统显示设置或生产 App 窗口。此配置不代表任意外接屏组合均已验收。

`MacStageUITests.swift` 使用实际窗口、快捷键和控件，覆盖八个用例（下列四个，加后文两项连播和两项分类／定位）：

- 两窗口暂停同步、关闭其中一个窗口保持会话、隐藏／失焦后媒体进度增加、Command-Q 退出、重开不自动播放并从已保存位置恢复。
- 最后一个窗口关闭后进程仍在，Command-N 重开继续同一会话并实际推进位置。
- 迷你条／完整页／历史／下载同集往返保持暂停，完整页无重复迷你条；停止并删除下载后冷启动，实际文件已删但进度保留；再次从历史打开，远端失败后重启也不清掉原位置。
- 暂停本地会话后检查分类编号升降序、清词保留降序、零结果和日期排序选中状态；系列过滤后用 Escape 取消、Return 提交非法／缺失集数，成功跳到被筛选隐藏的第 12 集并清词、收起面板，会话和位置保持暂停。

显式附件只记录本 App 各窗口的可访问性树，避免输出系统菜单中的无关最近项目。本机外接屏上窗口截图失败，App 截图只返回另一屏桌面，所以脚本不将截图作为窗口验收证据。它会临时将验证 App 带到前台，结束时终止验证 App；保留独立容器和 `/tmp` 构建／测试证据。`context.json` 同时记录生产工程 SHA-256，便于核对链接设置等工程修改。

本项仍不证明真实媒体听感、PiP／全屏、耳机／中断、异常强杀数据安全或所有 macOS 版本／窗口尺寸。完整矩阵以 change 的 verification.md 为准。

Mac 搜索框逐键发送并核对累计值，以区分输入是否送达与搜索结果是否正确。本机曾在批量 `typeText` 长 ASCII 文本时丢两个字符；原因尚未确定，逐键回归不覆盖连续快速输入可靠性或性能目标。


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
