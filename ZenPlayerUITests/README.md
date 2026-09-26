# 阶段 UI 验证

此套 XCTest UI 测试运行真实 SwiftUI 页面和 AVPlayer。生产工程不增加 UI target，也不引入测试模式；脚本把当前工作区源码复制到新的仓库外目录，只在副本添加 UI target 并改用独立 bundle `com.jxing.ZenPlayer.StageValidation`。不会安装到真机或写生产 App 数据。请在同一模拟器上串行运行，不要同时手动操作验证 App。

```sh
python3 Scripts/run-stage-ui-tests.py \
  --destination 'platform=iOS Simulator,id=F98C04D4-C1D9-4D5D-A97F-F13C5F8BF425' \
  --output /tmp/ZenPlayer-stage-ui-new-run \
  --package-cache /tmp/ZenPlayer-M0-ios/SourcePackages
```

用 `xcrun simctl list devices available` 选择本机实际可用的 iOS 模拟器 UUID。输出目录必须尚不存在；`--package-cache` 可省略，传入时目录须存在。脚本会构建、启动选定模拟器、安装独立验证 App、播种样本，再执行 UI 测试。测试并发关闭，并通过 `-collect-test-diagnostics never` 关闭本机 Xcode 27 曾卡住的额外 simctl diagnose 采集；XCTest 断言、日志及显式截图仍保留。输出包含源码 SHA-256／HEAD／目的地、工程和播种器快照、build/test 的日志及 xcresult；退出非 0 表示未通过，保留现场。

播种器会先核对模拟器容器的 bundle 身份，只更新此验证 App 内拥有的样本：`900001_mp3` 下载索引、180 秒静音 WAV 和该集 30 秒进度，不清空其他记录。它不读取或复制生产数据。样本远端地址使用不可解析的 `.invalid` 域名，播放成功证明本地文件绑定有效；这不等于真实下载传输或断网验收。测试结束后保留验证 App 和容器用于调查；每次运行会重新播种同一条样本。

- 续听测试：冷启动无活动播放、首页本地续听、迷你条位于 Tab 上方且标题入口至少 44pt 高、切 Tab、暂停、完整页隐藏迷你条、历史／下载同集重进仍暂停、停止和重启保留续听入口。
- 搜索测试：真实分类数据的零结果／清词、阿弥陀经 `01-001` 系列过滤、不存在集数提示、`0012` 定位第 12 集、清筛选／收键盘、不自动播放。

分类和系列测试依赖现有目录 API，以及 `01-001` 当前 21 集数据。服务不可达或内容变更时测试可能失败，须区分环境／数据变化与产品缺陷，不能将跳过当通过。播放测试使用本地样本，但首页仍会按正常流程请求目录。

截图保存在 xcresult，可导出复核：

```sh
xcrun xcresulttool export attachments \
  --path /tmp/ZenPlayer-stage-ui-new-run/tests.xcresult \
  --output-path /tmp/ZenPlayer-stage-ui-images --filter '*.png'
```

这套测试不替代 `ZenPlayerTests` 的两平台自动化，也不覆盖真实 iPhone 后台／锁屏／PiP、macOS 多窗口／退出、VoiceOver、动态字体、真实媒体听感或端到端性能。每次实际结果和剩余验收记录在相应 change 的唯一 `verification.md`；不能凭 UI target 通过标记整个阶段 Done。
