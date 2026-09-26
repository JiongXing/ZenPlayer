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
