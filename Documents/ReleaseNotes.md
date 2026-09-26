# 版本记录

此处记录工程版本及更新内容，不表示已上架或发布。App 版本号独立于 PRD 文档版本和 Roadmap 阶段。

版本号采用 `主版本.功能版本.修复版本`：功能或界面迭代递增中间位并将末位归零；仅修复 bug 时递增末位。

## 1.2.0（Build 120）— 2026-09-26

- 播放页新增按需打开的讲集信息和播放列表，可直接选集或进入讲集详情。
- 精简播放页：列表使用纯图标，移除重复的播放／暂停按钮，停止入口移至更多菜单。
- 连播、降噪和音量增强默认折叠，保留当前档位摘要以及错误／重试提示。
- 调整留白、配色和大字体布局，适配 iPhone 与 macOS。

版本配置从 1.1.0（Build 110）升级为 1.2.0（Build 120），App target 的 Debug／Release 同步更新。

功能验证范围与未运行项见 [播放列表验证记录](../openspec/changes/show-player-series-playlist/verification.md) 和 [简约播放页验证记录](../openspec/changes/simplify-player-layout/verification.md)。这些记录保留功能验收时的环境，不作为本版本已发布的证明。
