# 播放页讲集与播放列表验证

2026-09-26：用户明确回复“实施”，本轮使用 `openspec-apply-change` 执行。起点 `main @ e596ff3`；保留已有首页优化及其文档、资源和 L10n 改动。无提交、推送、主规格同步或归档。

## 实现范围

- `PlayerView` 添加「講集與播放列表」按钮和可关闭面板（iOS sheet／macOS popover），关闭后以 `SeriesDestination` 进入详情；沿用当前会话和首次选择保护。
- `PlayerPlaylistView` 读取当前队列，显示讲集、详情入口、已加载范围与单集行；首次展开／快照恢复定位当前行，自然切集只更新标记，停止会话收起。
- `PlayerViewModel.playEpisode` 以快照标识与单集身份核对目标，复用原队列与既有准备／保存流程；当前集点击无操作。
- 新增五条繁体文案、两项隔离集成用例及 macOS UI 用例。没有修改数据格式、播放所有权、下载、远端接口或工程设置。

## 已完成检查

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| macOS App 构建及 XCTest | 88 项，0 失败 | `/tmp/ZenPlayer-player-playlist/mac-tests-r2.xcresult`、同名 `.log` |
| iOS Simulator App 构建及 XCTest | 88 项，0 失败；iPhone 17／iOS 27.0 | `/tmp/ZenPlayer-player-playlist/ios-tests-r2.xcresult`、同名 `.log` |
| macOS 选集／详情往返 UI | 1 项通过；同集保持暂停、1→5 跳选、末集边界、详情及返回保持第 5 集暂停 | `/tmp/ZenPlayer-player-playlist-mac-ui/tests.xcresult` |
| iOS 主流程及自然连播 UI | 2 项通过；选集／详情往返保持状态，面板打开时自然 1→2 更新标记 | `/tmp/ZenPlayer-player-playlist-ios-ui/tests.xcresult` |
| iOS 无关联／部分长列表 UI | 1 项通过；无关联不提供详情，21 条部分队列首次显示当前第 12 集 | `/tmp/ZenPlayer-player-playlist-ios-ui/boundaries.xcresult` |

构建与自动化命令：`xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' -derivedDataPath /tmp/ZenPlayer-M0-mac -resultBundlePath /tmp/ZenPlayer-player-playlist/mac-tests-r2.xcresult test`；iOS 替换目的地为 `platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425`，derivedData 为 `/tmp/ZenPlayer-M0-ios`，结果路径为上述 `ios-tests-r2.xcresult`。原要求的 iPhone 16 不在现有可用目的地中，实际目的地清单保存在 `/tmp/ZenPlayer-player-playlist/destinations.log`。

88 项包括新增的任意跳选保存旧位置／恢复目标进度、同集暂停不重建、旧快照／不存在单集／停止后点击无操作，以及既有队列自然结束、源切换、失败重试、进度和目录测试。未因 UI 测试源码调整而重复执行未变化的生产自动化。

## UI 隔离及截图

macOS 使用现有 `scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-player-playlist-mac-ui --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages --only-testing testPlayerPlaylistJumpAndSeriesRoundTrip`。后续将当前 `MacStageUITests.swift` 复制到该临时工程，定向执行 `testPlayerPlaylistMissingMetadataPartialListAndLiveHighlight`；所有测试使用独立 `com.jxing.ZenPlayer.MacStageValidation`，本地静音媒体和精确 URL 的目录响应，不访问生产容器。

iOS 使用现有 `run-stage-ui-tests.py` 的 `prepare_project` 生成临时工程 `/tmp/ZenPlayer-player-playlist-ios-ui/project`，独立 bundle 为 `com.jxing.ZenPlayer.StageValidation`。只在临时副本中将既有 `MacQueueFixture`／`MacCatalogFixture` 适配到该 bundle 和 iOS 下载相对路径，在 App 初始化前播种专属记录，注入精确系列 URL 的响应。UI 用例源码保存在该目录的 `StageUITests/StageUITests.swift`。不修改生产 APIService 或 App 初始化，不伪造播放结束通知；部分列表用例的远端媒体 `.invalid` 失败是预期样本，不是正常播放通过证据。

截图已导出并目视检查：

- 面板与自然连播标记：`/tmp/ZenPlayer-player-playlist-ios-ui/images/E8FCBEAA-F955-4B58-AF74-F0C301E70675.png`。
- 当前集／详情／返回截图在同目录，映射见 `manifest.json`。
- 21 条部分队列中第 12 集居中可见：`/tmp/ZenPlayer-player-playlist-ios-ui/boundary-images/507443D4-6E5B-4391-A0D8-33AAC4E154D2.png`。
- 缺失讲集信息：`/tmp/ZenPlayer-player-playlist-ios-ui/boundary-images/1C22127E-D615-4E4A-A23B-50C0BB714364.png`。

