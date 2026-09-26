# M1 验证记录

状态：In Verification。本轮授权：review 并本地提交当前 M1 阶段改动；不推进后续阶段，无 push／sync／archive／发布授权。基线 main @ 49b4eed，初始工作区干净。

当前真实设备／UI 用例全部未运行。M0 既有 27 项隔离测试为回归基线，真机 Developer Mode 阻塞需在实际设备执行前重新核实。

| 追踪 | 自动化／集成门槛 |
| --- | --- |
| S1／AT-01／AT-02 | 同键不准备、不唤醒暂停；App 注入、三个入口复用；跨页和多窗口实际操作 |
| S2／AT-05 | 请求修订 A/B/C、迟到回调、失败目标保持；旧进度保存 |
| S3／AT-03／AT-04 | 完整／迷你／锁屏控制同一对象，停止释放；冷启动不出声，首页续听 M3 补 |
| S4／AT-11／AT-12 | 即时切源暂停意图、失败保护；PiP／全屏／macOS 失焦退出实际操作 |
| S5／AT-06 | 仅中断前播放且期间未暂停且系统允许时恢复；耳机拔出保持暂停 |
| S6 | ended 不循环，主动重听后才撤销完成 |
| S7／Q-02 | 可控时钟 300ms／30s 边界、暂停时间排除、有效进展重置；真实加载失败／重试 |
| S8／Q-03 | 长标题完整可访问名、44pt 控件、安全区、大字体与 Reduce Motion |

本文件持续记录实际通过／失败／未运行及命令／xcresult，不提前计入后续里程碑。

1.1 通过：`/tmp/ZenPlayer-M1-state.xcresult`（日志同前缀 .log），macOS 共 31 测试、0 失败。新增 4 个会话测试覆盖同键暂停幂等、A/B/C 过期请求、中断资格、300ms／30s 边界及停止／结束。其余 UI 和设备项未验。

## 2026-09-26 当前阶段提交 review

范围：main @ 49b4eed 之上的现有 M1 改动。开始时 8 个已跟踪文件修改和 M1 新文件／change 未跟踪，无暂存内容；均属于当前 M1。没有改动 M0 存储／迁移算法、PRD、主规格、签名／版本／依赖，也没有继续 M2～M4。

### Review 发现与修复

| 级别 | 确认问题 | 修复及证据边界 |
| --- | --- | --- |
| P1 | 中断产生的 AVPlayer paused 回调会调用用户 pause，清掉恢复资格 | 分开 observedPause 与用户 pause；开始通知同步处理且按媒体 token 隔离；重复开始幂等；新增中断暂停／禁止恢复测试。实际 iOS 通知与 KVO 顺序仍待真机。 |
| P1 | 原生点击播放先进入 waiting 时意图仍为暂停，导致迷你条错误且不计超时 | observedWaiting 同步意图并计时；中断期间不会唤醒，新增回归测试。 |
| P1 | 音视频切源失败重试丢失原暂停意图；KVO 延迟时切源可能读到旧意图 | 失败保留重试意图；已恢复媒体切源读取即时 rate／timeControlStatus；新增暂停重试状态测试，实际 AVPlayer 切源仍未验。 |
| P2 | 迷你条 NavigationLink 在 NavigationStack 外；导航延迟可能重新选择旧内容 | 通过窗口 NavigationPath 打开独立当前控制页路由，不执行选择；页面可见性按 ID 集合维护。两端编译通过，UI 导航未运行。 |
| P2 | 停止后显示无限加载，保留切源入口可能重新启动 | 清空媒体类型及 URL、显示停止状态、切源要求活动会话；状态测试确认停止后迟到事件不能恢复目标。 |
| P2 | 缓冲 loading 沿用首次准备时间，播放中途失败通知缺少处理 | 每段缓冲重新计 300ms；当前位置缓冲区增长更新有效进展；接入 failedToPlayToEnd 通知；超时边界测试通过。 |

