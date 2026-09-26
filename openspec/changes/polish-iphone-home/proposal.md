# Proposal

## Why

iPhone 11 实机首页的续播卡片纵向占用约 240pt，主操作与选中导航均为灰色，分类依靠图片内文字识别，视觉层级不清晰。用户已在本会话批准上一轮的首页优化建议，本变更记录并实施该明确范围。

## What Changes

- iPhone 首页采用暖白底色、深墨绿强调色，适配深色模式；保留首页／我的两个入口。
- 标题左对齐，服务端统计说明弱化，增加「瀏覽分類」分区。
- 续播卡片采用标题与圆形主操作并排、下方进度与时间的紧凑布局；动态字体自然增高。
- 分类卡片增加原生文字名称，简介降为一行，常规字号保持双列，大字体采用单列。
- 保留 F2-01 及现有 `surface-listening-progress` 的候选、直接控制、未知时长和分类加载独立性；遵循 Q-03 可访问性要求。

## Capabilities

### New Capabilities
- `iphone-home-presentation`: iPhone 首页的视觉层级、续播进度展示及自适应布局。

### Modified Capabilities
无。当前无已同步主规格；本变更补充展示约束，不重写 M3 的业务需求。

## Impact

涉及 `HomeView`、`HomeResumeCard`、`CategoryCardView`、`ContentView` 的 iOS 展示、颜色资源和 L10n 文案。现有 macOS 展示保留；不改播放所有权、存储、下载、网络接口、依赖、签名和版本。PRD 原轮次不含整体视觉重设计，本次用户额外授权仅覆盖上述首页优化，不扩展播放页或其他页面重设计；不改变 M0–M4 状态。