macOS 沿用窗口可访问性树附件作为 UI 操作证据；未声称完成 macOS 截图视觉验收。iOS 截图实际为半屏面板，列表可滚动；不将测试中的滑动手势当作已完成全屏展开证明。

## 修复与限制

首次两端 test 因新增断言误用 `PlaybackProgress.position` 编译失败，改为真实字段 `positionSeconds` 后均通过；App 行为没有因此调整。首次 macOS 补充用例使用了 iOS 夹具 ID `900001`，修正为 Mac 实际 ID `900002`。失败日志／结果均保留。

本轮没有运行真实 iPhone 后台、锁屏、PiP 或真实媒体听感；模拟器和静音夹具不能替代这些证据。没有改变这些生命周期实现，M0～M4 的既有设备验收缺口保持原状。未安装或启动生产 App 到真实设备；不修改其数据容器。

macOS 补充用例进一步发现 sheet 会暂停播放器。临时 `PlaylistTracePlayer` 调用栈确认 `AVPlayerView.windowWillBeginSheet:` → `AVPlayerController.setPlaying:` → `rate=0`。保持 isEnabled 以及原生 AVPlayerView 承载均未解决，诊断结果保存在 `boundaries-r2/r3/r4.xcresult`、`native-surface.xcresult`、`trace-r2.xcresult`。最终采用按钮锚定的 macOS popover，保留原 VideoPlayer，不加入恢复播放计时器、状态标记或原生承载层；诊断 subclass 仅存在临时副本，生产 PlayerViewModel 使用原 AVPlayer。最终 macOS `popover.xcresult` 两项 UI 用例全部通过，57.078 秒；保持播放打开面板后，自然从第 1 集进入第 2 集并更新标记。新面板的 macOS 关闭、跳选、暂停往返、无关联和长列表子断言均通过。iOS 最终 `final.xcresult` 3 项 UI 用例全部通过；最终两端生产构建均为 BUILD SUCCEEDED。


## 收尾状态

- 任务 1.1、2.1、2.2 完成；3.1 的两端构建／自动化／UI／规格和范围检查已执行，真实 iPhone 后台、锁屏、PiP 未运行，因此该整体任务保持未勾选。本变更功能已实现，不宣称完成设备或发布验收；Roadmap 的已有里程碑状态不变。
- macOS UI 最终结果：`/tmp/ZenPlayer-player-playlist-mac-ui/popover.xcresult`，2 项、0 失败。临时诊断承载层及播放器 subclass 未被最终视图／业务代码引用；生产仓库没有这些诊断文件。
- 最终生产构建日志：`/tmp/ZenPlayer-player-playlist/mac-build-delivery.log`、`ios-build-delivery.log`。测试后没有继续改动生产代码。
- 新增文件单独审查；`git diff --check`、OpenSpec 严格校验、xcstrings JSON 与新增本地链接检查通过。暂存区为空；未提交／推送。
- `/tmp/ZenPlayer-player-playlist/baseline.json` 记录了本轮开始前文件哈希；范围审计确认此前已有首页 Swift、颜色资源、ContentView 和其他 change 文档字节未变。L10n 文件只追加本功能五个 key，保留首页文案。

- iOS 最终 UI：`/tmp/ZenPlayer-player-playlist-ios-ui/final.xcresult`，3 项、0 失败，涵盖跳选和详情往返、自然连播标记、缺关联及 21 条部分列表首次定位。临时测试工程中的生产文件已与最终源码逐文件哈希比较；差异仅为已说明的夹具初始化／网络／隔离存储注入，结果保存于 `/tmp/ZenPlayer-player-playlist/final-source-audit.json`。
- 用户允许在弹层成本高时改为新页面；当前采用原生 sheet／popover 即满足要求，最终未保留任何诊断播放器、额外播放状态或重试逻辑。无需切换成新页面方案。

## Review 与本地提交

2026-09-26：用户随后授权“review 并提交”。本轮审查选集身份校验、进度保存调用链、弹层关闭与详情导航、当前会话观察、繁体文案及新增测试，未发现阻断提交的问题。

- 复核 120 个生产文件的 SHA-256，均与最终验证审计一致；复用上述两端各 88 项 XCTest、macOS 2 项／iOS 3 项 UI 测试及最终构建证据，不重复执行未变化代码的构建与测试。
- 重新执行 OpenSpec 严格校验、差异空白检查，并核对新增文件和暂存范围；共享 L10n 文件仅暂存播放列表的五个 key。
- 本地提交范围限于播放列表实现、文案、测试和本 change；既有首页优化、资源、首页文案及其他 change 保留在工作区。上文“未提交”是实施收尾时的历史状态；本轮按授权创建本地提交，不推送、不同步主规格或归档。
- 真实 iPhone 后台、锁屏、PiP 及真实媒体听感未验证，任务 3.1 保持未勾选。
- iOS 最终 UI 结果另含三条 AVAudioSession 主线程同步激活可能影响响应性的运行时提示；测试无失败，本次未修改音频会话激活路径，也不将其表述为无运行时告警。
