# M2 验证记录

状态：In Verification。基线 main @ b3e35b8，开始时工作区干净。授权来自持续目标：M1～M4 顺序实施、review／修复及本地提交；不 push／PR／发布／同步／归档。

PRD：F1-05～F1-07、D-01／D-02、Q-01／Q-02／Q-04。追踪 S1～S7 与 tasks.md；M0／M1 真机及 UI 缺口继续保留。

所有新测试、两端构建、实际设备／UI 验收初始均未运行。AT-09 先验证未筛选快照与可见列表独立，M4 加入实际搜索后重验；AT-12 锁屏／PiP 自动切集不能用纯模型测试替代。

1.1 通过：`/tmp/ZenPlayer-M2-queue.xcresult`，macOS App 编译及 42 项隔离测试通过、0 失败；新增 5 项队列测试。日志同前缀 .log。尚未接入实际队列自动推进／UI，不构成设备验收。

1.2 通过：`/tmp/ZenPlayer-M2-store.xcresult`（同前缀 .log），macOS App 编译及 46 测试、0 失败；新增 4 项隔离存储测试验证重启／偏好、损坏未知版本不删除、写失败内存保留及可重试、跨系列歧义不误关联。

## 阶段 review 与交付证据

2.1／2.2 通过：系列行传递未筛选快照的引用；历史／下载沿用原 PlaybackContext 入口，在 PlayerViewModel 内恢复引用或按原键查保存的快照。冷启动不自动播放；设置开关不调用暂停。结束事件先保存 completed，再根据队列与偏好选择下一项；失败和 seek 不调用自动前进。手动前后切集使用新指令并保留当前媒体类型，降噪与音量设置在同一模型保留。

为直接验证上述行为，给真实 PlayerViewModel 注入隔离存储／UserDefaults、本地文件查找、网络状态及音频处理控制面；生产 convenience init 仍使用原 DownloadManager、标准偏好和 RNNoise 处理器，算法只增加协议声明，没有改算法。独立测试 target 编译真实 PlayerViewModel，用临时静音 WAV 和真实 AVPlayer；不启动生产 App、不读写真实 App 数据。

### 最终通过

- macOS：`/tmp/ZenPlayer-M2-final-mac.xcresult`，App 构建及 **58 项测试，0 失败**；日志 `/tmp/ZenPlayer-M2-final-mac.log`。
- iPhone 17 / iOS 27 模拟器：`/tmp/ZenPlayer-M2-final-ios.xcresult`，App 构建及 **58 项测试，0 失败**；日志 `/tmp/ZenPlayer-M2-final-ios.log`。
- 其中 M0／M1 37 项回归，M2 新增 21 项：6 项队列／兼容、6 项存储／关联、2 项媒体策略、7 项真实 PlayerViewModel 集成。
- 集成验证：1／2／5 自然切集及重复通知；关闭连播后结束且重开开关不重启；B 延迟完成不能覆盖 C，同集重复选择保留暂停播放器；暂停切源保留即时 1.25 秒位置及队列；离线替代与处理器失败原声回退；下一集损坏不覆盖其 2 秒旧进度、前集仍 completed，修复后手动重试恢复；快照加载未结束时本集已经 ready，迟到快照不能改新目标。
- `OPENSPEC_TELEMETRY=0 openspec validate play-series-in-order --strict --no-interactive`、本地化键对应、Markdown 链接及 Git diff 检查通过。

实际命令：

```sh
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' -derivedDataPath /tmp/ZenPlayer-M0-mac -resultBundlePath /tmp/ZenPlayer-M2-final-mac.xcresult test
xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' -derivedDataPath /tmp/ZenPlayer-M0-ios -resultBundlePath /tmp/ZenPlayer-M2-final-ios.xcresult test
```

代表性只读 API 样本：系列 2988 为 289／289 集，系列 2992 为 9／9 集；各自 id 唯一、两样本原键无交集，前六集顺序均 1～6。日志 `/tmp/ZenPlayer-M2-api-sample.log`。这不是全库身份唯一性证明；跨系列歧义保护仍保留。

### Review 修复与失败记录

- P1：可选系列字段解码损坏可能牵连有效进度 → 可选关联容错，基础单集身份仍严格解码；旧入口无关联时保留已有关联，新增测试通过。
- P1：队列异步恢复可能在 prepare await 期间关联成功又被旧局部上下文覆盖 → 媒体提交时采用当前关联，恢复另有选择版本校验；真实迟到快照测试通过。
- P1：结束通知排队后才恢复的队列可能事后开播 → 事件到达时捕获队列修订；仍记录本集 completed，修订变化则不自动前进。
- P2：不可变快照在每次切集重复写／浏览即写目录 → 区分内存 cache 和播放 register，成功版本去重；测试确认浏览零写入、重复选择一次写入。
- P2：选择后、异步准备任务启动前 isPreparingPlayback 为 false → 选择时同步置位；补上真实播放器就绪断言。
- 初次集成测试构建失败：`/tmp/ZenPlayer-M2-player-mac.xcresult`，测试夹具默认工厂在非隔离默认参数中调用 MainActor 初始化器；改为可选工厂并在隔离函数内部构造。
- 后续两端集成各 56 项有 1 项失败：mac `player-mac-r2`／iOS `player-ios`（均为 `/tmp/ZenPlayer-M2-*.xcresult`），迟到准备测试过早将准备标志空窗中的 nil 当已就绪播放器；修复同步标志并明确等待真实 ready 状态后，两端各 56 项通过（mac `player-mac-r3`／iOS `player-ios-r2`）。再新增损坏重试和迟到快照测试，最终各 58 项通过。
- 构建仍提示无 AppIntents 依赖而跳过元数据提取；模拟器有 AVFoundation 平台诊断输出，未造成最终断言失败。没有调整部署／签名／版本／依赖来获取通过。

