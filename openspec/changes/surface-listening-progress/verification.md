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