其他审查：App 的 @State 是媒体所有者；系列值路由、历史和下载直接路由均继承同一个 Environment 模型，完整页 onDisappear 只改变窗口可见性。旧 player／item／progressGate token 阻止准备、seek、KVO、通知、远程命令覆盖新目标。releasePlayback 仍使用旧 activePlaybackContext 保存进度。解析本地文件／远端回退和降噪构建原声回退沿用原路径。以上为源码走读，不能替代跨页或设备操作验证。

### 通过

提交版本的两端 `xcodebuild test` 均包含 App target 编译及独立 XCTest target，**各 37 项、0 失败**：M0 回归 27 项，M1 状态测试 10 项。测试 target 无 App host，使用隔离数据；新测试没有覆盖实际 PlayerViewModel／SwiftUI 的完整集成链路。

```sh
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' -derivedDataPath /tmp/ZenPlayer-M0-mac -resultBundlePath /tmp/ZenPlayer-M1-commit-mac.xcresult test
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' -derivedDataPath /tmp/ZenPlayer-M0-ios -resultBundlePath /tmp/ZenPlayer-M1-commit-ios.xcresult test
```

日志分别为 `/tmp/ZenPlayer-M1-commit-mac.log` 与 `/tmp/ZenPlayer-M1-commit-ios.log`。iOS 目的地为已有 iPhone 17 / iOS 27 模拟器；未修改部署目标。构建有 AppIntents 元数据提取跳过警告（无 AppIntents 依赖），没有编译或测试失败。`/tmp` 产物可能被系统清理，不把路径当永久归档。

- `OPENSPEC_TELEMETRY=0 openspec validate unify-playback-session --strict --no-interactive`：通过。
- 9 个新增 session 本地化键：catalog JSON 解析、L10nKey 对应繁体值均通过。
- Roadmap 和 M1 Markdown 链接检查、`git diff --check`：通过。
- Review 已涵盖已跟踪差异、新增源文件／测试和全部 M1 artifacts；工程差异仅给现有测试 target 增加状态模型源码。

### 失败／未运行

本轮已运行检查没有失败。真实设备／UI 操作用例**未运行**，并非通过：

- S1～S4：实际三入口重复进入、A/B/C 延迟返回、跨页／Tab、即时暂停切源失败重试、冷启动／停止后锁屏清理。
- S5、AT-06／AT-12：iPhone 耳机拔出、来电中断、后台／锁屏／PiP／全屏。M0 曾记录 Developer Mode 未开启，本轮没有重新确认设备状态。
- S8：迷你条与导航／Tab 安全区、列表最后一行、长标题、大字体、VoiceOver、Reduce Motion；完整页已改可滚动，但未以截图或 UI 自动化证明布局。
- macOS 多窗口共享、窗口关闭／失焦／App 退出；真实离线下载、分享、降噪／音量增强回归。

剩余风险主要是平台 KVO／通知实际顺序、SwiftUI 导航与 PiP 生命周期，以及未做真实布局验证。1.2／2.2／3.2 保持未完成；M1 进入 In Verification，**不能标记 Done**，M0 的设备缺口也不关闭。

### 本地交付

提交标题：`实现 M1 统一播放会话并修复阶段审查问题`。该记录随当前阶段同一提交交付；提交 hash 以 Git 对象为准，避免在文件中写入自引用 hash：

```sh
git log -1 --format='%H%n%B' --grep='^实现 M1 统一播放会话并修复阶段审查问题$'
```

只创建本地提交，不 push／PR／发布／主规格同步／归档。下一步是补齐本节未运行的 M1 平台验收，当前请求不自动进入 M2。

## 2026-09-26 跨阶段 UI review 补充

本节是 M4 整合验收期间对 M1 的回归修复，覆盖上文“当前 UI 全部未运行”的历史状态。基线 `main @ 4a01cf3`，只有本轮创建的 `Scripts/` 和 `ZenPlayerUITests/` 未跟踪，没有用户暂存／未暂存改动。持续目标授权阶段 review、修复及本地提交；不 push／PR／sync／archive／发布。

### 实际缺陷与修复

