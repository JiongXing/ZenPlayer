# M4 验证记录

状态：In Verification。基线 main @ 096307d，开始时工作区干净。持续目标已授权 M1～M4 实施、review 修复与本地提交；不 push／PR／发布／sync／archive。

范围：PRD F3-01～04、Q-03／04、AT-22～26，联调 AT-09／19；总验收保留 M0～M3 未验设备子断言。唯一任务清单为 tasks.md。

初始：自动化、构建、性能及实际 UI／设备均未运行；不能将规划状态视为实施完成。

1.1 通过：先写 6 项检索／集数解析 XCTest，再接入纯实现；macOS App 编译及 77 项测试、0 失败。证据 `/tmp/ZenPlayer-M4-search-core.xcresult`、`.log`。该结果不包含随后建立的 ViewModel 测试。

1.2 通过：新增 5 项 ViewModel 测试，macOS App 编译及 82 项、0 失败，`/tmp/ZenPlayer-M4-models-r2.xcresult`／`.log`。初次 `/tmp/ZenPlayer-M4-models` 构建失败：独立测试 target 缺 APIService 所需 CategoryData 源文件，补齐现有 Models/Category.swift 后通过。无生产逻辑失败。


## 2.1／2.2 与最终回归（2026-09-26）

实际环境：Apple M5，macOS 27.0 (26A428)，Xcode 27.0 (27A266a)；模拟器 iPhone 17／iOS 27.0，id F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425。App 1.1.0／Build 110，部署目标 iOS 17／macOS 14 未改。测试 bundle 无 App host，不读写真实 App 数据；媒体使用临时 4 秒静音 WAV（单声道、8kHz），网络与故障通过 loader／处理器注入。

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| UI 接入首轮两端构建／测试 | 各 84 项、0 失败 | `/tmp/ZenPlayer-M4-integration-{mac,ios}.xcresult` 及 `.log` |
| 最终 macOS 构建／测试 | **通过**，86 项、0 失败 | `/tmp/ZenPlayer-M4-final-mac.xcresult`、`.log` |
| 最终 iOS 模拟器构建／测试 | **通过**，86 项、0 失败 | `/tmp/ZenPlayer-M4-final-ios.xcresult`、`.log` |
| 搜索与真实播放器联调 | **通过**，只显示第 2 集，自然结束仍到第 5 集；快照仍 1／2／5 | `PlayerQueueIntegrationTests.testFilteredEpisodeStillNaturallyAdvancesThroughFullLoadedQueue`，上述两端结果 |
| 静态布局 | **通过（局部）**，360pt 搜索输入／计数／范围／零结果与跳集输入按钮明暗外观可读 | `/tmp/ZenPlayer-M4-native-search-{light,dark}.png`、`/tmp/ZenPlayer-M4-native-jump-{light,dark}.png`；生产组件 NSHostingView 隔离渲染并目视检查 |
| ImageRenderer 首次尝试 | **未验证输入框**：原生 TextField 显示不支持标记，已改用 NSHostingView | `/tmp/ZenPlayer-M4-search-{light,dark}.png` 不能用作输入框验收 |

命令：

```sh
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' -derivedDataPath /tmp/ZenPlayer-M0-mac -resultBundlePath /tmp/ZenPlayer-M4-final-mac.xcresult test
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' -derivedDataPath /tmp/ZenPlayer-M0-ios -resultBundlePath /tmp/ZenPlayer-M4-final-ios.xcresult test
```

M4 新增 15 项：6 个检索／解析、7 个页面模型、1 个完整队列真实播放器联调、1 个性能样本。回归包含 M0～M3 的 71 项。结构上搜索只读取本页已加载数据；定位方法不依赖播放／进度服务；EpisodeRowView 始终收到原完整 queueSnapshot，点击目标后才播放。SwiftUI task 的高亮计时按请求 UUID 取消和校验，缩短动画直接滚动。以上调用链检查不等同实际点击／VoiceOver 通过。

## 性能样本与边界

`CatalogSearchPerformanceTests`：1000 课程、2000 集，已加载并归一化后的数据；8 种查询 × 10 轮＝80 次，含多词、简繁、全角、数字精确、零结果、清空。计时从赋值 searchQuery 到派生结果完成（无防抖），P95 取排序第 76 项。不是输入事件到画面显示的端到端计时。

| 环境 | 课程 P95 | 单集 P95 | 判定 |
| --- | --- | --- | --- |
| macOS M5 最终 Debug | 0.781 ms | 1.534 ms | ViewModel 计算低于 200ms |
| iPhone 17 模拟器最终 Debug | 7.835 ms | 3.265 ms | ViewModel 计算低于 200ms |

首轮值分别为 macOS 0.954／1.643ms、模拟器 1.303／2.608ms，保留波动，不报告为真机提升比例。参考 iPhone 的真实输入→画面 P95、100ms 操作反馈、动态字体和键盘性能**未运行**，AT-26 不通过关闭。

## Review 与修复

- 请求取消／快速重进：isLoading 早退可能挡住新请求；改为请求 UUID，仅最新未取消结果可更新列表、错误和 loading。新增取消后即刻重进及旧系列迟到不能替换新快照两项测试，通过。
- 主操作点击面积：把 44pt 下限放到跳集提交／取消、工具栏和定位按钮的标签内，避免只有外层布局变大。
- 本地化只新增 15 个 key，保留原文件排序与原值；没有全文件重排。清理字表恒等项，不扩展检索语义。
- 修正 M3 验证记录中的模拟器名为实际 iPhone 17／iOS 27.0；其 UUID 和原测试证据不变。
- 编译仅有既有 AppIntents 元数据提取提示；最终无测试失败。独立预览日志有沙箱扩展诊断，但进程返回 0 且原生渲染输出完整；不是 App 测试失败。

## AT-01～AT-26 总验收矩阵

