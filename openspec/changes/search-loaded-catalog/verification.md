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
| 01 | App 唯一会话注入和页面不停止的调用链 | 真实返回、切 Tab、浏览后重进，声音连续／无重复加载 |
| 02 | 状态与真实 PlayerViewModel 同键复用、暂停保持 | 收起／打开完整页与重复点击的实际 UI |
| 03 | 三处控制绑定同一模型，媒体 token 隔离 | 迷你／完整／锁屏交替控制及信息同步 |
| 04 | stop 状态、冷启动仅本地候选、直接续听接口 | 停止后系统信息清理、实际冷启动不出声及首页点击 |
| 05 | 真实 B 延迟不能覆盖 C，旧快照／媒体回调隔离 | 快速 UI 选择及真实网络延迟／旧进度实测 |
| 06 | 中断恢复资格、手动暂停不唤醒的状态测试 | 耳机拔出、来电、系统通知实际顺序 |
| 07 | WAV 自然结束 2→5、重复结束只推进一次 | 真机音视频系列连续播放 |
| 08 | 关闭连播、末尾不循环、设置冷读 | 开关 UI、实际 App 重启偏好 |
| 09 | **M4 联调通过**：过滤第 2 集，真实 AVPlayer 结束进入完整快照第 5 集 | 实际搜索输入／点击到连播 UI |
| 10 | 类型／离线策略、坏媒体失败保留目标、手动重试恢复位置 | 实际网络断开、下载文件与远端失败路径 |
| 11 | 暂停切源保存即时位置、失败不覆零 | 原生手势／不同真实音视频时间轴和切换失败 |
| 12 | 编译／所有权／回调门控检查 | iPhone 后台／锁屏／PiP／全屏、Mac 窗口失焦／退出 |
| 13 | 本地候选、真实一次 continue 恢复历史，无中间路由 | 冷启动首页真实点击和位置验收 |
| 14 | 本地卡在分类错误分支外；注入离线本地媒体可播 | 分类失败实景、实际下载内容离线点击 |
| 15 | 紧邻未完成下一集自身进度、无候选隐藏规则 | 首页画面随实际完成状态变化 |
| 16 | 30 条长期存储、最近 10 条、磁盘重读；行状态直接查长期仓库 | 三个真实入口、重开 App 后旧集展示／播放 |
| 17 | 即时／周期提交、seek 门控、原子写入及文件冷读 | 原生拖动／锁屏、强制终止重开、后台实际保存间隔 |
| 18 | 未知时长完成、近尾不完成、真实结束后同集重听零起点 | 真实未知时长媒体、原生拖动与重听展示 |
| 19 | **M4 定位模型通过**：搜索隐藏目标→清筛选→准确 id；删除下载不调用进度仓库（静态） | 实际滚动约 2 秒高亮／不播放；真实删除下载后进度保留 |
| 20 | 隔离 fixture／文件迁移、缺字段、幂等、失败备份及新值保护 | 测试安装升级、每中断点真实进程演练 |
| 21 | 单条损坏隔离、写失败／重试、旧文件不清空 | 真实错误提示／重试交互与设备空间受限路径 |
| 22 | 分类 title／num、排序切换／清空恢复且不再请求网络 | 当前分类 UI 输入、清除和排序操作 |
| 23 | 简繁／全半角／多词、前导零数字精确优先、原标题保持 | 实际输入法交互 |
| 24 | 12／0012／第１２集／0 真实字段解析、清筛选、重复定位身份 | 输入面板收起、滚动目标、2 秒高亮与不自动播放 |
| 25 | 非法／不存在／重复候选、用户选候选及零结果模型 | 提示可见、候选按钮可操作、一键清词实际 UI |
| 26 | 部分／未知范围、首次离线重试、上述计算 P95；局部静态明暗布局 | 真机端到端 P95／操作反馈，大字／键盘／VoiceOver／Reduce Motion／底部遮挡 |

原功能回归：分类排序已由真实 ViewModel 测试覆盖；地址／本地优先／源回退和处理器失败保留原声有策略／播放器隔离证据；下载暂停／恢复／删除、文件分享、实际 RNNoise 降噪听感、音量增强与两平台完整播放界面操作均**未运行**。处理器替身的失败测试不等于真实算法听感回归。没有静默删除这些发布门槛。

## 阻塞、风险与下一步

2026-09-26 再查 `devicectl`：用户设备 jxing's16pro（iPhone 16 Pro／iOS 26.6.2）Developer Mode 仍 disabled；没有向其安装 App，没有使用列表中其他人的手机。已请求用户开启、连接／解锁后回复。缺可操作的 iPhone 是后台／锁屏／PiP 的环境阻塞；macOS 全流程 UI 和辅助功能也尚无证据。当前独立渲染仅覆盖局部静态布局，不声称焦点／提交动作／大字通过。

固定简繁表保留未覆盖异体字，符合首版词典边界；查询不上传。仍需真实媒体时间轴和跨系列身份更广样本。临时 xcresult／日志／截图位于 `/tmp`，可能被系统清理，仓库记录结果及复现命令。

M4 保持 In Verification，3.2 未完成；M0～M3 同样保留各自设备缺口。下一步是补齐本表实机／UI、性能与旧能力验收，不创建新业务阶段，不标 Done、不发布。


## 3.1 本地交付检查

通过：5 个 change 的 `OPENSPEC_TELEMETRY=0 openspec validate --all --strict --no-interactive`；26 个修改／新增文件内容与 19 个相对链接、15 个新增繁体 key、原 catalog 值保持；工程对象对比仅变更既有测试 Sources 并增加所需引用，App／测试构建配置值均不变。`git diff --check` 通过；包括新增文件内容审查，未把未跟踪文件遗漏。

阶段提交标题：`实现 M4 页内搜索与精确集数定位`。实际 Git 身份可用 `git log -1 --format='%H%n%B' --grep='^实现 M4 页内搜索与精确集数定位$'` 查询。此前 M3 本地提交为 096307d0cf330505350cc3598dfe8798fd60dc31。本地提交只交付已实现与验证过的工程部分，不代表 3.2 完成；不 push／PR／sync／archive／发布。