| 级别 | 复现与证据 | 修复 |
| --- | --- | --- |
| P1 | 首页续听后迷你条覆盖 Tab，“我的”点击实际打开完整播放页。iPhone 17／iOS 27 可访问性树：Tab y=791～874，迷你标题 y=793.3～831；`/tmp/ZenPlayer-stage-ui-routing.{xcresult,log}` 1 项失败。 | 将 inset 从 NavigationStack 外移到各浏览页内容内，根页使用 Tab 上方安全区，详情使用窗口安全区；完整页不应用 inset。移除随之失去用途的可见页 ID 状态。标题入口最小高 44pt。 |
| P2 | 在最近播放页点击迷你条、再返回，回到了“我的”而非最近播放。直接目的地未进入绑定 NavigationPath，追加控制页时原页面丢失；`/tmp/ZenPlayer-stage-ui-detail-routing.{xcresult,log}` 的返回后树证实此路径。 | “我的”的最近播放／下载完成／关于入口接入既有值路由，继续由同一 NavigationPath 管理。历史／下载中的单集播放入口和媒体所有者不变。 |

修复后 focused UI 回归通过：`/tmp/ZenPlayer-stage-ui-routing-fixed.xcresult` 1 项、0 失败；`/tmp/ZenPlayer-stage-ui-detail-fixed.xcresult` 1 项、0 失败，后者包含历史和下载页面往返、同集重进保持暂停。截图实际目视检查：`/tmp/ZenPlayer-stage-ui-routing-fixed-images/FB82D125-AB21-4452-BF11-C54C772D3CEE.png`，迷你条位于 Tab 上方，三个入口可见。不是仅编译或原生视图离屏渲染。

