## Context

基线 49b4eed，M0 接口已提交、验收未齐。PlayerView 每页持有模型并在 onDisappear stop；三类入口混用 PlaybackContext 值路由及直接 PlayerView。App 的 WindowGroup 未注入会话。保留现有 NavigationStack／TabView 和降噪构建链路。

## Goals / Non-Goals

Goals：复用现有 PlayerViewModel 作为 App 级媒体所有者，避免第二套引擎；分离可测的播放意图与平台事件。Non-Goals：本阶段不创建队列／首页卡／搜索，不改 M0 迁移合同。

## Decisions

- ZenPlayerApp 的 @State 模型向根视图注入 Environment；macOS 使用系统 Window（单个主窗口），iOS 保留 WindowGroup。关闭 macOS 主窗口按系统单窗口语义退出，沿用现有 willTerminate 保存链路，不增加窗口协调器。页面只读取同一实例，不持有媒体资源；同键 prepare 幂等。保留 PlaybackContext 路由以减小入口改动，后续 M2 可扩展上下文。
- 纯 PlaybackSessionState 负责目标身份、请求修订、播放意图、阶段、中断恢复资格及可控时钟无进展检测；AVPlayer／M0 progressGate 保持媒体和保存职责。采用单一意图模型，避免多个视图分别推导播放状态。
- 完整页使用当前会话目标，传入 context 仅是单集入口选择；迷你条经独立的控制页值路由只展示当前会话，避免导航延迟重选旧目标。ContentView 只给浏览页内容应用迷你条安全区修饰器，根页继承 Tab 上方安全区、详情页继承窗口安全区；完整播放页不应用该修饰器，不再维护页面可见性 ID 集合。我的页面入口也使用绑定路径的值路由，防止从未记录在 NavigationPath 的直接目的地追加控制页时丢失原页面；退出页面不释放模型。
- 所有暂停／继续／停止和 iOS 系统控制走相同模型方法。停止递增媒体身份并移除观察者、系统命令、音频会话；中断前记录是否在播放，手动暂停撤销恢复资格；系统中断导致的原生暂停观察不撤销资格，重复开始通知幂等。
- KVO 和通知携带 player/item/token；准备／播放中途失败及 30 秒无进展时取消有效请求，保留当前目标与进度用于重试。轻量可取消监测任务只在活动会话存在，按单调时钟判定，暂停不超时。
- 切源读取即时 AVPlayer 状态避免 KVO 延迟导致暂停意图丢失；失败重试保留失败前意图。原生控件仍操作同一 AVPlayer；其 rate／timeControlStatus 观察将变化反馈到统一状态。视图不能自动 play；加载恢复完成后仅执行当前意图。
- macOS Debug／Release 显式保留系统 AVKit 框架链接（`-needed_framework AVKit`）。实际 Xcode 27 产物只自动链接了 `_AVKit_SwiftUI`，进入 VideoPlayer 时无法解析其 AVPlayerView 父类并崩溃；系统框架的动态类型依赖不能依靠直接符号引用自动推导。保留既有 VideoPlayer 与 AVPlayer 所有权，不增加替代渲染器或修改 iOS 链接选项。

## Risks / Trade-offs

- 原生暂停、系统中断及缓冲 rate==0 需区分 → 依据 timeControlStatus 与显式意图测试，设备路径另验。
- 窗口／全屏／PiP 的 SwiftUI 可见性差异 → macOS 只维护一个主窗口，验证关闭／退出保存与重新启动续听；不以模拟器单元测试冒充设备验证。
- M0 阶段的设备缺口 → 保留原状态，M1 集成测试覆盖相关行为但不提前标为 Done。

## Migration Plan

不迁移数据，不改签名或依赖；M0 进度单例继续使用。新会话不持久化活动播放，启动始终 idle。回退 UI 代码仍保留新存储。

## 2026-09-26 验证范围调整

用户要求“测试用例不必太严苛，极端情况不必考虑，核心保证主流程可用即可”。阶段验收采用现有确定性测试和实际 UI 主流程证据；不再将 VoiceOver 全流程、所有字体／窗口组合、精确动画时长或重复压力执行作为本轮工程任务完成条件。相关产品行为仍保留，实现走读与未运行的设备／辅助功能验证分别登记，不写成通过。真实 iPhone 后台／锁屏／PiP 等核心平台能力继续由 M1／M2 及 M4 汇总追踪；本阶段展示完成不关闭其缺口，也不等于发布验收。
