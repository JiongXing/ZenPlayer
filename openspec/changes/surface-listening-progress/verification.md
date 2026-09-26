# M3 验证记录

状态：In Verification。基线 main @ 81dc155，开始时工作区干净。持续目标授权 M1～M4 实施、review 修复和本地提交；不 push／发布／PR／主规格同步／归档。

追踪 PRD F2-01／F2-02、F3-03 联动；S1～S6、tasks.md 为当前唯一任务入口。初始测试、构建及 UI／真机项目均未运行；M0～M2 未验设备路径保留，M4 将复验搜索清筛选定位。

1.1 通过：`/tmp/ZenPlayer-M3-candidates.xcresult`，macOS App 编译及 64 项测试、0 失败，新增 6 项纯候选测试。1.2 首轮通过：`/tmp/ZenPlayer-M3-resume-model.xcresult`，67 项、0 失败；新增 3 项本地候选／快照模型测试，不使用分类 API。各日志同前缀 .log。随后补取消后重新查询同一候选的回归，最终证据另记。


## 最终自动化与代码审查（2026-09-26）

2.1／2.2 通过：两端 App 编译及真实 PlayerViewModel、纯候选／路由测试通过。`HomeView` 的本地卡位于分类加载／错误分支之外；按钮直接调用唯一 session，不经历史页面。`SeriesDetailView.locate` 只改本页定位并滚动；`RecentPlaybackListView → SeriesDestination → SeriesDetailView` 保留真实系列与 episode id。

| 检查 | 实际结果 | 证据 |
| --- | --- | --- |
| 中间集成 | 两端各 70 项，0 失败 | `/tmp/ZenPlayer-M3-integration-{mac,ios}.xcresult` 及同名前缀 `.log` |
| 最终 macOS | 71 项，0 失败，App 编译通过 | `/tmp/ZenPlayer-M3-final-mac.xcresult`、`.log` |
| 最终 iOS 模拟器 | 71 项，0 失败，App 编译通过 | `/tmp/ZenPlayer-M3-final-ios.xcresult`、`.log`；iPhone 17／iOS 27.0，id F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425 |
| OpenSpec | strict 通过 | `OPENSPEC_TELEMETRY=0 openspec validate surface-listening-progress --strict --no-interactive` |
| 本地化／差异 | 9 个新增繁体 key 完整，diff check 通过 | L10nKey 与 xcstrings 对照、Git 定向检查 |
| 静态渲染 | 360pt 首页卡明暗外观可读、长标题换行、未知时长正确 | `/tmp/ZenPlayer-M3-resume-standard.png`、`/tmp/ZenPlayer-M3-resume-large-dark.png`，隔离 ImageRenderer；不代表实际交互通过 |

运行命令：`xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=macOS' -derivedDataPath /tmp/ZenPlayer-M0-mac -resultBundlePath /tmp/ZenPlayer-M3-final-mac.xcresult test`；iOS 对应 `platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425`、`/tmp/ZenPlayer-M0-ios` 和 `/tmp/ZenPlayer-M3-final-ios.xcresult`。

新增测试共 13 项（7 候选、4 本地查询、2 实际播放器集成）。覆盖 S1～S6 的模型／控制子断言，包括长历史、紧邻下一集自身位置、旧原键关联、失败同目标重试、准备中重复操作不重建、暂停复用、真实自然结束后同集重听从零。临时目录／UserDefaults 与静音 WAV 隔离，不修改生产容器。

Review 修复：取消的快照查询不记作已成功刷新，允许回页重试；历史返回可能定位较早单集，标记由“上次收聽”改为“目前定位”；整理本次新增嵌套缩进。未发现剩余可复现的阻断代码缺陷。

## 未运行与阶段门槛

3.2 未运行：AT-13／14 的真实首页点击及分类失败画面、AT-19 滚动定位、VoiceOver、iOS 大字体、Reduce Motion、实际下载入口、动态字体下触控和底部遮挡。静态渲染请求大字体但 macOS 未体现放大，不能将其登记为大字验收。M4 需联调清筛选定位。M0～M2 的 iPhone 后台／锁屏／PiP、macOS 窗口／退出及旧功能操作回归仍待验。

最近设备查询显示用户 iPhone 的 Developer Mode 关闭，已请求开启后连接／解锁；没有使用其他人的设备。无测试失败待修，但验收缺项使 M3 保持 In Verification，不能标 Done 或发布。

3.1 本地交付：本轮阶段提交消息为“实现 M3 首页续听与系列进度定位”；提交身份用 `git log -1 --format='%H %s' -- openspec/changes/surface-listening-progress` 查询。没有 push、PR、主规格同步或归档。