“通过”只限定在证据列所述子断言；每行的真实 UI／设备缺项都保留，不能据此将整条 AT 或整轮标为通过。历史证据见 M0～M3 各 change 的 verification.md，最终 86 项包含其自动化回归。

| AT | 已通过证据／子断言 | 未运行／剩余验收 |
| --- | --- | --- |
| 01 | App 唯一会话调用链；模拟器首页续听→切 Tab→完整页往返通过 | 真机声音连续／无重复加载、播放中跨系列浏览 |
| 02 | 状态／真实 PlayerViewModel 同键复用；模拟器迷你／完整页和历史／下载同集重进保持暂停 | 真实设备、其他入口及重复快速点击 |
| 03 | 三处控制绑定同一模型；模拟器迷你条暂停→完整页仍暂停 | 真机锁屏交替控制及位置同步 |
| 04 | stop 状态；模拟器停止后迷你条隐藏，冷启动仅续听卡、无活动播放，点击启动本地样本 | 真机冷启动与锁屏／系统信息清理 |
| 05 | 真实 B 延迟不能覆盖 C，旧快照／媒体回调隔离 | 快速 UI 选择及真实网络延迟／旧进度实测 |
| 06 | 中断恢复资格、手动暂停不唤醒的状态测试 | 耳机拔出、来电、系统通知实际顺序 |
| 07 | 模型／真实 AVPlayer 的 2→5、重复结束；实际 Mac App 本地 WAV 自然 1→2，手动 2→5 | 真机音视频系列连续播放、实际系列页入口 |
| 08 | 实际 Mac 开关关闭后媒体时间继续推进、关闭时自然结束不切集、开启时末集不循环、首尾禁用、冷启动偏好保留 | iPhone／真实音视频控制路径 |
| 09 | 模型过滤 2→5；实际 Mac 搜索只显示 1 后点击播放，自然结束进入隐藏的 2，清筛选保持暂停，手动下一集到 5 | iPhone／真实音视频与其他目录样本 |
| 10 | 类型／离线策略、坏媒体失败保留目标、手动重试恢复位置 | 实际网络断开、下载文件与远端失败路径 |
| 11 | 暂停切源保存即时位置、失败不覆零 | 原生手势／不同真实音视频时间轴和切换失败 |
| 12 | 编译／所有权／回调门控；实际 macOS 双窗口暂停同步、关闭其中一个窗口及最后窗口重开、完整页往返、隐藏后位置推进、正常退出保存和冷启动恢复（静音样本） | iPhone 后台／锁屏／PiP／全屏；Mac 原生全屏／真实媒体听感及更广导航路径 |
| 13 | 本地候选／真实 continue；模拟器首页一次点击启动 30 秒历史样本，无中间页面 | 真机位置精度和更多历史样本 |
| 14 | Mac 实际 App 注入分类网络失败，错误与本地卡同时可见，一次点击从 30 秒开始播放且媒体时间推进 | 物理断网、实际下载内容离线点击及真机 |
| 15 | 实际 Mac 首集完成后显示下一集自身 7 秒并单击续听；末集完成后冷启动回退到其他未完成记录；模型无候选规则 | 实际无候选隐藏、紧邻下一集已完成及真机 |
| 16 | 30 条长期存储、最近 10 条、磁盘重读；行状态直接查长期仓库 | 三个真实入口、重开 App 后旧集展示／播放 |
| 17 | 即时／周期提交、seek 门控、原子写入及文件冷读 | 原生拖动／锁屏、强制终止重开、后台实际保存间隔 |
| 18 | 未知时长完成、近尾不完成、真实结束后同集重听零起点 | 真实未知时长媒体、原生拖动与重听展示 |
| 19 | 定位模型／模拟器跳集；Mac 历史返回 12、筛 21 后“定位上次收聽”清筛选并滚回 12、无播放，退出冷启两条进度字节不变；Mac 删除隔离下载后保留进度 | 约 2 秒高亮、VoiceOver／Reduce Motion、其他历史行／长历史实际定位及 iPhone 删除下载 |
| 20 | 隔离 fixture／文件迁移、缺字段、幂等、失败备份及新值保护 | 测试安装升级、每中断点真实进程演练 |
| 21 | 单条损坏隔离、写失败／重试、旧文件不清空 | 真实错误提示／重试交互与设备空间受限路径 |
| 22 | 模拟器零结果／清词；实际 Mac 编号升降序、清词保留方向、日期菜单选中值 | 其他分类、全部日期格式排序及真机 |
| 23 | 简繁／全半角／多词、前导零数字精确优先、原标题保持 | 实际输入法交互 |
| 24 | 模拟器和 Mac 的 0012 定位第 12 集；Mac 清词／收面板保留暂停；实际已有第 0 集定位且不开播 | 2 秒高亮时序、全角／中文输入法实景及真机 |
| 25 | 模拟器零结果／清词；Mac Escape、非法／缺集反馈；两个第 12 集明确等待选择，选第二项后按其 id 滚动，不播放／改进度 | 更广非法输入、更多重复项／长候选及真机 |
| 26 | 范围／错误模型和计算 P95；Mac 21／24 部分加载时零结果仍保留范围说明、清词恢复 21 集；模拟器标准／最大辅助字体及深色列表可达 | 真机端到端 P95／反馈，VoiceOver／Reduce Motion、其他字号／窗口组合和更广列表样本 |

原功能回归：分类排序已由真实 ViewModel 测试覆盖；地址／本地优先／源回退和处理器失败保留原声有策略／播放器隔离证据；下载暂停／恢复／删除、文件分享、实际 RNNoise 降噪听感、音量增强与两平台完整播放界面操作均**未运行**。处理器替身的失败测试不等于真实算法听感回归。没有静默删除这些发布门槛。

## 阻塞、风险与下一步

