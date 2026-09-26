# Design

## Context

见 proposal.md。当前 HomeResumeViewModel 已提供可靠候选，HomeViewModel 的说明来自 API；本轮只调整展示。工程和 xcstrings 在任务开始时已有用户修改，须保留。

## Goals / Non-Goals

目标是局部 SwiftUI 展示改造，避免新会话状态或主题框架。非目标包括播放页重设计、业务流程调整、存储迁移和 macOS 视觉改造。

## Decisions

- 新增少量具备明暗变体的颜色资源，仅在 iOS 首页及 TabView tint 使用；不修改现有全局 AccentColor，避免影响 macOS。
- 标题左对齐，保留原始服务端说明并降低字号，不解析或硬编码年份、数量。
- 续播按钮复用原动作和禁用条件。普通字号标题最多两行，大字体允许增高；课程名和集数不为压缩而丢失。用可靠 duration 绘制有界进度，未知时长省略进度条。
- iOS 分类采用自适应列数的网格，正常双列，辅助功能字号单列。图片比例保持 16:9，名称和简介按层级展示；macOS 沿用现有布局。
- 新文案通过 L10nKey 与现有 xcstrings 增量加入。复用既有 ResumeCandidateTests / HomeResumeViewModelTests 验证候选业务，不为颜色常量编写镜像测试。

## Risks / Trade-offs

- 长标题截断 → 常规字号限制两行但保留完整辅助功能文本；辅助功能字号放开高度。
- 暖色在深色模式对比不足 → 独立深色资源并做模拟器截图检查。
- 真机安装覆盖正在运行的旧进程 → 使用现有签名构建并正常安装更新，不卸载、不修改真实数据容器；仅验证首页展示。
- 原有 M0–M4 真机后台／锁屏／PiP 验证缺口不由此次视觉截图关闭。