## 2026-09-26 隔离 App UI 补充

M4 整合期间运行真实 SwiftUI／AVPlayer 的 iPhone 17／iOS 27 模拟器 UI 测试：首页从隔离容器的 30 秒本地历史一键启动静音 WAV；切 Tab、暂停后从历史／下载同集重进仍暂停；停止后重启保留续听卡且不出现活动迷你条／暂停动作。focused 结果 `/tmp/ZenPlayer-stage-ui-detail-fixed.xcresult`，1 项、0 失败。完整套件、两端回归及环境边界见 [M4 UI 验证](../search-loaded-catalog/verification.md#2026-09-26-隔离-app-ui-验证与补充交付)。

这补充 AT-04／13 的实际模拟器 UI 子断言；上节“真实首页点击／实际下载入口未运行”是本次之前的状态。样本是验证 App 内播种的本地完成下载，不证明生产下载传输、真正断网或分类接口失败。AT-14 分类失败实景、AT-15 完成态动态展示、AT-19 上次收听定位及可访问性门槛仍不关闭。3.2 保持未勾选。


## 2026-09-26 Mac 完成后的首页接续

本轮基线 `1bf59f9`。通过独立验证 App 的真实 SwiftUI／AVPlayer 测试补充 AT-15 和首页上下文贯通：关闭连播后本地首集自然完成，迷你条仍显示第一集已聽完，首页改为“繼續下一集”及第二集自己的 `已聽 0:07 / 2:00`，没有自动播放第二集；点击后直接续听第二集，完整页仍有前后切集，连播偏好仍为关闭。停止、正常退出、冷启动后只读核实第二集至少 7 秒、第一集 completed、末集 notStarted，首页没有活动会话。

另一用例在最后第 5 集完成后冷启动：首页回退到最近的其他未完成记录（第 2 集），不回第一集或使用末集 100%；点击恢复第二集并保留同一队列，上一集可将已完成第一集从头重听。静音媒体和持久化夹具不替代真实音视频听感。

证据：`/tmp/ZenPlayer-mac-queue-r3/tests.xcresult` 完整 **6 项、0 失败、0 跳过**（273.553 秒），其中 `testAutoAdvanceOffOffersNextWithItsOwnProgress` 27.106 秒；加强后的另一队列用例 `/tmp/ZenPlayer-mac-queue-final/tests.xcresult` **1 项、0 失败**（60.011 秒）。这不是 7 个独立场景。窗口树附件 `/tmp/ZenPlayer-mac-queue-r3-attachments/C49DC908-D82F-4D8A-9914-F671401B105C.txt` 明确显示下一集 7 秒及仍已完成的第一集迷你条。

夹具身份／数据边界、失败尝试、review 修正和复现命令见 [M2 记录](../play-series-in-order/verification.md#2026-09-26-mac-实际连播与偏好回归)。未改生产 App 代码与数据格式；复用未变化源码两端各 86 项测试证据。仍未覆盖无候选隐藏、紧邻下一集已完成的实际画面、分类失败实景、真实上次收听／历史返回定位、VoiceOver／Reduce Motion、真机和旧能力门槛。任务 3.2 保持未勾选、M3 仍 5/6／In Verification；不标 Done。

交付标题 `补充 Mac 连播与首页下一集实际回归`；仅本地提交。

## 2026-09-26 分类失败与历史定位 review

本轮基线 `main @ c5a17af`，开始时工作区干净。继续任务 3.2 的隔离 Mac UI 子断言，生产 App 文件／工程不变；没有修改真实数据容器、系统网络或远端 API。

新增两项测试：分类请求失败时本地续听，以及历史返回系列／上次收听定位。`MacCatalogURLProtocol` 只通过脚本加入临时 App 的 URLSession 配置，并按启动参数接管精确分类地址和专属 `.invalid/series`；分类返回唯一错误文字，系列返回 21 集确定数据。它保留真实 APIService 请求／解码／错误处理和 SwiftUI 页面，不证明物理断网或目录服务故障。`MacCatalogFixture` 只播种两个专属进度原键（第 12 集 42 秒、较早的第 18 集 completed）、固定快照和只读核验基线，保留其他历史／下载。

### 失败及 review 修正

- `/tmp/ZenPlayer-mac-catalog-r1/tests.xcresult`：1 失败、0 通过、0 跳过（17.289 秒）。全局 `URLProtocol.registerClass` 没有接管此会话，窗口树仍是成功的真实分类；不能算分类失败验收。改为临时 APIService 配置显式 `protocolClasses`，生产源文件不修改。
- `/tmp/ZenPlayer-mac-catalog-r2/tests.xcresult`：1 失败、0 通过、0 跳过（17.460 秒）。窗口已显示 `网络错误：Mac 分類請求失敗驗證`，但 Mac StaticText 的内容位于 value，测试误用 label 条件而未找到。改为完整文字匹配，保留错误与续听按钮上下位置断言。上述两次 build-for-testing 均通过，测试退出 65。

- `/tmp/ZenPlayer-mac-catalog-r3/tests.xcresult`：完整 8 项中 **7 通过、1 失败、0 跳过**。分类失败用例通过（10.812 秒），原有六项也通过；历史返回用例已进入系列页，但查询组合行标签失败（25.101 秒），后续定位与冷启动核验未运行。不能称整轮通过。修正测试对标签逗号分隔符的假设，并在系列加载后先保存窗口树，定向重跑历史用例。

### 最终通过证据

`/tmp/ZenPlayer-mac-catalog-r4/tests.xcresult`：历史／定位定向 **1 通过、0 失败、0 跳过，25.698 秒**；临时 App 与 UI target 构建、签名／sandbox 检查、测试均 exit 0。它与 r3 的其余 7 项通过结果共同覆盖当前 8 个用例，**不是同一轮 8 项全部通过**。r3 之后仅修改此测试方法和它独用的 `catalogEpisode` helper，其余 21 个方法逐字相同；最终 80 个 Swift／Python／xcstrings 文件与工程 hash 均匹配 r4 输入。

- **AT-14／S3 子断言通过**：首页同时显示分类网络错误与上方本地卡，30 秒起点一击播放到 32 秒，仍显示分类错误，未跳转完整页。窗口树 `/tmp/ZenPlayer-mac-catalog-r3-attachments/58DD2527-0B4F-4067-B815-561B6AA9942E.txt`。属于注入网络失败＋本地静音媒体的实际 UI，物理断网未运行。
- **AT-19／S5／S6 子断言通过**：带引用的最新历史返回实际系列，第 12 集完整行 frame `(6,451,995,66)` 位于窗口内且显示 `已聽 0:42`；筛第 18 集显示已聽完，第 21 集显示未收聽。筛选只剩 21、隐藏 12 后，点击“定位上次收聽”清词、恢复 21 集计数并滚回 12；无迷你播放／暂停或完整页停止控件。窗口树 `/tmp/ZenPlayer-mac-catalog-r4-attachments/4156DACE-1ED1-48FF-91C5-6F896F287D64.txt`、`2251CDFC-0ABC-4210-8059-682AB8BAD243.txt`、`B564B18E-9EE1-4CA9-9AE7-FE3C51FCAD87.txt`。实际组合标签使用“、”，原测试的英文逗号假设已被该证据否定。
- **仅定位不写进度通过**：正常退出后以 `--stage-verify-catalog` 重开，不重新播种；两条专属进度文件与播种时原始字节一致，位置、completed、修订及收听时间均未变。冷启动仍显示 42 秒且无活动播放。

复现（重跑使用新的 output）：

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-catalog-r3 --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-catalog-r4 --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages --only-testing testHistorySeriesAndLatestLocationClearFilterWithoutPlayback
```

Review：没有发现本轮需要修改生产实现的缺陷，修正集中于请求注入和 UI 测试选择器。116 个生产文件及工程 hash 与上一轮回归一致；两平台各 86 项、0 失败的 `/tmp/ZenPlayer-avkit-review-{mac,ios}.xcresult` 已重读 summary，**本轮复用、未重跑**。构建仍有 RNNoise 既有整数精度警告与 AppIntents 元数据提示；r3 有一条内部 QoS 警告，未将其当作已测的输入延迟。r3 附件首次并发读取与 summary 竞争数据库迁移而导出失败，随后顺序导出成功；未手工修改原始测试结果。

交付检查通过：M3／M4 两个 change 的 `openspec validate <change> --strict --no-interactive`、运行器 Python AST／`--help`、相关文档 9 个相对文件链接（不含锚点）、Git diff／新增文件／暂存范围审查。Roadmap 阶段状态未变化，因此不更新其历史摘要。

未运行／限制：不是 VoiceOver 朗读或截图目视验收，未断言“目前定位”的约 2 秒持续时间；未验 Reduce Motion、旧于最近 10 条的实际 UI 定位、其他历史行入口和参考机性能。无候选隐藏／紧邻已完成下一集、真实断网下载内容、iPhone 生命周期／锁屏／PiP、真实音效／分享／下载传输和迁移过程仍按既有矩阵待验。本轮未刷新设备状态。3.2 保持未勾选，M3 仍 5/6／In Verification。

本次本地提交标题：`补充分类失败续听与历史定位隔离回归`；实际身份用 `git log -1 --format='%H%n%B' --grep='^补充分类失败续听与历史定位隔离回归$'` 查询。只提交本轮 Harness／文档，不 push／PR／sync／archive／发布。

## 2026-09-26 首页候选边界与未知时长 UI

基线 `main @ 3edc4fac17e1b101494e312744f4df60c4c6bf68`，起始工作区干净。本轮继续 3.2 的 AT-15／M3 S2、S4 子断言：空历史隐藏、紧邻完成项不跳过、其他未完成候选回退及未知时长展示。生产 App／工程未变。

新增 MacResumeFixture，临时工程仅将两处共享仓库根目录和旧迁移来源接到显式参数控制的隔离入口。每个用例使用全新 UUID 目录，禁止覆盖已有目录；默认运行仍使用原验证 bundle 的共享路径。未删除现有验证记录，未接触生产 App 容器。这样首页与使用共享仓库的历史页不会因只给播放器注入空 store 而异源。记录／快照均为真实文件，使用原加载、候选、SwiftUI 实现；冷启动逐字节核对原样本，且核实 0／2／3 条记录与无恢复异常。

### 失败、修正与定向证据

- `/tmp/ZenPlayer-mac-resume-empty-r1/build.xcresult`：**构建失败**，exit 65；新夹具把可抛错的 Data 读取放进非抛错 precondition autoclosure。改为先读取再断言；UI 未运行。
- `/tmp/ZenPlayer-mac-resume-empty-r2/tests.xcresult`：**1 项通过、0 失败／跳过，6.350 秒**，覆盖空历史首次及只读冷启动。随后加强两秒持续隐藏断言，最终版本以完整回归为准。
- Review 核实 `.ended` 不会凭空生成实际收听时间，完成样本先 `.advance` 再 `.ended`，并断言 lastListenedAt／isValid；避免把没有实际收听时间的样本错误用于“最近完成集”测试。
- `/tmp/ZenPlayer-mac-resume-candidates-r1/tests.xcresult`：**1 项失败、0 通过／跳过，23.220 秒**。下一集正对照、紧邻已完成时隐藏及各自冷启动已执行；回退场景找到了正确标题和续听按钮，但测试错误地预期普通“已聽 0:42”。改为现有本地化的“已收聽 0:42 · 總時長未知”，并提前捕获窗口树。不能把这个失败轮次算整项通过。

### 验收边界

本次不把固定 completed 样本当作真实播放结束证据，也不把两秒无卡片观察扩展到任意异步时序。iPhone 复查 `/tmp/ZenPlayer-device-resume-details.json` 仍为已配对、Developer Mode Disabled，工具返回信息不完整警告；未安装或改设备。真实 iPhone 生命周期／锁屏／PiP、VoiceOver／Reduce Motion、参考机性能、真实下载／分享／音效、长历史 UI 和升级迁移缺口继续保留。3.2 未完成，阶段不标 Done。

### 最终完整回归与交付

`/tmp/ZenPlayer-mac-resume-final/tests.xcresult`：**13 项通过、0 失败、0 跳过，446.486 秒**。新增空历史用例 10.441 秒、候选边界用例 27.575 秒；后者包含 next／blocked／fallback 三种场景，不计为三项独立 XCTest。全部四种场景各有首次启动及只读冷启动断言。其余十一项（含上轮批量输入）同轮通过。临时 App／UI target 构建、签名／sandbox 检查和 test-without-building 均 exit 0。

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-resume-final --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages
```

复跑使用不存在的新 output；可添加 `--only-testing testEmptyHistoryHidesResumeCard` 或 `--only-testing testCompletedImmediateNextIsNotSkipped`。原生 Unicode 对照是独立诊断，不在此 13 项中，历史间歇输入问题未因此关闭。

已导出并复核窗口树：

| 场景／子断言 | 证据 |
| --- | --- |
| 空历史冷启动隐藏卡片 | `/tmp/ZenPlayer-mac-resume-final-empty/73B1FBAE-02C0-42CB-BCE7-9A722AE95DF8.txt`；首页错误已就绪，续听标题／按钮和下一集按钮均不存在；自动化持续观察两秒 |
| 紧邻第 2 集 completed，不越过推荐未听第 3 集 | `/tmp/ZenPlayer-mac-resume-final-candidates/D756557A-5064-41E1-9961-285FAC3A7381.txt`；冷启动无卡片，记录／快照字节一致 |
| 正对照：第 2 集未完成使用自身位置 | `/tmp/ZenPlayer-mac-resume-final-candidates/974295A3-94AA-4D79-8D1A-0D6D682EF5F4.txt`；“Mac 候選驗證-2”“已聽 0:07 / 2:00”及“繼續下一集” |
| 紧邻已完成，回退其他历史／未知时长 | `/tmp/ZenPlayer-mac-resume-final-candidates/1BB00332-3C26-4740-8AF5-B7DE0EBFF6DB.txt`；“Mac 其他未完成驗證”“已收聽 0:42 · 總時長未知”和“繼續收聽”，无下一集按钮 |

AT-15 对应的上述 Mac UI 子断言通过；未知时长仅为记录展示，未证明真实未知时长媒体播放。Review 修正均为测试夹具／断言，未发现需要修改生产实现的新缺陷。116 个生产文件和工程 hash 与上轮一致；最终构建的所有 Swift／Python 输入及工程与当前文件一致，构建后只补文档。两端各 86 项生产自动化／构建**复用、未重跑**。结果包含三条内部 QoS 警告，不是实测的性能结论。

M3／M4 strict 校验、Python AST／help／无效方法参数拒绝、Git diff 与新增文件审查通过。3.2 仍未勾选，M3 5/6、M4 5/6；阶段状态不变。下一步为长历史实际定位／旧集续听及其余矩阵门槛，不能把本轮通过扩展成阶段 Done。

本地提交标题：`补充首页候选边界与未知时长 UI 回归`；身份以 `git log -1 --format='%H%n%B' --grep='^补充首页候选边界与未知时长 UI 回归$'` 查询。只提交本轮 Harness／文档，不 push／PR／sync／archive／发布。

## 2026-09-26 长历史定位与旧集入口续听

基线 `main @ 373ac2d9039f4bbe077d2d0a21cf39fcf72fcde0`，起始工作区干净。继续 3.2 的 S5／AT-16／AT-19 子断言。新增独占目录 long-history 变体，14 条长期记录中旧系列两条均被另外 12 条挤出最近十条；目录响应经精确 URL 测试协议进入真实分类／系列页面。没有改生产 App、工程、共享仓库实现或真实数据容器。

两条测试各自执行三次启动：首次从最近页确认 10 条边界，进入旧系列检查第 18 集 completed 和第 12 集 42 秒，筛 21 后“定位上次收聽”清筛选／滚动且不播放；首次冷启动逐字节核对全部 14 条，随后从系列行或下载行续听旧目标；第二次冷启动只允许该目标原键更新，其他 13 条字节不变、总数仍 14。下载媒体使用真实 120 秒 WAV，合并单个自有下载键 `910012_mp3`，保留其他下载。此样本不证明下载传输、物理离线或真实媒体听感。

初次 `/tmp/ZenPlayer-mac-long-history-series-r1/tests.xcresult`：**1 失败、0 通过／跳过，22.500 秒**，构建成功。最近页 10 条／底部第 3 条／旧记录缺席断言已执行，分类入口查询失败；CodeGraph 证实现有 CategoryCardView 显示 desc 而非 title，测试错误地按未呈现的标题查找。修正隔离分类样本的可见描述为明确名称，补入口前窗口树；未修改产品分类卡。该失败轮次不算定位或续听通过。

第二次 `/tmp/ZenPlayer-mac-long-history-series-r2/tests.xcresult`：**1 失败、0 通过／跳过，60.713 秒**，构建成功。旧系列状态、筛选隐藏目标后的定位和首次冷启动全部 14 条字节不变核验通过；进入播放页并返回后，测试误在系列页查找首页进度文案，未取得时间，后续暂停与播放后冷启动未执行。CodeGraph 确认迷你条只显示标题／状态，不显示时间；修正测试为返回首页读取活动会话位置，再暂停／退出核验，没有修改生产 UI 或恢复逻辑。

范围核对：PRD AT-16 的完整操作是“依次播放 30 个单集后回到第 1 个，重开 App”。本轮 14 条播种样本针对 M3 S5 的“超出最近十条仍能定位”以及旧入口恢复子断言；不能用它替代真实依次播放 30 集的完整 AT-16。该操作门槛继续保留，既有 30 条存储单测也不替代实际入口验收。

### 最终完整回归与 review

`/tmp/ZenPlayer-mac-long-history-final/tests.xcresult`：**15 项通过、0 失败、0 跳过，552.872 秒**。新增下载入口 49.989 秒、系列入口 55.614 秒；包含全部既有十三项。构建、签名／sandbox 核验和 test-without-building 均 exit 0。默认 Unicode 跳集输入仍为 0012，独立原生 Unicode 诊断未在本轮重跑。

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-long-history-final --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages
```

重跑使用新的 output；可指定 `--only-testing testEvictedHistoryStillLocatesAndResumesFromSeries` 或 `--only-testing testEvictedHistoryResumesFromDownload` 单跑新入口。

| 新增实际证据 | 窗口树／结果 |
| --- | --- |
| 最近十条排除旧系列 | series 附件 `CD230E94-FB48-46A7-967A-F10B5182FB4C.txt`：摘要为 10，滚到底部显示新近第 3 条，两个旧系列项不在最近行中 |
| 被筛选隐藏的旧第 12 集仍可定位 | series 附件 `A34F98C8-5945-4715-9D75-9E9355A43E76.txt`：`Mac 長期保留-12、已聽 0:42、目前定位、第 12 集`，frame `(6,444,995,80)`；无活动播放 |
| 定位不重写／抬升旧记录 | 第一次只读冷启动全部 14 条进度与原始字节一致，最近十条仍无旧第 12 集 |
| 系列入口恢复后暂停／冷启 | series 附件 `9B0D171C-E0B0-4E56-BC4D-02C487537B16.txt`、`D5709D24-EAA7-4586-A719-8CAB92DB26C5.txt`：暂停及冷启动均显示 0:51 / 2:00，冷启动不自动播放 |
| 下载入口恢复后暂停／冷启 | download 附件 `E724ED50-0125-4E59-B80E-200EBC16CFB8.txt`、`BDF409A2-475A-4F24-A95D-80E44912AD6A.txt`：同样保留 0:51 / 2:00，冷启动无活动播放 |
| 播放后长期数据保护 | 两条入口各自通过第二次只读启动：目标原键更新、有效未完成状态／位置／收听时间／修订保留，其余 13 条字节不变，总记录仍 14，目标重新进入最近十条 |

表中 series／download 文件分别位于 `/tmp/ZenPlayer-mac-long-history-final-series/`、`/tmp/ZenPlayer-mac-long-history-final-download/`，已顺序导出并核实窗口树。恢复位置断言要求返回首页后 15 秒内达到至少 44 秒，暂停低于 65 秒；这是此实际流程的位置检查，不是恢复精度或启动时延测量。窗口树不是 VoiceOver、真实听感或约两秒高亮时序验收。

Review 未发现需要修改生产实现的新缺陷，修正均为隔离样本和测试测量位置。当前源码／工程与最终结果输入 hash 一致（构建后仅编辑文档）；116 个生产文件及工程与上一轮不变，两端各 86 项生产测试／构建**复用，未重跑**。结果含三条内部 QoS 警告，未把测试总耗时作为端到端性能证据。

完整实际 30 集操作、真机生命周期／锁屏／PiP、VoiceOver／Reduce Motion、参考机性能、真实下载／分享／音效与迁移过程等缺口继续保留。M3／M4 均 5/6，3.2 未勾选，阶段不标 Done。下一步优先补 PRD AT-16 的真实依次播放 30 集及回到第 1 集的操作证据。本轮未重新查询设备状态，最近一次 Developer Mode Disabled 记录仍只是先前检查结果。

本地交付标题：`补充长历史定位与旧集入口续听回归`，身份以 `git log -1 --format='%H%n%B' --grep='^补充长历史定位与旧集入口续听回归$'` 查询；只本地提交，不 push／PR／sync／archive／发布。

## 2026-09-26 三十集实际播放与首集冷启动恢复

基线 `main @ 9325c2646a10e66968499cb32ddf014b702b108f`。本次审查未提交的 AT-16 回归测试及夹具；生产 App 和工程未改。样本从空进度仓库开始，只准备 30 集目录快照／本地静音 WAV／自有下载键，进度由真实 SwiftUI 入口和 AVPlayer 播放产生。每集保留标题／状态／时间的窗口树，第一集至少 12 秒，其余至少 2 秒；正常退出后恢复第一集，并在再次冷启动核对其他 29 条进度原始字节不变。数据和运行方式见 [UI 测试说明](../../../ZenPlayerUITests/README.md#mac-实际播放三十集后恢复首集)。

### 首轮失败与 review 修正

`/tmp/ZenPlayer-mac-thirty-plays-r1/tests.xcresult`：**0 通过、1 失败、0 跳过，298.692 秒**，构建通过。已执行全部 30 集实际播放、首集暂停位置记录和最近 10 条／底部第 21 集／首集不在最近列表断言；返回首页后点击分类卡前，`clickCenter` 的完整可见性断言失败，返回首集及冷启动未执行，不能记 AT-16 通过。

窗口树 `/tmp/ZenPlayer-mac-thirty-plays-r1-trees/6E4EAE12-9310-4E7B-A5C0-07B2F4D2296B.txt` 显示：窗口 `(0,33,1024,768)`，续听卡下方分类卡 `(28,436,477,409)`，底部超出窗口。修正仅在新用例的 `openThirtySeries` 中加入有限次数的实际滚动和前后窗口树，仍保留完整可见检查，没有放宽点击断言或修改生产布局。恢复断言使用媒体位置减去实际经过时间，避免从零播放到阈值造成误判。

### 第二轮与无窗口对照

`/tmp/ZenPlayer-mac-thirty-plays-r2/tests.xcresult`：**0 通过、1 失败、0 跳过，353.857 秒**，构建通过。滚动、回到首集、第一次冷启动及实际从原位置恢复均通过；暂停时窗口树 `AD763180-FD16-4515-AAED-34326604BF61.txt`（位于 `/tmp/ZenPlayer-mac-thirty-plays-r2-trees/`）显示首集 `已聽 0:22 / 2:00`。最后启动未找到首页标题，整条用例仍失败。

只读检查该独立目录 `resume-E0206D89-D6B6-4ECF-AA98-E20F68B0D8BD`：30 条记录保留，首集实际 22.830014125 秒，其他 29 条与 `thirty-before-resume.json` 逐字节一致。没有回写这些进度。临时测试副本追加仅重开该样本的诊断方法，`probe.xcresult` **1 失败，17.973 秒**，窗口数为 0；手动启动相同隔离 bundle 后 `sample` 显示主线程处于正常事件循环，未发现崩溃／主线程阻塞证据。AppleScript 读取界面因缺少辅助访问失败，未修改权限设置。

同一临时诊断再明确断言窗口数为 0，并发送 Command-N：`probe-window.xcresult` **1 通过，4.133 秒**，真实仓库校验及首集标题展示通过。两份 probe 结果在 `/tmp/ZenPlayer-mac-thirty-plays-r2/`；仅用于故障定位，不计入阶段套件通过数，临时诊断方法未保存到仓库。正式用例增加局部启动窗口检查：等待 5 秒后若无窗口，保存文本证据并实际新建窗口，再核对进度。尚不能断言缺窗由 XCTest、SwiftUI 或系统恢复状态中的哪一层引起；不声称已修复生产生命周期，也不把该分支作为自动开窗证据。

第三轮 `/tmp/ZenPlayer-mac-thirty-plays-r3/tests.xcresult`：**0 通过、1 失败、0 跳过，68.687 秒**，构建通过。在第 3 集进入完整页并点击下一集后，未取得第 4 集标题；独占目录 `resume-74774AF0-5F76-476D-9992-3D790AA1F134` 实际保留第 1／2／3／5 集进度，第 5 集约 9 秒，没有第 4 集记录。因此不能只描述成“标题选择器失效”或宣称该轮依次播放成功。此前两轮相同路径均走完 30 集；本次尚不能区分额外输入事件、导航交互或切集逻辑原因。新增失败时完整窗口树采集，保持原断言，不添加自动补点／跳过／降低集数门槛；间歇切集现象保留为待调查风险。

### 最终定向通过证据

`/tmp/ZenPlayer-mac-thirty-plays-r4/tests.xcresult`：**1 通过、0 失败、0 跳过，351.809 秒**。macOS 27.0／MacBook Pro arm64；构建、验证 bundle 签名与 sandbox 检查、test-without-building 均 exit 0。结果有一条内部 QoS 警告，测试耗时不作为产品反馈或搜索性能证据。

```sh
python3 Scripts/run-mac-stage-ui-tests.py --output /tmp/ZenPlayer-mac-thirty-plays-r4 --package-cache /tmp/ZenPlayer-M0-mac/SourcePackages --only-testing testThirtyActualPlaysPreserveFirstProgressAfterRestart
```

重跑需另选不存在的 output。以下窗口树均位于 `/tmp/ZenPlayer-mac-thirty-plays-r4-trees/`，已从结果中导出并核对：

| 子断言 | 实际证据 |
| --- | --- |
| 首集初始播放并暂停 | `F0D115E1-A00F-466F-8479-53135EB2A8A9.txt`：首集 0:14 / 2:00，已暂停 |
| 实际播放到第 30 集、最近仅 10 条 | 每集标题／播放／时间检查均通过；`E66F3D4A-D6A5-44E4-AF17-E0A636734869.txt`：摘要 10，滚到底部为第 21 集，首集不在最近行中 |
| 回首集原位置未被挤掉 | `4D1A6418-CBB9-4639-929C-AD83156307C0.txt`：系列首集仍为已听 0:14；首次冷启动读取全部 30 条并核对最近顺序 30～21 |
| 冷启动后实际续播 | 媒体位置减去经过时间的下限断言通过；`E1C7076B-45E9-457C-A558-5CC2C5CBE9F6.txt`：恢复后暂停为 0:22 / 2:00 |
| 再次启动保留实际新位置 | `6338608A-6BC7-48D1-9B9D-D1B3CB3B5F61.txt`：首页首集 0:22 / 2:00，无自动播放；仓库仍 30 条，首集进入最近第一项，其他 29 条逐字节不变 |
| 启动窗口边界 | 最后一次启动触发无窗口分支，`77BC07A7-44C5-4E3F-9956-38893AE0F34A.txt` 明确记录 Command-N；这是新建窗口后的展示证据，不是自动开窗通过 |

本轮实现输入为 85 个 Swift／Python／xcstrings 文件及工程，已与 r4 `context.json` 的 SHA-256 核对。116 个生产文件及工程未变；两端各 86 项 `/tmp/ZenPlayer-avkit-review-{mac,ios}.xcresult` 的结果摘要重新核对为通过，**复用、未重跑**。默认 Mac 阶段套件现为 16 项，本轮先定向执行新用例；不得把它称为完整 16 项同轮通过。

### 未验证项与剩余风险

AT-16 增加真实 30 集 macOS 操作证据，但第三轮间歇跳集原因和自动开窗差异未解决，不能用 r4 通过覆盖历史失败。参考机性能、VoiceOver／Reduce Motion、真实下载／分享／媒体音效、异常强杀与升级迁移仍需执行。当前 iPhone 16 Pro／iOS 26.6.2 已连接配对，但 Developer Mode disabled，设备工具返回信息不完整警告；本轮只读复查记录为 `/tmp/ZenPlayer-device-thirty-review-details.json`／`.log`，未安装或修改设备。

M3／M4 仍 5/6，3.2 未勾选，M0 仍 6/13，阶段保持 In Verification。下一步继续调查间歇切集与启动窗口差异，并完成剩余设备／辅助功能等门槛；不建议标 Done。

### 受影响旧入口回归与本地交付

复用 r4 的同一构建，串行定向运行 `testEvictedHistoryResumesFromDownload`／`testEvictedHistoryStillLocatesAndResumesFromSeries`：`/tmp/ZenPlayer-mac-thirty-plays-r4/legacy-regression.xcresult` **2 通过、0 失败／跳过，106.232 秒**（下载 50.379 秒，系列 55.853 秒）。`legacy-regression.log` 保存命令输出。它验证目录响应复用后的原 long-history 分支：14 条样本、旧入口恢复和其他 13 条字节保护仍通过，不等同重新运行全部 16 项。

实际命令为相同临时工程和 derived-data 的 `xcodebuild test-without-building`，同时指定 `-only-testing:StageUITests/StageUITests/testEvictedHistoryResumesFromDownload` 和 `-only-testing:StageUITests/StageUITests/testEvictedHistoryStillLocatesAndResumesFromSeries`；未并发运行 Mac GUI 测试。最终新用例 1 项、旧入口 2 项分两轮通过；前三轮失败和两次临时诊断另列，不合并成一次全绿结果。

Review 修正仅为测试滚动、明确的窗口重开步骤及失败现场采集；没有确定足以修改生产代码的间歇跳集根因。Python AST／脚本 help、输入 SHA-256、相对文档链接、M0／M3／M4 strict 及 Git diff 检查通过。交付标题 `补充三十集实际播放与冷启动进度回归`，本地身份以 `git log -1 --format='%H%n%B' --grep='^补充三十集实际播放与冷启动进度回归$'` 查询；不 push／PR／主规格同步／归档／发布。

交付检查通过：M3／M4 strict 校验，Python AST／CLI help，11 个相对文件链接（不含锚点），84 个 Swift／Python／xcstrings 与工程输入 hash，Git diff／新增文件及暂存范围 review。Roadmap 阶段状态未改变。