### 未运行／风险

AT-07～AT-10／AT-12 的真实界面点击、锁屏自动换集、PiP／全屏、硬件断网／耳机／来电及 macOS 多窗口流程未运行。离线证据是注入网络状态与临时文件，非实际网络切换；下载文件查找的生产绑定已编译并走读，未执行真实下载／删除／分享／降噪听感回归。完整页上一／下一集、开关、长标题／大字体、VoiceOver 与安全区未做截图或 UI 自动化验证。AT-09 的实际搜索过滤留 M4 重验；M0／M1 未验项没有关闭。

剩余风险：真实媒体／网络与平台回调顺序、完整页控制布局、快照样本覆盖不足。保持 In Verification，当前 5/6 项，不建议 Done。临时日志／xcresult 可能被系统清理，不作为永久归档。

本地提交标题：`实现 M2 系列顺序连播与快照恢复`；本文件所属提交即交付版本，可用 `git log -1 --format='%H%n%B' --grep='^实现 M2 系列顺序连播与快照恢复$'` 查询。无 push／PR／发布／同步／归档。下一阶段推荐 M3 首页与系列续听，按持续目标继续实施；设备验收缺口在后续总验收继续追踪。


## 2026-09-26 Mac 实际连播与偏好回归

本轮基线 `main @ 1bf59f9`，开始时工作区干净。继续 3.2 的真实界面子断言，并联调 M3 完成后的首页候选；不改产品算法、签名、部署、依赖或主规格。

新增 `ZenPlayerUITests/MacQueueFixture.swift`，仅由 Mac UI 脚本复制进独立 bundle `com.jxing.ZenPlayer.MacStageValidation`。fixture 在播放器创建前播种专属 1／2／5 三集完整快照、10／120／15 秒静音 WAV、完成下载索引及进度（第一集 1 秒、第二集 7 秒）。远端使用 `.invalid`，实际由 DownloadManager 找到本地文件；不用 mock 播放器或主动发送结束通知。只覆盖本样本的三个记录及固定快照版本，不清空其他记录／下载；只调整本验证 App 的连播偏好。

`--stage-verify-queue`／`--stage-verify-queue-off` 在重启时只读核验实际磁盘记录、关联快照及关闭偏好。前者要求第一／末集 completed、中间集至少 7 秒；后者要求第一集 completed、第二集至少 7 秒、最后一集仍 notStarted。断言失败直接使验证 App 启动失败，不能靠重新播种掩盖保存问题。

### 首轮失败与 review 修正

- `/tmp/ZenPlayer-mac-queue-r1/tests.xcresult`：0 通过、1 失败。真实首集已自然进入第二集并恢复位置，但将 Mac CheckBox 的 NSNumber 值按 String 读取，后续动作未执行。修正为数值断言。
- `/tmp/ZenPlayer-mac-queue-r2/tests.xcresult`：0 通过、1 失败。实际关闭值已变为 0，但测试误用迷你条的 `pause.fill` 图标标识查询完整页按钮；完整页使用文字“播放／暫停”。按真实控件修正，并增强既有完整页暂停断言，要求“播放”存在、“暫停”不存在，避免永不存在的图标查询给出虚假通过。
- 为排除仅看按钮的间接证据，最终用例还检查关闭连播后实际媒体位置继续推进，并要求在末集仍播放时开启连播再观察自然结束。


### 最终结果

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| 完整 Mac UI 套件 | **6 项、0 失败、0 跳过，273.553 秒** | `/tmp/ZenPlayer-mac-queue-r3/tests.xcresult`、`test.log` |
| 加强后的连播定向回归 | **1 项、0 失败、0 跳过，60.011 秒** | `/tmp/ZenPlayer-mac-queue-final/tests.xcresult`、`test.log` |
| 临时 App／UI 构建和隔离检查 | 两轮 build-for-testing／test-without-building 均 exit 0，签名／sandbox 校验通过 | 两目录 `build.xcresult`、`build.log`、`entitlements.plist` |
| 生产源码回归 | 复用此前两端各 86 项 XCTest／App 编译通过证据；本轮未重跑 | `/tmp/ZenPlayer-avkit-review-{mac,ios}.xcresult`，App 源码／工程未变 |

