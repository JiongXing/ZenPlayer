## Why

M1 已统一会话，但自然结束仍停在当前集。M2 按 PRD F1-05～F1-07、D-01／D-02、Q-02／Q-04 加入真实系列顺序，减少每集结束后手动找课；保留 M0 进度和 M1 设备验收缺口。

## What Changes

- 系列入口携带未筛选的已加载列表快照、系列元信息、完整性和当前索引，顺序允许 1／2／5。
- 保存快照和轻量系列引用；旧历史／下载入口异步恢复本地快照，缺失时仅播放当前集并提示，不等待远端补列表。
- 默认开启并持久化自动连播；完整页提供边界禁用的上一／下一集。
- 自然结束校验媒体与队列版本并只推进一次；开关关闭／最后一集停止，不循环、不跳过完成集。
- 延续当前媒体类型、本地优先、已下载替代类型及明确失败目标；失败不自动跳过，重试保留队列、位置及偏好。

## Capabilities

### New Capabilities

- `series-playback-queue`：系列快照、顺序控制、结束推进和媒体选择。

### Modified Capabilities

暂无主规格。增量叠加 M1 会话，不同步／归档其 delta。

## Impact

当前 SeriesDetailViewModel 直接展示 SpeechDetailData.rows，totalCount 可用于完整性判断；PlaybackContext 只有单集及服务器，PlayerViewModel 的结束处理只保存 completed。新增队列模型及隔离快照存储，扩展上下文可选字段，接入系列入口／完整页／会话。无新依赖、部署或签名修改。M3 首页 UI 与 M4 搜索不在本阶段，但输入快照独立于后续筛选。

用户持续目标已授权 M1～M4 实施、review／修复及本地提交；不 push／PR／发布／主规格同步／归档。设备和 UI 门槛不足时只记 In Verification。