测试在独立 bundle `com.jxing.ZenPlayer.StageValidation` 的模拟器容器中执行。180 秒静音 WAV 由隔离下载索引绑定，起点 30 秒；远端 `.invalid` 地址不能替代本地媒体。没有读取、复制或改动生产容器。复现脚本、边界见 [UI 测试说明](../../../ZenPlayerUITests/README.md)。最终整套 UI 和两端结果集中记在 [M4 验证记录](../search-loaded-catalog/verification.md#2026-09-26-隔离-app-ui-验证与补充交付)。

1.2／2.2 已取得 iOS 模拟器首页／Tab／历史／下载／完整页的局部证据，但 macOS 多窗口、完整长列表末行、大字体／VoiceOver／Reduce Motion 仍未验证；3.2 的真机中断／后台／锁屏／PiP 等仍未验证。三项继续未勾选，M1 不标 Done。没有把静音样本的成功当作真实下载传输或实际媒体听感证明。

### 2026-09-26 长标题／最大辅助字体补充

M4 的 [动态字体验收记录](../search-loaded-catalog/verification.md#2026-09-26-动态字体与末行验收补充) 增加 iPhone 17／iOS 27 模拟器最大辅助字体＋深色外观下的长标题完整可访问名、迷你条／Tab 几何隔离、历史／下载往返暂停保持和系列末集可滚到迷你条上方的证据。`/tmp/ZenPlayer-ui-accessibility-fixed/tests.xcresult`，3 项、0 失败。2.2 的该字号子断言通过，但 VoiceOver、Reduce Motion、其他设备／窗口组合及 macOS 仍无证据，不据此关闭整个任务。

## 2026-09-26 macOS 实际窗口与退出补充

基线 `de77e31c0d240ae9398d15001ee666f9dc5f7d1f`，开始时工作区干净。复核最新大字体修复、共享会话注入、迷你条值路由以及 `willTerminateNotification → persistCurrentPlaybackProgress → flushSynchronously` 链路；未发现本轮需改生产源码的新缺陷。新增独立 Mac UI 脚本／样本／测试，并更新现有任务和证据；生产工程、签名、源代码及真实容器均未修改。

### 通过

实际环境：MacBook Pro／macOS 27.0 (26A428)、Xcode 27。`/tmp/ZenPlayer-mac-lifecycle-r7/build.xcresult` 与 `tests.xcresult` 均成功，`test.log`：**1 项 UI 测试、0 失败、0 跳过，35.926 秒**。不是纯状态模型测试或编译检查。

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-lifecycle-r7 --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages
```

重跑须改为不存在的输出目录。运行脚本、测试源码及隔离方式见 [UI 测试说明](../../../ZenPlayerUITests/README.md#macos-窗口与正常退出)。`context.json` 保存实际输入 SHA-256，77 个 Swift／Python／本地化文件与审查时工作区一致；bundle 为 `com.jxing.ZenPlayer.MacStageValidation`，签名和 sandbox entitlement 检查通过。样本在验证 App 自己的沙盒内生成，未通过终端绕过 macOS 容器隐私保护。临时 App 仅在播放器创建前添加播种入口，冷启动移除播种参数。

- 首页从 30 秒启动真实 AVPlayer，位置实际推进；Command-N 创建第二窗口，两个窗口均显示 35 秒及正在收听。
- 点击第二窗口迷你条暂停，两窗口均显示 36 秒及已暂停；关闭第二窗口后原窗口仍暂停、位置一致。
- 原窗口恢复播放，Command-H 隐藏后保持 4 秒，再激活时进度增加；附件显示 50 秒及正在收听。
- Command-Q 正常退出，断言进程不运行；无播种冷启动显示保留的 50 秒续听卡、没有活动迷你条；点击续听后从保存位置继续推进。测试清理终止验证 App。

六份窗口树附件在 xcresult 中，已导出至 `/tmp/ZenPlayer-mac-lifecycle-r7-attachments/` 核对。生产源码未变，复用且重新读取本轮两端 `/tmp/ZenPlayer-accessibility-final-{mac,ios}.xcresult`：各 86 项、0 失败，包含 App 编译；iOS 最大字体 UI `/tmp/ZenPlayer-ui-accessibility-fixed/tests.xcresult` 3 项通过。没有为新增 Mac 测试重复运行无变动的 iOS 业务测试。

### 失败尝试与工具限制

`/tmp/ZenPlayer-mac-lifecycle-r1`～`r6` 的测试均失败，保留各自 build/test 日志和 xcresult，不将后续通过覆盖历史结果：

| 运行 | 原因与处理 |
| --- | --- |
| r1 | XCTest 窗口标识简写查询最多 128 字符；改用显式 identifier predicate。 |
| r2 | 测试误用“播放中”，实际繁体状态为“正在收聽”；按已有产品文案修正断言。 |
| r3／r4 | 暂停控件自动点击失败；改为按唯一窗口身份查询，并补录窗口树。 |
| r5 | 窗口位于外接屏负坐标，XCTest window screenshot 报 Image creation failed；App screenshot 只返回另一屏桌面，不能作布局证据。改为保留窗口树。 |
| r6 | 唯一窗口查询正确后，外接屏控件自动 hit point 仍失败。r7 核实按钮 frame 在目标窗口内，点击其中心坐标，随后两窗口暂停断言通过；不把该结果当成 VoiceOver／自动 hit point 通过。 |

更早 `/tmp/ZenPlayer-mac-ui-probe/test.xcresult` 的启动 smoke 1 项通过；终端读取验证容器 metadata 被系统拒绝后未重试绕过，最终采用 App 自己初始化其沙盒样本。所有失败发生在隔离 App／测试层，没有为让测试过关改动产品行为。

### 未运行与交付边界

1.2 的 macOS 多窗口子断言和 3.2 的窗口失焦／正常退出子断言已通过，但 macOS 三类单集入口／完整页往返、最后窗口关闭、全屏、真实音视频／无重复音轨听感、VoiceOver／键盘焦点仍未完成。静音 WAV 使用本容器 file URL，不能证明真实下载绑定、下载传输、RNNoise／增强听感或远端失败。iPhone 后台／锁屏／PiP／中断、安装升级和异常强杀等原缺口继续保留；阶段仍为 In Verification。

本地提交标题：`补充 macOS 多窗口与退出续听隔离回归`，提交身份用 `git log -1 --format='%H%n%B' --grep='^补充 macOS 多窗口与退出续听隔离回归$'` 查询。不 push、PR、主规格同步、归档或发布。

提交前检查通过：5 个 change 的 OpenSpec strict 校验；新增 Python 脚本 AST／help／拒绝仓库内输出与缺失依赖缓存的 smoke；7 个 Markdown 文件链接；Git 范围与空白检查（包含新增文件审查）。未发现新增需改动生产代码的 review 问题。未完成的验收保留为未完成，不将本地提交视为阶段 Done。

## 2026-09-26 Mac 完整播放页崩溃与入口回归

基线 `baab993`，开始工作区干净。继续本轮目标的 M1～M4 集成验收；没有新业务功能或下一里程碑。iPhone 设备再次查询仍为 Developer Mode Disabled（`/tmp/ZenPlayer-device-continuation.json`），本轮未向手机安装 App。

### P1：进入完整播放页的实际崩溃

`/tmp/ZenPlayer-mac-entry-r1/tests.xcresult` 实际从迷你条进入 PlayerView 时 App SIGABRT。系统日志原文：`failed to demangle superclass of VideoPlayerView from mangled name 'So12AVPlayerViewC': unknown error`。崩溃栈为 `_AVKit_SwiftUI → getSuperclassMetadata → swift fatalError`，独立验证 bundle 与时间一致；报告 `~/Library/Logs/DiagnosticReports/ZenPlayer-2026-09-26-151756.ips`。`otool -L` 确认失败产物有 `_AVKit_SwiftUI`、没有 `AVKit.framework`，不是从测试按钮不存在反推根因。

修复仅为 App target Debug／Release 增加 macOS 条件链接选项 `$(inherited) -Wl,-needed_framework,AVKit`，确保动态引用的 AVPlayerView 父类所在系统框架被加载且不被裁剪。不改既有 VideoPlayer、会话所有者、存储、签名、版本、第三方依赖或 iOS 链接选项。工程对象比较确认仅这两个配置项变化；设计已记录原因。

首次失败包含 1 个通过、2 个失败：最后窗口关闭测试通过；完整页触发产品崩溃；后续旧生命周期测试的 runner 在 `XCTCrashLogTracker.waitForPendingCrashlogs()` 崩溃，不能把该测试登记通过。修复后 `/tmp/ZenPlayer-mac-entry-avkit-r2` 完整页及同集往返已执行，最终 2 通过／1 失败：删除动作与菜单栏“编辑→删除”同名导致 XCTest 查询歧义，已限定为窗口内上下文菜单的 trash 标识，未改产品删除逻辑。

### 实际通过的入口和数据子断言

`/tmp/ZenPlayer-mac-entry-final/{build,tests}.xcresult`：**3 项 UI 测试、0 失败、0 跳过，108.875 秒**。测试使用隔离 App 自己的静音文件、完成下载索引与 30 秒进度；远端改为不可解析的 `.invalid` 地址，真实 AVPlayer 位置推进依赖实际本地索引。保持 sandbox，不接触生产容器。相较上一节增加：

- 最后窗口关闭后进程仍在，Command-N 重开仍是正在收听并继续推进位置。
- 迷你条打开完整页保持暂停且不显示重复迷你条；历史／下载列表的控制页打开和返回保持原列表，从同集记录重进仍暂停。
- 停止后在实际下载列表右键删除；无播种冷启动的只读断言核实文件已不存在、原进度文件仍可解码且至少 30 秒；首页显示删除前的暂停位置，没有活动会话。

结合既有两端 PlayerViewModel 请求身份／同键测试、三类入口源码走读和 iOS 模拟器跨页证据，1.2 工程完成条件满足，现 4/6。实际系列条目跨更多样本、原生音视频／全屏、VoiceOver／Reduce Motion、iPhone 生命周期等仍在 2.2／3.2 的验收范围，不因 1.2 勾选宣布整个 M1 或 AT 完成。

### 构建与回归

生产工程的 macOS 和 iOS Simulator `xcodebuild test` **各 86 项、0 失败**，包含 App 编译，证据 `/tmp/ZenPlayer-avkit-review-{mac,ios}.{xcresult,log}`。命令沿用 scheme ZenPlayer、既有 `/tmp/ZenPlayer-M0-{mac,ios}` derived data 和 iPhone 17 UUID，`-parallel-testing-enabled NO -collect-test-diagnostics never`。App 数据容器未用于这些单元测试。

macOS Release 构建通过：`/tmp/ZenPlayer-avkit-release.{xcresult,log}`，命令为 `xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/ZenPlayer-avkit-release -clonedSourcePackagesDirPath /tmp/ZenPlayer-M0-mac/SourcePackages -resultBundlePath /tmp/ZenPlayer-avkit-release.xcresult build`。Debug UI 产物与 Release 可执行文件的 `otool -L` 均确认存在 AVKit 和 `_AVKit_SwiftUI`。Release 仅构建与链接检查，未把它写成 Release UI 运行通过。

### 最终补充回归与交付

随后补上“删除下载后从历史打开不可用远端，失败后重启也不覆零”的实际链路，最终 `/tmp/ZenPlayer-mac-entry-final-r4/{build,tests}.xcresult` 均通过：**3 项、0 失败、0 跳过，118.909 秒**。该轮对应当前全部 77 个 Swift／Python／本地化输入与生产 pbxproj SHA-256，已逐项核对；13 份窗口树附件导出到 `/tmp/ZenPlayer-mac-entry-final-r4-attachments/`。菜单歧义和原生完整页崩溃均不再出现。

复现：`python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-entry-final-r4 --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages`，重新执行须换新 output。只读删除核实只在隔离验证 App 启动时执行，生产代码没有测试入口。终端未读取或修改任何生产容器；测试结束通过 tearDown 终止验证 App。

M1 仍 In Verification（4/6）；M0／M2～M4 原设备与总验收门槛不变。没有验证 iPhone 真机后台／锁屏／PiP、真实音视频听感、原生全屏、VoiceOver／Reduce Motion、参考设备端到端性能、实际下载传输／分享／降噪增强或安装升级。已知外接屏 XCTest 截图／自动 hit point 限制继续明确保留，坐标点击后的实际状态断言不等于辅助功能通过。

本次本地提交标题：`修复 macOS 完整播放页崩溃并验证下载删除保留进度`；用 `git log -1 --format='%H%n%B' --grep='^修复 macOS 完整播放页崩溃并验证下载删除保留进度$'` 查询实际提交身份。不 push／PR／sync／archive／发布。

提交前检查通过：5 个 change 的 OpenSpec strict 校验；OpenSpec apply 读取 4/6 完成且仍有 2 项未完成；工程 plutil 解析、Python AST／CLI help、34 个相对文件链接和 Git 空白／范围检查。Review 核对过 12 个改动文件；无其他暂存、未暂存或新增用户文件混入，已修复问题均有实际回归证据，未完成验收仍明确保留。


## 2026-09-26 完整页暂停断言与队列 UI 补充

M2／M3 补验时发现 Mac 完整页使用文字“播放／暫停”按钮，旧测试对 `pause.fill` 的不存在断言不能单独证明暂停；既有“已暫停”状态及保存位置断言仍有效。本轮改为正向要求“播放”存在、“暫停”不存在，完整 Mac 6 项回归通过（`/tmp/ZenPlayer-mac-queue-r3/tests.xcresult`）。新队列用例也验证同一会话自然推进、关闭连播后媒体时间继续增加和冷启动不自动播放，后续加强定向通过（`/tmp/ZenPlayer-mac-queue-final/tests.xcresult`）；详情见 [M2 证据](../play-series-in-order/verification.md#2026-09-26-mac-实际连播与偏好回归)。

没有修改生产会话实现。S8 明确包含 VoiceOver 使用条件，现有可访问性树／大字体／几何断言不能替代实际朗读与焦点操作，因此 2.2 继续未勾选；iPhone Developer Mode 实查仍 Disabled，3.2 也未完成。M1 保持 4/6、In Verification。本次仅本地提交 `补充 Mac 连播与首页下一集实际回归`。
