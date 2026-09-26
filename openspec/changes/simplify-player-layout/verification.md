# 播放页简约设计记录

## 本轮：截图与提案

2026-09-26，基线 `main @ 8eec75e`。用户反馈真机播放页杂乱，要求简约设计并明确列表纯图标、移除常驻重复播放与停止按钮。

- `xcrun devicectl list devices` 发现已连接 iPhone 11。
- `xcrun devicectl device capture screenshot --device 00008030-001A4D1601A1802E --destination /tmp/ZenPlayer-player-minimal/iphone-before.png --timeout 25` 成功，尺寸 828 × 1792；已目视检查，确为当前 App 播放页，暂停在 21:06。
- 通过 CodeGraph 检查 `PlayerView`、`PlaybackQueueControls`、原生容器、迷你条及选集调用关系；核对 PRD 的控制一致性、连播、失败重试和辅助功能要求。
- 设计预览：`/tmp/ZenPlayer-player-minimal/design-preview.png`；前后对照：`/tmp/ZenPlayer-player-minimal/comparison.png`。使用真实截图的标题／系统播放器区域进行布局合成并绘制其余控件，已目视检查；右侧明确标为设计预览，非新版本运行结果。
- 本轮创建 proposal、specs、design、tasks；不修改 App 代码、已有 change 或首页工作区改动。所有实施任务未勾选，未构建／测试／安装 App，未提交或推送。真机截图不代表播放生命周期验收。
- `OPENSPEC_TELEMETRY=0 openspec validate simplify-player-layout --strict --no-interactive` 通过；规划产物 4/4 齐全。`git diff --check`、新增文件空白／本地链接检查通过。规划完整不等于实施完成。

## 实施与验证

用户随后回复“实施”，本轮使用 `openspec-apply-change`。起点仍为 `main @ 8eec75e`，已有首页改动的文件哈希保存在 `/tmp/ZenPlayer-player-minimal/baseline.json`。

### 实际改动

- `PlayerView` 精简为标题、原生播放器、图标选集、单色媒体切换和折叠设置；更多菜单保留停止。正常播放／暂停文字及重复按钮移除；加载、完成、失败与重试仍明确显示。使用系统自适应背景，macOS 限制正文宽度。
- `PlaybackQueueControls` 接收原有列表按钮，前后按钮保持边界禁用及 44pt 热区；正常完整列表数量移至列表面板，缺失／部分和保存错误继续在主页面显示。
- `PlayerSettingsView` 复用原有模型绑定；默认收起，摘要显示当前档位。局部 DisclosureGroupStyle 提供整行点击、右箭头和展开状态读屏说明，档位网格随动态字体换行。四条新繁体 L10n 保留已有首页文案。
- 更新受影响的 Mac／iOS UI 定位方式，新增 Mac 设置／原生控制用例。未修改播放器服务、播放所有权、快照／进度存储、下载、生产工程设置或签名。

### 检查与证据

以下路径相对于 `/tmp/ZenPlayer-player-minimal/`。

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| macOS 构建与 XCTest | 88 项，0 失败 | `mac-tests.xcresult`、`mac-tests.log` |
| iOS Simulator 构建与 XCTest | 88 项，0 失败；iPhone 17／iOS 27.0 | `ios-tests.xcresult`、`ios-tests.log` |
| Mac 列表跳选与详情往返 | 1 项通过 | `mac-ui/main.xcresult` 中 `testPlayerPlaylistJumpAndSeriesRoundTrip`；同批设置旧定位失败记录保留 |
| Mac 原生控制／设置／停止及列表边界 | 2 项通过 | `mac-ui/settings-r4.xcresult`；含无关联、部分长列表和面板打开期间自然切集 |
| iOS 列表自然连播 | 1 项通过 | `ios-ui/main-r2.xcresult` 中 `testPlaylistFollowsNaturalAdvance`；同批旧原生 label 判断失败记录保留 |
| iOS 选集详情往返／设置停止／无关联长列表／错误重试 | 4 项通过 | `ios-ui/main-r3.xcresult` |
| iOS 折叠时保存失败可见 | 1 项通过 | `ios-ui/save-error.xcresult` |
| iOS 深色及最大辅助字体 | 1 项通过，档位换行、末档可滚动操作 | `ios-ui/visual.xcresult`、`visual-settings.json`、`visual-images/` |
| iPhone 11 真机 | 1 项完整流程通过，另有前置 1 项通过；iOS 18.6.2 | `device-ui/media.xcresult`、前置 `device-ui/tests.xcresult` |

