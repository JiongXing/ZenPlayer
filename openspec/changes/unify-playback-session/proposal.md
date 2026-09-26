## Why

M0 已保护长期进度，但 PlayerView 仍创建自己的 PlayerViewModel 并在离开页面时停止。M1 按 PRD F1-01～F1-04、Q-01～Q-03 让浏览页面共享唯一会话，保证选择、控制、失败和中断恢复一致。

## What Changes

- macOS 使用单个主窗口，移除新建窗口及跨窗口同步验收；关闭主窗口遵循 SwiftUI Window 的退出行为并保存进度（2026-09-26 用户明确不需要多窗口）。
- App 持有唯一播放器模型，历史／下载／系列值路由只选择或展示该会话；相同原键重复进入不重建、不唤醒暂停。
- 安全区迷你条显示目标与状态，提供开控制页、暂停／播放、失败重试和停止；完整页不重复显示。
- 统一播放意图、自然结束、停止清理、中断条件恢复和媒体请求身份；新目标失败不恢复旧音频。
- 加入 300 毫秒加载状态及 30 秒无有效进展失败边界，暂停时间不计入超时。
- 保留 M0 保存／恢复合同、本地优先和音频处理原声回退。M0 设备缺口仍列未验。

## Capabilities

### New Capabilities

- `playback-session`: 进程级唯一播放会话、控制及生命周期。

### Modified Capabilities

无主规格可修改；不自动同步 M0 主规格。

## Impact

涉及 ZenPlayerApp、ContentView、PlayerView、PlayerViewModel、迷你条和本地化；新增可独立测试的会话意图模型。现有三类入口仍使用 PlaybackContext，保持原值路由；无部署版本／签名／依赖变更。不实现 M2 队列、M3 首页卡或 M4 搜索。

本轮授权：用户要求 review 并提交当前阶段代码，范围为工作区现有 M1 变更及其修复／验证。本轮不推进 M2～M4，不 sync／archive／push／发布；阶段完成仍需真实验收证据，见 verification.md。