2026-09-26 再查 `devicectl`：用户设备 jxing's16pro（iPhone 16 Pro／iOS 26.6.2）Developer Mode 仍 disabled；没有向其安装 App，没有使用列表中其他人的手机。已请求用户开启、连接／解锁后回复。缺可操作的 iPhone 是后台／锁屏／PiP 的环境阻塞；macOS 全流程 UI 和辅助功能也尚无证据。当前独立渲染仅覆盖局部静态布局，不声称焦点／提交动作／大字通过。

固定简繁表保留未覆盖异体字，符合首版词典边界；查询不上传。仍需真实媒体时间轴和跨系列身份更广样本。临时 xcresult／日志／截图位于 `/tmp`，可能被系统清理，仓库记录结果及复现命令。

M4 保持 In Verification，3.2 未完成；M0～M3 同样保留各自设备缺口。下一步是补齐本表实机／UI、性能与旧能力验收，不创建新业务阶段，不标 Done、不发布。


## 3.1 本地交付检查

通过：5 个 change 的 `OPENSPEC_TELEMETRY=0 openspec validate --all --strict --no-interactive`；26 个修改／新增文件内容与 19 个相对链接、15 个新增繁体 key、原 catalog 值保持；工程对象对比仅变更既有测试 Sources 并增加所需引用，App／测试构建配置值均不变。`git diff --check` 通过；包括新增文件内容审查，未把未跟踪文件遗漏。

阶段提交标题：`实现 M4 页内搜索与精确集数定位`。实际 Git 身份可用 `git log -1 --format='%H%n%B' --grep='^实现 M4 页内搜索与精确集数定位$'` 查询。此前 M3 本地提交为 096307d0cf330505350cc3598dfe8798fd60dc31。本地提交只交付已实现与验证过的工程部分，不代表 3.2 完成；不 push／PR／sync／archive／发布。

## 2026-09-26 隔离 App UI 验证与补充交付

