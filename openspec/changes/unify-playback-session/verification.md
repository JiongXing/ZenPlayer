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