最后只为连播用例加入“关闭开关后真实媒体时间继续推进”及“末集仍播放时重新开启连播”两个加强条件，因此定向重跑该用例；其余五项及全部 helper 与完整通过轮次逐字相同。不能把 6+1 次执行算作 7 个独立场景。最新 78 个 Swift／Python／xcstrings 输入及工程 SHA-256 与待提交内容一致。

已通过的实际子断言：本地首集自然结束进入第二集；第二集恢复自己的至少 7 秒进度；默认连播开启；关闭连播不立即暂停且媒体时间继续增加；手动下一集沿真实 1／2／5 顺序进入 5；连播开启时末集完成停留、不回第一集；首尾按钮禁用；关闭偏好在退出／冷启动后保留；已完成第一集经手动上一集从头重听。冷启动只读文件断言还证明前／末集完成、中间集进度和同一快照关联持久化成功。

另一个用例证明关闭连播时首集自然结束不推进，首页正确展示下一集自己的 7 秒并单击续听；停止／重启后第 2 集位置保留，第 5 集仍 notStarted。M3 记录见 [首页下一集 UI](../surface-listening-progress/verification.md#2026-09-26-mac-完成后的首页接续)。

已导出并核对 `/tmp/ZenPlayer-mac-queue-r3-attachments/` 中窗口树：首页下一集为 `已聽 0:07 / 2:00`；完整页关闭开关 value 0 且“暫停”按钮存在；末集“已聽完”、开关 value 1、“下一集” Disabled；冷启动首页回退到未完成第二集。这里是窗口树／断言证据，不是实际音质或截图目视验收。

复现完整套件：

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-queue-r3 --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages
```

定向加强用例在另一新 output 上增加 `--only-testing testNaturalQueueAdvanceControlsAndColdPreference`。重跑时必须使用尚不存在的 output；临时日志可能被系统清理。

设备复查 `/tmp/ZenPlayer-device-queue-review.json`：已配对 iPhone 16 Pro 已连接，Developer Mode 仍 Disabled，devicectl 明确只能返回不完整设备信息。没有安装或更改真实设备。仍未验证：真实音视频听感、iPhone 锁屏／PiP／后台自动换集、真实网络断开和类型回退、搜索过滤后从实际系列行进入队列，以及下载传输／分享／降噪／音量等回归。本轮无生产代码缺陷修复；原 Unicode 事件合成和连续输入风险也未关闭。

任务 3.2 继续未勾选，M2 仍 5/6、In Verification。交付标题 `补充 Mac 连播与首页下一集实际回归`；仅本地提交，不 push／PR／主规格同步／归档／发布。

## 2026-09-26 搜索结果携带完整队列

本轮基线 `b56de9a`。M4 新增实际 Mac UI 用例 `testFilteredEpisodeNaturallyAdvancesThroughFullSeries`：历史返回真实系列页，输入 `1` 后只显示首集，点击该行进入播放；返回仍保留 `1` 筛选，10 秒本地 WAV 自然完成后进入隐藏的第 2 集，首集显示已听完。暂停、清词后仍是同一暂停会话，手动下一集到实际第 5 集，末集下一按钮禁用。证明真实搜索行入口传入完整 1／2／5；没有将手动 2→5 算自然连播。

样本复用三个既有专属原键／本地文件，媒体和注入目录响应来自同一份 EpisodeItem 数组；启动参数 `--stage-queue-catalog` 仅控制独立验证 App 的精确目录请求。生产队列／会话代码、原键和格式未变。

首轮 `/tmp/ZenPlayer-mac-search-queue-r1/tests.xcresult` 发送 `1` 后文本仍为空，测试在点击播放前失败；同一构建不改代码复跑 `retry.xcresult` **1 通过、0 失败、0 跳过，43.503 秒**。首次输入事件失败仍保留，不归因于队列且不宣称已解决输入可靠性。最终全套结果和复现命令见 [M4 本轮记录](../search-loaded-catalog/verification.md#2026-09-26-搜索入口连播与目录边界)。

最终 `/tmp/ZenPlayer-mac-search-integration-final/tests.xcresult` 完整 **10 通过、0 失败、0 跳过，439.518 秒**；搜索连播在此轮再次通过（44.498 秒），原有两项队列／首页用例也重跑通过。构建、签名／sandbox 和测试命令均 exit 0；生产源码／工程未变，两端各 86 项既有证据复用。本地提交标题 `补充搜索入口连播与目录边界 UI 回归`。

本轮重新查询用户 iPhone 16 Pro，Developer Mode 仍 Disabled，命令明确无法返回完整信息（`/tmp/ZenPlayer-device-search-review.json`）；没有安装或改变真实设备。AT-09 的上述 Mac 本地样本子断言已获得证据，真实音视频／iPhone 生命周期、网络回退、VoiceOver／Reduce Motion、端到端性能和旧能力仍未齐备。3.2 保持未勾选，M2 仍 In Verification。

交付检查通过：M1／M2／M3／M4 四个 change strict 校验、Python AST／CLI help、14 个相对 Markdown 文件链接（不含锚点）、已跟踪差异与新增 fixture 行尾检查。Git 范围为 12 个测试 Harness／说明和现有 change 记录；116 个生产 App 文件与工程 hash 均未变化。