生产检查命令为 `xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination <目的地> -derivedDataPath <目录> -resultBundlePath <结果> test`。macOS 目的地 `platform=macOS`，目录 `/tmp/ZenPlayer-M0-mac`；模拟器目的地 `platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425`，目录 `/tmp/ZenPlayer-M0-ios`。本次继续使用现有 iPhone 17，不修改部署版本来适配不存在的 iPhone 16。

### 真机与隔离边界

真机使用当前源码的临时工程副本，App bundle 仍为 `com.dunkong.zenplayer`，按原签名配置构建安装；只为独立 UI runner 配置同团队自动签名，生产工程签名未变。未向真实数据容器播种或修改文件。实际从首页继续用户的现有单集，原生暂停后展开／收起设置、打开／关闭列表，再切换视频并返回音频，核对暂停及时间标签不变；未更改用户音效和连播偏好。实际试播约数秒并按正常播放路径保存进度，最后保留暂停。

真机原图：`device-ui/media-images/6D8A861A-56FC-4975-B0A7-3E6F7A774633.png`；视频：`6A9EB938-B797-41F4-84DE-17CBBE19CAF2.png`；音频返回：`CB7E78C3-A2F2-4EE5-9BA0-B77C060F87B5.png`。这些是运行截图，均已目视检查，区别于上一轮设计合成图。

Mac／模拟器 UI 复用上一轮独立验证工程和夹具，刷新本次生产视图／文案／业务源文件；bundle 分别为 `com.jxing.ZenPlayer.MacStageValidation`／`com.jxing.ZenPlayer.StageValidation`。Mac 最终用例源码与仓库对应；iOS 临时用例保存在 `ios-ui/project/StageUITests/StageUITests.swift`。Mac 的窗口截图也已目视检查，见 `mac-ui/final-images/08EB970A-851B-473E-B798-3E9F60650C60.png`。

iOS 临时夹具追加三个限定 flag：交互测试将首／末静音样本延长，避免原 10 秒 WAV 在原生控件查询期间自然切集，专门连播用例仍用原 10 秒；坏媒体样本写入无效内容验证失败与重试；保存失败使用现有 writer 闭包注入拒绝写入并触发真实 flush 错误。后两者验证 UI 恢复入口和提示，不是实际网络／磁盘故障发生率证明。原来提案所述“持有失败播放器”在当前实现不可达：`failPlayback` 会释放播放器，所以核对释放路径并验证真实媒体错误后的失败页，不新增测试专用播放状态。连播偏好本身使用同步 UserDefaults，无独立保存错误接口；验证的是既有队列快照保存错误提示。

大字体／深色仅临时调整测试模拟器，`finally` 已恢复原来的 `light`／`large`。没有修改用户真机的外观与字体设置。

### 修复过程与限制

- 首轮设置测试发现 DisclosureGroup 的分组标识传播到子控件、macOS 元素类型与 iOS 不同；最终标识只放在整行按钮，Mac 按标识查元素，子开关可独立访问。
- iOS 27 原生 `Play/Pause` 新建时可能短暂无 label，原测试把空 label 误当暂停；调整测试明确执行所需原生动作并等待对应状态。生产代码没有为测试增加播放按钮、计时器或自动恢复。
- 原始失败／诊断结果保留，最终通过证据按用例列出，不把含失败的整批结果称作全通过。
- 本次已验证真机前台控制与切源，未重新运行后台、锁屏、PiP、系统中断或完整 VoiceOver 操作验收，原里程碑缺口继续保留。大字／深色和 iPhone 11 长标题截图不代表所有设备组合通过。
- 未提交、推送、同步主规格、归档或调整 Roadmap 阶段。当前授权范围为简约页面实施与验证。

### 最终范围审查

- OpenSpec 严格校验、`git diff --check`、新增文件空白和 Markdown 本地链接检查通过；审阅本次源文件及测试差异，未发现阻塞问题。
- 对比实施前哈希，14 个独立的首页／既有进度文档文件完全保留；共享本地化文件仅在既有首页文案之外增加四个播放设置键，原有翻译未变。记录：`/tmp/ZenPlayer-player-minimal/final-scope-audit.json`。暂存区为空。
- 真机、Mac 和模拟器验证副本中的本次视图及本地化与当前源码一致，仅 `PlayerView` 的失败路径注释在验证后纠正，无可执行代码差异。
- Mac UI 文件另更新了首页测试的“未进入完整页”断言，以列表入口代替已移入菜单的停止按钮；该首页用例未在本轮重跑。上表仅报告实际运行的定向 UI 用例，不表示整套历史 UI 全量通过。