本轮 review 基线为 `4a01cf3`，源代码修复限于迷你条安全区和“我的”浏览页值路由。两处实际 UI 缺陷的失败现场、调用关系和修复见 [M1 补充记录](../unify-playback-session/verification.md#2026-09-26-跨阶段-ui-review-补充)；同步更新 M1 design 使其描述最终实现。未修改存储／迁移／队列／检索算法、生产工程配置、签名、版本、依赖或真实 App 数据。

新增 [UI 测试说明](../../../ZenPlayerUITests/README.md)、2 项 XCTest UI 测试、隔离播种器及运行脚本。脚本先复制当前生产源码／工程，添加仅副本使用的 UI target，构建并核对 bundle 为 `com.jxing.ZenPlayer.StageValidation` 后安装；核对数据容器元数据再播种 180 秒静音 WAV、30 秒进度和完成下载索引。源码没有测试模式或测试行为分支。网络目录测试使用当时真实 89 门课程分类／`01-001` 的 21 集，目录可用性及未来内容变化是明确的外部依赖。

### 已通过的实际 UI 子断言

- 首页本地续听→迷你条出现；标题可访问入口至少 44pt 高、其底边不超过 Tab 顶边；切“我的”实际选中 Tab，暂停后开关完整页仍暂停且完整页不重复迷你条。
- 最近播放／下载完成页的迷你入口→完整页→返回仍在原列表；点击同一历史／下载记录仍保持暂停。停止后迷你条消失；终止再启动仍有续听卡、无活动暂停动作或迷你条。
- 分类输入无匹配词→零结果反馈→一键清除恢复课程；系列输入 12 仅 1 集；跳 99999 显示无此集且保留筛选；跳 0012 清筛选恢复 21 集、目标第 12 集可点击、键盘收起，没有自动创建播放会话。

`/tmp/ZenPlayer-stage-ui-final-r3/tests.xcresult` 的 2 项、0 失败，运行耗时 73.493 秒。源码 SHA-256 与当前 App／UI 测试文件逐一核对一致。截图导出至 `/tmp/ZenPlayer-stage-ui-final-r3-images/`，已目视检查首页／我的迷你条、最近播放返回后的原列表和第 12 集定位。定位截图在测试断言后捕获，不证明两秒高亮时序。

### 失败与工具限制（保留历史）

- `/tmp/ZenPlayer-stage-ui-playback{,-r2}.xcresult` 和 `routing.xcresult` 的失败复现 Tab 遮挡；`detail-routing.xcresult` 与 `final-r2/tests.xcresult` 的失败复现历史页返回丢失；均在后续测试中修复验证。
- `/tmp/ZenPlayer-stage-ui-series.log` 曾因目的地 UUID 拼写错误退出 70，未运行测试。新脚本对真实设备 destination／不可用 UUID 提前拒绝，已实测 exit 2 且没有创建输出目录。
- 脚本第一次 `/tmp/ZenPlayer-stage-ui-final` 在生成副本时参数名冲突（`add` 的位置参数与对象 `name` 属性）而失败；改名后构建、播种及执行成功。未触及生产文件。
- Xcode 27 在测试已结束后阻塞于额外 `simctl diagnose`，通过进程采样确认。仅终止本轮三个诊断子进程后，对应 xcodebuild 按真实断言结果退出（失败轮 65、成功轮 0）。`final-r3` 的测试断言和截图完整，但额外系统诊断不完整；第一次过早导出也因 xcresult 尚未封口失败，封口后成功。脚本已改 `-collect-test-diagnostics never`，保留测试日志／显式截图。

### 两端源码回归

最终源代码两端 `xcodebuild test` 均包含 App 编译，**各 86 项、0 失败**；证据 `/tmp/ZenPlayer-stage-review-final-{mac,ios}.xcresult` 及 `.log`。测试依旧使用原独立 XCTest target，不修改生产容器。命令沿用前文的 scheme、两端目的地和 `/tmp/ZenPlayer-M0-{mac,ios}` derived data，仅 result bundle 改为此处路径；iOS 加 `-parallel-testing-enabled NO`。

3.2 仍未完成。上方矩阵只增加实际模拟器子断言；真机 Developer Mode 阻塞、iPhone 后台／锁屏／PiP／中断、macOS 多窗口／退出、VoiceOver／大字／Reduce Motion、参考真机端到端性能、真实下载／分享／降噪／音量与升级回归均未据此通过。完整页原生音频控件在该模拟器对 WAV 的显示也不作为真实音视频／PiP 证据。没有把缺口改成可接受例外，M0～M4 仍为 In Verification。

### 最终脚本与本地提交检查

最终脚本端到端运行 `/tmp/ZenPlayer-stage-ui-final-r4` **通过**：build-for-testing、安装／身份核对、fixture 播种、test-without-building 全部 exit 0，2 项 UI 测试、0 失败（73.766 秒），没有挂起的诊断采集。日志 `build.log`／`fixture.log`／`test.log`，结果 `build.xcresult`／`tests.xcresult`；源码 SHA-256 与当前全部 App／UI 测试文件一致。复现命令：

```sh
python3 Scripts/run-stage-ui-tests.py --destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' --output /tmp/ZenPlayer-stage-ui-final-r4 --package-cache /tmp/ZenPlayer-M0-ios/SourcePackages
```

重跑时必须换一个尚不存在的 output 目录。临时产物不纳入仓库，可能被系统清理；源码、脚本和实际结果摘要已保存。

通过：5 个 change 的 OpenSpec strict 校验、Python 语法及 CLI help／拒绝错误目的地 smoke、相关 Markdown 文件链接、`git diff --check`；审查覆盖所有新增脚本／测试和已跟踪改动。没有改动生产 pbxproj、PRD、Roadmap 状态或主规格。已运行测试的历史失败原因均已定位；最终没有失败断言待修。

补充本地提交标题：`修复迷你播放器遮挡与返回路径，补齐隔离 UI 回归`。实际身份通过 `git log -1 --format='%H%n%B' --grep='^修复迷你播放器遮挡与返回路径，补齐隔离 UI 回归$'` 查询。提交仅交付修复、验证 Harness 和现有 change 证据，不等于验收 Done；没有 push／PR／sync／archive／发布。

## 2026-09-26 动态字体与末行验收补充

基线 `main @ 8994d49`，工作区起始干净。本轮继续 3.2 中可独立运行的动态字体、明暗外观、长标题可访问名和列表末行子断言。复查用户 iPhone `jxing's16pro`（devicectl ID `CBE73FBF-972C-572A-A490-D06203CE3840`）Developer Mode 仍为 disabled；没有向真机安装或写数据，不重复请求已在等待的设备准备。

### Review 发现及局部修复

最大辅助字体下，旧紧凑单集行的集数、时长、文件大小和下载按钮共享横排空间，时长被压到不可读，集数和大小逐字竖排。真实失败布局截图：`/tmp/ZenPlayer-ui-accessibility-dark-images/4D6A1E68-226D-425C-8B23-B56B409D9A58.png`。本轮只在 `isCompact && dynamicTypeSize.isAccessibilitySize` 时改为纵向字段布局，保留完整标题、进度、定位标记和既有下载动作；常规字号及宽屏使用原布局。没有修改播放器、进度、队列或下载算法。

UI Harness 增加 `--appearance`／`--content-size`：通过 simctl 实际设置并读回验证，保存 `ui-settings.json`，无论测试成功或失败均还原所选模拟器的原外观／字号。没有修改用户 macOS 或真实设备设置。样本使用长标题，确认视觉截断后完整可访问名仍存在。新增第 3 项 UI 测试：暂停本地样本→浏览真实系列→跳至最后第 21 集→滚动并检查位于迷你条上方、会话仍暂停；另为第 12 集新增时长实际可见且未挤成窄条的断言，截图同时保存可访问性树。

### 失败记录与修正

- `/tmp/ZenPlayer-ui-accessibility-dark/tests.xcresult`：2 项中 1 项失败。长卡片在最大字号下部分位于迷你条后方，XCTest 默认 `.tap()` 的命中点落到迷你条，误开完整页。UI 数据和截图确认这次失败是测试未先暴露目标，不是历史记录消失；同时目视发现上述单集行的真实布局缺陷。
- `/tmp/ZenPlayer-ui-accessibility-layout/tests.xcresult`：3 项中 1 项失败。已修正历史／下载操作，但新增末行测试的粗粒度上滑越过课程卡片。改为像用户一样先定位实际内容安全区，点击其中可见的卡片区域；保持页面身份、暂停、末行几何位置等断言，没有移除产品验收条件。
- 两次失败后 `ui-settings.json` 和 simctl 读回均证明外观／字号已还原为 `light`／`large`。临时失败产物保留，未将测试失败改记为通过。

### 已通过的最大字体 UI

`/tmp/ZenPlayer-ui-accessibility-fixed/tests.xcresult`：**3 项、0 失败**（103.324 秒），构建／播种／测试命令全部 exit 0。iPhone 17／iOS 27.0，`dark` + `accessibility-extra-extra-extra-large`，实际设置和还原值都记录在 `ui-settings.json`。完整生产源码副本运行，没有 App 测试模式。可复现命令（output 必须换成新目录）：

```sh
python3 Scripts/run-stage-ui-tests.py --destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' --output /tmp/ZenPlayer-ui-accessibility-fixed --package-cache /tmp/ZenPlayer-M0-ios/SourcePackages --appearance dark --content-size accessibility-extra-extra-extra-large
```

已目视检查两张最终截图：`/tmp/ZenPlayer-ui-accessibility-fixed-images/E47C68FF-C994-4573-988C-EBF6CAC48D6E.png`（第 12 集字段可读）、`BCAE7CF7-019F-4D05-B9AA-93E48E74C8C2.png`（末集信息和下载入口均在迷你条上方）。最大字体下单行所占空间变高，可正常滚动，不以压小用户字体换取显示。首页／我的的既有卡片仍沿用原主题配色，不宣称全 App 深色视觉重新设计。

这些证据只覆盖该模拟器两种字号／外观组合下的具体路径，不证明全部尺寸、VoiceOver 朗读／焦点顺序或 Reduce Motion，也不替代参考真机性能、macOS 多窗口、真实 iPhone 后台／锁屏／PiP／中断及旧能力全流程。3.2 继续未勾选，阶段不标 Done。

### 本轮最终回归与交付

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| 最大辅助字体／深色实际 UI | 3 项、0 失败，103.324 秒 | `/tmp/ZenPlayer-ui-accessibility-fixed/tests.xcresult`、`test.log` |
| 常规字号／浅色实际 UI | 3 项、0 失败，100.378 秒 | `/tmp/ZenPlayer-ui-accessibility-standard/tests.xcresult`、`test.log`；参数 `--appearance light --content-size large` |
| macOS App 编译／自动化 | 86 项、0 失败 | `/tmp/ZenPlayer-accessibility-final-mac.xcresult`、`.log` |
| iOS App 编译／自动化 | 86 项、0 失败 | `/tmp/ZenPlayer-accessibility-final-ios.xcresult`、`.log` |
| Harness／规格／范围 | 通过 | Python 语法／help、5 个 change strict 校验、相关文件链接及 Git 差异检查 |

两套 UI 各 3 项为同一套测试的两种配置，不计作 6 个独立场景。两套 `context.json` 中所有 App 与 UI 测试源码 SHA-256 均与当前文件一致；两套 `ui-settings.json` 的 original 与 restored 均为 light／large。常规字号末集截图 `/tmp/ZenPlayer-ui-accessibility-standard-images/4BC9D9CF-17B8-40ED-B9F4-DB7A979212AF.png` 已目视检查，保留原紧凑行，末集没有被迷你条遮住。UI 日志含既有 AVAudioSession 主线程调用提示，未把它解释为已经发生的卡顿或已通过的反馈时延。

两端命令沿用当前 scheme／目的地和 `/tmp/ZenPlayer-M0-{mac,ios}` derived data，resultBundlePath 为上表路径；iOS 测试关闭并发。所有真实设备和更广辅助功能缺口继续保留。部署版本、签名／依赖、生产工程、主规格和 Roadmap 状态不变。

本地提交标题：`修复辅助字体下单集信息布局并补充 UI 验收`；实际身份用 `git log -1 --format='%H%n%B' --grep='^修复辅助字体下单集信息布局并补充 UI 验收$'` 查询。只本地提交，不 push／PR／sync／archive／发布。

## 2026-09-26 macOS 生命周期验收补充

在 `de77e31` 之后补充独立 macOS 验证 App，新增 `Scripts/run-mac-stage-ui-tests.py`、`ZenPlayerUITests/MacStageFixture.swift`、`MacStageUITests.swift`。生产代码、工程与配置未变。实际窗口／Command-H／Command-Q、两窗口同步暂停、冷启动保留 50 秒并恢复播放已通过；`/tmp/ZenPlayer-mac-lifecycle-r7/tests.xcresult` **1 项、0 失败，35.926 秒**，构建及签名／sandbox 检查通过。

原失败尝试、样本安全边界、输入 hash、复现命令及剩余项详见 [M1 实际窗口记录](../unify-playback-session/verification.md#2026-09-26-macos-实际窗口与退出补充)。外接屏上的截图和自动 hit point 有工具限制；最终用窗口树与实际控件中心点击后的状态／位置断言验证生命周期，未声称可访问性或布局截图验收通过。

复核并复用未变化源码的两平台各 86 项 XCTest 和 iOS 深色最大字体 3 项 UI 证据；本次新增 Mac 测试不替代 iPhone 真机、全屏、真实媒体听感、下载／分享、VoiceOver／Reduce Motion、端到端性能与升级迁移的剩余门槛。3.2 继续未完成，M0～M4 状态不变。交付标题 `补充 macOS 多窗口与退出续听隔离回归`；仅本地提交。

## 2026-09-26 Mac 完整播放页与下载删除回归

实际 UI 复现 P1：从迷你条进入完整页触发 `_AVKit_SwiftUI` 的 AVPlayerView 父类解析崩溃。已通过 macOS Debug／Release 显式保留 AVKit 系统框架链接修复；只变更 App target 两个条件链接项，不修改签名、版本、第三方依赖或业务源码。失败现场、定位和最终结果见 [M1 审查记录](../unify-playback-session/verification.md#2026-09-26-mac-完整播放页崩溃与入口回归)。

最终 macOS 实际 UI 3 项通过（118.909 秒，`/tmp/ZenPlayer-mac-entry-final-r4/tests.xcresult`）：完整页／历史／下载同集暂停往返，最后窗口关闭重开，已验证的双窗口／退出路径，以及删除下载后冷启动、历史重开遇远端失败、再次启动均保留原进度。窗口树附件和只读文件断言支持这些结论；不靠静音样本证明听感。该轮全部源码及工程 SHA-256 与待提交文件一致。

重新执行两平台 App 构建与 XCTest：各 86 项、0 失败（`/tmp/ZenPlayer-avkit-review-{mac,ios}.xcresult`）；macOS Release 构建和二进制 AVKit 链接检查通过（`/tmp/ZenPlayer-avkit-release.xcresult`），Release UI 未运行。M1 1.2 已达工程条件，4/6；M4 3.2 仍未完成，整轮仍 In Verification。iPhone Developer Mode 再查仍 Disabled；后台／锁屏／PiP 和既有可访问性、性能、旧能力、升级迁移缺口未被豁免。

本轮仅本地提交 `修复 macOS 完整播放页崩溃并验证下载删除保留进度`，不 push／PR／sync／archive／发布。


## 2026-09-26 Mac 搜索、排序与键盘 review

基线 `main @ ba6c710`；起始只有 Mac UI 测试与运行脚本的未提交改动。本轮按当前阶段 review／本地提交授权收尾。生产 App 源码、工程、签名、依赖和数据格式未改；仅补充隔离验证 Harness 和当前 change 的证据。

### Review 改进

- 搜索用例读取真实分类，检查编号升降序、清词保留降序、零结果清词和日期菜单选中值。日期项只验证实际切换，不据此宣称所有日期格式排序正确。
- 系列先筛选第 21 集，明确断言第 12 集不在结果中；Escape 取消及非法／不存在输入保持筛选，成功提交再检查清词、收起面板、目标位于迷你条上方及原暂停位置不变。没有以可见目标替代“筛选隐藏目标”条件。
- 运行器增加 `--only-testing`，仅接受源码中现有测试方法，创建输出前拒绝无效名称；使用参数数组调用 xcodebuild，并记录实际选择。省略参数仍运行全部用例。
- 外接屏负坐标下，测试出现点击未获搜索焦点／Tab 未选中。显式激活、等待布局及拖窗均未解决。最终 fixture 只在独立验证 App 内、收到首个窗口成为主窗口通知时放到主屏可见区域，立即解除观察者；没有改生产窗口行为、系统显示或输入法设置。

### 失败历史（不改记为通过）

| 运行／结果 | 实际观察 |
| --- | --- |
| `/tmp/ZenPlayer-mac-search-r1/tests.xcresult`：2 通过、2 失败 | 搜索用例 Unicode 事件合成超时；历史用例点击“我的”后仍在首页，未进入后续断言。不能据此判定 Unicode 解析或历史数据损坏。 |
| `mac-search-r2`：0 通过、1 失败 | 定向运行生效，但搜索框未获得键盘焦点，尚未到 Unicode 分支。 |
| `mac-search-r3`：2 通过、2 失败 | 显式激活后搜索焦点和 Tab 问题仍在。 |
| `mac-search-r4`：0 通过、1 失败 | 等待目录／控件布局后仍为搜索焦点失败。 |
| `mac-search-r5`：0 通过、1 失败 | 外接屏坐标拖窗未把窗口移到主屏，前置断言失败，搜索主体未运行。 |

以上路径除第一行已写全外均位于 `/tmp/ZenPlayer-<运行名>/tests.xcresult`，各轮构建通过，测试命令退出 65，均无跳过。失败现场与日志保留；临时文件可能被系统清理，不将路径存在等同于永久证据归档。

主屏后的 Unicode 尝试：`/tmp/ZenPlayer-mac-search-r6/test.log` 到达 `Type 第１２集 into TextField`，该输入框位于主屏，但仍在事件合成 30 秒后超时；没有将此解释为 parser 接受或拒绝输入。该轮最终 3 通过、1 失败、0 跳过；原历史／下载、关闭最后窗口和双窗口／退出用例已重新通过。本轮增加 `--jump-input`，默认 `0012`，保留 `第１２集` 的显式重现入口。测试从临时 scheme 的 TestAction 读取实际输入，缺少配置直接失败，不静默回退。Unicode UI 输入继续是未通过项，且没有修改 PRD／规格降低要求。


`/tmp/ZenPlayer-mac-search-final` 的批量 ASCII 输入尝试也记录失败：发送 `ZenPlayerNoMatch987654321` 后实际字段为 `ZenPlayerNoMat987654321`。精确断言没有把少字输入当成功；该轮最终 3 通过、1 失败、0 跳过。静态复核 `CatalogSearchHeader` 的原始 Binding 和 `CategoryDetailViewModel.applySearch`：检索只更新 visibleSeries，没有回写／截断 searchQuery；仍无法判定这是 XCTest 连续事件合成还是 App 在快速输入下的问题。回归 Harness 改成每键发送、等待 XCTest idle 并核对完整累计值，继续验证搜索与定位行为；不能用此配置证明高速连续输入可靠或输入到画面的 P95。这个风险继续保留，不宣称已修复业务输入。


`/tmp/ZenPlayer-mac-search-keywise/tests.xcresult`：0 通过、1 失败（84.587 秒）。逐键输入和 `0012` 提交已到达清筛选／收面板，但测试按独立 StaticText 查询 Mac 行失败。修正查询为实际 NavigationLink 的组合 Button，并在筛选前后记录窗口树；第 21 集必须存在、第 12 集必须先被隐藏，避免用永不存在的节点满足前置条件。

### 最终证据与边界

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| Mac 搜索／排序／键盘定向回归 | **1 通过、0 失败、0 跳过，75.022 秒**；逐键搜索，成功跳集输入为 `0012` | `/tmp/ZenPlayer-mac-search-row/tests.xcresult`、`test.log` |
| Mac 原有三项生命周期／历史／下载回归 | **3 项通过**；所在完整轮次另有上述搜索输入失败，不能称整轮通过 | `/tmp/ZenPlayer-mac-search-final/tests.xcresult`；核对 14 个既有测试／helper 方法和 fixture 与当前逐字相同 |
| 最新临时 App／UI target 构建、签名／sandbox | 通过，build-for-testing／test-without-building 均 exit 0 | `/tmp/ZenPlayer-mac-search-row/build.xcresult`、`build.log`、`entitlements.plist` |
| 原两平台 App／XCTest | **复用各 86 项、0 失败**；本轮未重跑 | `/tmp/ZenPlayer-avkit-review-{mac,ios}.xcresult`；已重读 summary，生产源码／工程 hash 未变 |
| 静态／文档／范围 | 通过 | Python AST／help、无效 method 和 jump-input 均 exit 2 且未创建目录、M4 strict 校验、相关 4 个相对文件链接（不含锚点）、Git diff 检查 |

最新定向运行的 77 个 Swift／Python／xcstrings 文件及生产工程 SHA-256 与待提交内容一致；文档记录不属于可执行输入。筛选前树只有第 21 集；跳转后第 12 集 Button frame 为 `(6, 419, 995, 66)`，底部 485 小于暂停迷你条顶部 747；日期 Popup 值为“日期”。导出的 4 份窗口树位于 `/tmp/ZenPlayer-mac-search-row-attachments/`。这是几何与可访问性树证据，不是截图目视／VoiceOver 朗读证据，也未测两秒高亮持续时间。xcresult 含一次内部 QoS 等待警告，没有将其解释成已测出的延迟或已修复的性能问题。

复现默认已通过路径（重跑需换不存在的 output）：

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-search-row --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages --only-testing testCatalogSortingAndKeyboardJumpPreservePausedSession
```

Unicode 变体需另加 `--jump-input '第１２集'`；新参数的解析／临时 scheme 配置可用，最终参数化脚本没有再次运行 Unicode 失败路径，之前两次硬编码 Unicode 的事件合成失败继续保留。此次没有再次执行完整四项套件，以未变化的三项已有通过证据加定向修复回归交付；不得报告为同一次四项全通过。

未关闭：Unicode 实际输入、连续快速输入少字原因、VoiceOver／Reduce Motion、参考机端到端性能、真机后台／锁屏／PiP、真实下载／分享／降噪／音量听感及升级迁移等既有门槛。未操作真实设备，未刷新 Developer Mode 状态。任务 3.2 不勾选，M0～M4 仍 In Verification，不建议标记 Done。

本次本地提交标题：`补充 macOS 搜索键盘回归并记录输入验证边界`；实际身份可用 `git log -1 --format='%H%n%B' --grep='^补充 macOS 搜索键盘回归并记录输入验证边界$'` 查询。只提交本轮 6 个 Harness／文档文件，不 push／PR／sync／archive／发布。


## 2026-09-26 Mac 连播与首页接续整合

完整独立 Mac 套件 `/tmp/ZenPlayer-mac-queue-r3/tests.xcresult` **6 项通过、0 失败、0 跳过**（273.553 秒），包含原有搜索／键盘、最后窗口、历史／下载、双窗口／退出和新增两个队列／首页用例。之后仅加强自然连播用例的实际时间推进与结束前开关断言，`/tmp/ZenPlayer-mac-queue-final/tests.xcresult` **1 项通过、0 失败**（60.011 秒）；其余测试与 helper 没有变化。实际命令和输入 hash 见 [M2 回归](../play-series-in-order/verification.md#2026-09-26-mac-实际连播与偏好回归)，首页下一集 7 秒／末集后回退见 [M3 记录](../surface-listening-progress/verification.md#2026-09-26-mac-完成后的首页接续)。

这关闭 AT-07／08／15 的上述 Mac 静音样本 UI 子断言，未把手动 2→5 算成自然推进，也未把首页快照恢复算成实际搜索行点击后连播。既有 Unicode 事件合成与连续输入少字风险没有关闭；默认搜索仍逐键核对、跳集为 0012。

Review 修正测试对 NSNumber 复选框值及完整页文字按钮的读取；旧完整页暂停检查新增“播放”存在的正断言。生产代码／工程未变，两平台各 86 项自动化沿用既有通过证据。已复查 iPhone 仍 Developer Mode Disabled（`/tmp/ZenPlayer-device-queue-review.json`），没有安装或改设备。

3.2 仍未完成，M0～M4 均 In Verification。真实媒体／真机、输入法／连续输入、VoiceOver／Reduce Motion、端到端性能、下载／分享／音效、分类失败与部分首页／定位／升级路径仍需对应证据。交付标题 `补充 Mac 连播与首页下一集实际回归`，只本地提交。

## 2026-09-26 分类失败与清筛选定位整合

本轮新增分类失败下首页本地续听、历史返回系列与筛选后“定位上次收聽”的实际 Mac UI 验证。完整套件 `/tmp/ZenPlayer-mac-catalog-r3/tests.xcresult` **7 通过、1 失败、0 跳过**；失败为新历史用例误用英文逗号匹配组合标签，修正后 `/tmp/ZenPlayer-mac-catalog-r4/tests.xcresult` 定向 **1 通过、0 失败、0 跳过（25.698 秒）**，其余测试／共享 helper 未改。不是同一轮 8 项全通过。失败尝试、源文件 hash、窗口树及命令见 [M3 本轮记录](../surface-listening-progress/verification.md#2026-09-26-分类失败与历史定位-review)。

补充 AT-14／19 的矩阵子断言：真实首页错误区与本地续听同时可用；历史引用返回目标，12 集 42 秒／18 集完成／21 集未听状态显示正确，筛 21 后上次定位清词、滚回 12 且不播放，退出重启只读证明两条进度字节未变。API 故障和目录响应来自独立验证 App 的 URLProtocol；保留真实请求处理与 UI，不把它算物理断网或远端目录服务验收。

生产 App／工程未变，两端 86 项证据复用。3.2 保持未勾选；约 2 秒高亮、VoiceOver／Reduce Motion、Unicode／连续快速输入、真机生命周期、端到端性能、无候选 UI、真实下载／分享／音效与迁移门槛继续保留。阶段状态不变，本次只本地提交 `补充分类失败续听与历史定位隔离回归`。

## 2026-09-26 搜索入口连播与目录边界

基线 `main @ b56de9a`，开始时工作区干净。继续任务 3.2 的 AT-09／24／25／26 UI 子断言。复用独立 Mac bundle 和临时工程协议：新增 `--stage-queue-catalog` 将现有三集本地媒体的相同元数据作为 API 响应，实际 UI 从搜索结果进入播放器；`--stage-catalog-edge-cases` 在原目录样本内构造 21／24 部分加载、真实第 0 集及两个同集数不同 id 的第 12 集。专属记录身份与隔离边界不变；没有修改生产代码、网络设置或真实 App 数据。

### 初次失败与同构建复跑

`/tmp/ZenPlayer-mac-search-queue-r1/tests.xcresult`：**1 失败、0 通过、0 跳过，21.570 秒**，build-for-testing 成功。发送搜索 `1` 后字段实际仍为空，精确输入断言失败，尚未点击播放；不能算搜索队列失败或通过，也不能将此前输入可靠性风险关闭。

不改代码、不重编译，使用同一 App／UI 二进制执行：

```sh
xcodebuild -project /tmp/ZenPlayer-mac-search-queue-r1/project/ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' -derivedDataPath /tmp/ZenPlayer-mac-search-queue-r1/derived-data -parallel-testing-enabled NO -collect-test-diagnostics never -clonedSourcePackagesDirPath /tmp/ZenPlayer-M0-mac/SourcePackages -only-testing:StageUITests/StageUITests/testFilteredEpisodeNaturallyAdvancesThroughFullSeries -resultBundlePath /tmp/ZenPlayer-mac-search-queue-r1/retry.xcresult test-without-building
```

该复跑 **1 通过、0 失败、0 跳过，43.503 秒**。真实筛选只剩 1，点击进入完整页并返回仍保留筛选；真实 AVPlayer 自然 1→2，第二集在列表仍被隐藏、第一集显示已听完；暂停后清词保留暂停，手动下一集到 5 且末集下一按钮禁用。此时第 2 集不是用户点击切入，也没有伪造结束通知或 seek。首次输入失败未复现不等于根因已解决，XCTest 事件合成／真实快速输入边界继续保留。

### 最终完整回归

`/tmp/ZenPlayer-mac-search-integration-final/tests.xcresult`：**10 通过、0 失败、0 跳过，439.518 秒**。其中搜索入口连播 44.498 秒，目录边界 43.991 秒；包含原有全部八项的本次重新运行。临时 App／UI target build-for-testing、签名／sandbox 检查和 test-without-building 均 exit 0，日志及构建结果与测试结果同目录。

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-search-integration-final --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages
```

复跑须使用新的 output；可用 `--only-testing testFilteredEpisodeNaturallyAdvancesThroughFullSeries` 或 `--only-testing testPartialCatalogAndDuplicateOrZeroEpisodeLocation` 单独执行新增路径。默认跳集仍为 0012，旧搜索采用逐键核对；不能据此宣布 Unicode／连续输入问题已解决。

| 新增子断言 | 实际结果／证据 |
| --- | --- |
| AT-09 搜索行点击到自然连播 | 保留 `找到 1 集` 与首集 completed，迷你条已经是第 2 集“正在收聽”；`7B6E9760-6FCD-4EEA-BD1E-BC33B2A38C74.txt` |
| AT-26 部分加载和零结果 | 返回 21 条、totalCount 24；零命中仍显示“僅搜尋已載入內容”，清词恢复 21；自动化断言通过 |
| AT-25 重复集数 | 保留原筛选 21，两个第 12 集候选同时出现，等待选择；两个按钮均 52pt 高；`A35FA8B0-ADD6-41F0-815C-8C2A4FF1DF04.txt` |
| AT-25 按所选 id 定位 | 选第二候选后窗口内显示 `Mac 定位驗證-18、已聽完、第 12 集`，frame `(6,501,995,66)`；`075AA4A8-D8DD-4DD0-9200-642296582903.txt` |
| AT-24 已有第 0 集 | 实际定位 `Mac 定位驗證-1、未收聽、第 0 集`，frame `(6,441,995,66)`；`BA92FA3B-389A-477C-B9C4-C003F32A2C56.txt` |
| 定位不写长期进度 | 无活动播放，正常退出后只读启动比较两条专属进度文件与原始字节，位置、状态、修订和收听时间均未改变 |

表中文件均位于 `/tmp/ZenPlayer-mac-search-integration-final-attachments/`，已导出并复核窗口树。这是实际 UI／几何证据，非 VoiceOver 朗读、截图目视或约两秒高亮时序测量。

Review 没有发现需要修改生产实现的新缺陷；新增逻辑均在临时验证夹具／测试中。检查目录响应与本地 WAV 使用相同 EpisodeItem 元数据，所有变体须显式启动参数启用，原有测试起点保持原语义。最终 80 个 Swift／Python／xcstrings 文件及工程 hash 与运行输入一致；116 个生产文件及工程 hash 相对上一轮未变，两平台各 86 项测试／App 构建证据**复用、未重跑**。构建仍有既有 RNNoise 整数精度和 AppIntents 提示，测试结果含两条内部 QoS 警告；不将它们解释成已测的端到端性能。

设备复查：`/tmp/ZenPlayer-device-search-review.json` 显示用户 iPhone 16 Pro 已连接／配对但 Developer Mode Disabled，工具明确未能取得完整信息，没有安装或修改设备。本轮不关闭首次输入丢失、Unicode／连续输入、两秒高亮、VoiceOver／Reduce Motion、真实 iPhone 后台／锁屏／PiP、参考机性能、无候选 UI、真实下载／分享／音效及迁移过程等门槛。3.2 仍未勾选，M0～M4 仍 In Verification，不建议 Done。

本地交付标题：`补充搜索入口连播与目录边界 UI 回归`。只提交当前 Harness／文档改动，不 push／PR／sync／archive／发布；提交身份以 `git log -1 --format='%H%n%B' --grep='^补充搜索入口连播与目录边界 UI 回归$'` 查询。

交付检查：M2／M4 两个 change strict 校验通过；相关 9 个相对文件链接（不含锚点）、最终源文件 hash、Git diff／暂存范围检查通过。无新文件或生产工程改动，Roadmap 阶段状态未变化。
