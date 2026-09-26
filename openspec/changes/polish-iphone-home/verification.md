# iPhone 首页优化验证

日期：2026-09-26。用户在查看 iPhone 11 首页建议后明确要求「按推荐进行 UI 优化」，本轮包含实施及安装到已连接设备查看；不含提交、推送、同步或归档。

## 变更范围

- 首页左对齐标题、真实 API 说明、分类标题、暖白与墨绿明暗配色。
- 续播卡圆形 56pt 按钮、紧凑文字及可靠时长进度条；动作和准备禁用条件沿用原逻辑。
- 双列分类名称／一行简介，辅助功能字号单列；沿用原路由、封面、网络与候选业务。
- 仅新增一个繁体文案；现有 AccentColor 和工程配置未修改。

## 已验证

产物及日志目录：`/tmp/zenplayer-home-polish.jn1VnS`。

- iOS Simulator：`xcodebuild -project ZenPlayer.xcodeproj -scheme ZenPlayer -destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' -derivedDataPath /tmp/zenplayer-home-polish.jn1VnS/build CODE_SIGNING_ALLOWED=NO SWIFT_EMIT_LOC_STRINGS=NO build`，通过。实际目的地 iPhone 17 / iOS 27。
- macOS：同工程／scheme，`-destination 'platform=macOS' -derivedDataPath /tmp/zenplayer-home-polish.jn1VnS/mac-build CODE_SIGNING_ALLOWED=NO SWIFT_EMIT_LOC_STRINGS=NO build`，通过。
- iPhone 11：同工程／scheme，`-destination 'platform=iOS,id=00008030-001A4D1601A1802E' -derivedDataPath /tmp/zenplayer-home-polish.jn1VnS/device-build SWIFT_EMIT_LOC_STRINGS=NO build`，使用现有签名通过；正常安装更新成功，未卸载或改数据容器。
- 在上述 macOS derivedData 下执行 `-only-testing:ZenPlayerTests/ResumeCandidateTests -only-testing:ZenPlayerTests/HomeResumeViewModelTests test`：11 项通过，0 失败，隔离数据测试覆盖候选、未知时长、空历史、下一集及加载独立性。不是 UI 自动化证据。
- `simulator-light.png`、`simulator-dark.png`：实际首页截图已查看，分类布局／配色与选中导航正常。该模拟器无续播记录，已验证卡片隐藏后的布局。
- `simulator-large-text.png`：辅助功能 accessibility-extra-large 下深色首页截图已查看，分类转单列、名称可读、无横向溢出；测试后恢复原 light / large 设置。
- 三个颜色资源与 xcstrings 的 JSON 解析通过；`openspec validate polish-iphone-home --strict --no-interactive` 通过。
- 真机解锁后启动成功，最终 `iphone-home-verified.png`（828×1792）已查看：续听卡约 170pt 高，圆形主操作、20:02 / 56:13 的真实位置、进度条、分类名称与导航选中态均可见；末尾重复集数仅在展示标题中省略，独立集数字段仍保留。未改原始标题／记录。
- 标题尾缀整理后增量重跑 iOS 模拟器／真机构建均通过（`ios-build-final.log`、`device-build-final.log`），重新安装并启动真机成功；变化仅处于 iOS 编译分支，复用本轮 macOS 构建及未变化业务的 11 项测试证据。
- 最终 `git diff --check`、暂存／未暂存范围、未跟踪资源与文档检查通过；M3 仅追加视觉版本交接记录，相关 change strict 校验通过。

## 验证限制与待完成

- 首次真机启动在黑屏状态下等待 20 秒超时；用户解锁后再次启动成功，已取得最终 App 页面，原阻塞已解除。
- 未新增颜色／布局常量镜像测试，未做完整 VoiceOver、所有字体组合、点击续播／暂停、后台／锁屏／PiP 回归；原 M0–M4 生命周期验收缺口不由本轮关闭。
- 深色／大字体截图来自无续播历史的模拟器；续播卡在这两种模式下只有代码走读证据，未进行对应实机操作验证。
- 构建存在原 RNNoise C 转换及无 AppIntents 依赖的提示，未见本次 Swift 展示代码错误。

## 工作区保留

开始 HEAD 为 `4df37f5`，工程与 xcstrings 已有改动。执行期间外部提交 `e596ff3 真机编译` 收录原有改动；本 agent 未提交。工程文件 SHA-256 前后均为 `0a56296dbb94c11f48666d347384f3b5901650b717fd5b94bcfff19f6d7eb096`，xcstrings 相对新 HEAD 仅新增文案和末尾换行。

## 本地提交交付

用户后续明确授权「提交 git」。提交检查时 HEAD 已推进至 `caa67af`（另含播放页和版本变更）；本次仅提交首页 UI、`home.browse_categories` 文案、颜色资源和相关 change 文档。保留工作区另有的 macOS 签名、Scheme 格式及其他本地化整理。两项 change strict 校验与 diff 检查通过；复用上轮首页构建、11 项测试和真机截图证据，不声称推进后的整个基线已重新构建／回归。不推送、不同步或归档主规格。
