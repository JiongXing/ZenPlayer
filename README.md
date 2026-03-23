# ZenPlayer

一款面向 **传统文化讲座** 场景的 Apple 平台播放器，当前支持在 **iPhone / macOS** 上浏览讲座分类、播放单集内容、离线下载，并针对人声内容提供可调节的降噪与音量增强能力。

---

## 技术方案概览

- **单代码库跨端复用**：使用纯 SwiftUI 覆盖 iPhone 与 macOS，主要以 `NavigationStack` 组织导航，并在 iOS regular width 下保留双栏布局适配。
- **本地化自动跟随系统**：当前仅支持简体中文 / 繁体中文，启动时按系统语言自动匹配，并在系统语言变更时同步刷新。
- **播放链路稳定优先**：本地文件优先播放，远端地址作为回退；音频处理失败时自动降级为原声直通，优先保证可播放。
- **人声增强方案**：基于 `AVPlayerItem` Audio Tap + 本地 `RNNoise` 实现实时降噪，并支持播放中动态调节降噪强度与音量放大倍数。
- **下载方案（iOS 完整、macOS 兼容）**：iOS 使用后台 `URLSession` + 断点续传 + 清单恢复；macOS 使用 `NSSavePanel` + 直链下载作为兼容路径。
- **面向真实脏数据的兼容策略**：对 API 中音/视频地址字段不一致、日期格式不统一等情况做了业务级兜底。

---

## 功能概览

- 首页浏览一级类目（Category）
- 二级类目中按编号/日期排序浏览系列（Series）
- 单集列表查看时长、体积，支持音频/视频下载
- 播放页支持视频/音频播放、锁屏控制（iOS）、PiP（iOS）、人声降噪与音量增强
- 下载完成后优先本地播放；iOS 侧可通过系统分享导出文件
- 简体 / 繁体中文自动跟随系统语言

---

## 技术栈

- **语言**：Swift 5
- **UI**：SwiftUI（纯 SwiftUI，不混用 AppKit 页面）
- **架构**：MVVM + `Services` / `Localization` / `Utilities`
- **并发模型**：`async/await` + `Task` + `@MainActor`
- **网络**：`URLSession`
- **媒体播放**：`AVPlayer` / `AVPlayerViewController`
- **图片加载与缓存**：Kingfisher `8.6.2`
- **调试抓包**：Atlantis `1.34.0`（Debug）
- **音频降噪**：RNNoise（项目内置 C 源码 + Swift 封装）
- **本地化**：`Localizable.xcstrings` + 自定义 `L10n`
- **最低系统版本**：iOS 17+、macOS 14+

---

## 架构设计

### 1) 分层与职责

- `Models`：`Codable + Identifiable/Hashable`，承载 API 数据结构与展示辅助字段。
- `ViewModels`：`@MainActor + @Observable`，维护页面状态（加载、错误、数据）与业务动作。
- `Views`：UI 组件与交互绑定，关注呈现与用户操作，不直接处理网络/下载细节。
- `Services`：网络请求、下载服务、音频处理等可复用能力。
- `Localization`：语言匹配、文案查找与运行时 locale 切换。
- `Utilities`：跨平台适配和布局常量。

### 2) 导航与路由

采用 **值路由（Value-based Navigation）**，在 `ContentView` 统一注册。当前主路径为 `NavigationStack`，iOS regular width 下会切换到 `NavigationSplitView`：

- `CategoryItem -> CategoryDetailView`
- `SeriesItem -> SeriesDetailView`
- `PlaybackContext -> PlayerView`

这样可以让跳转链路类型安全，并降低页面间耦合。

### 3) 关键数据流

`HomeView` 加载一级类目 -> 进入 `CategoryDetailView` 加载系列 -> 进入 `SeriesDetailView` 加载单集 -> `EpisodeRowView` 触发播放或下载。

---

## 核心技术方案详解

### 1) 统一网络层（APIService）

- 泛型 `request<T: Codable>` 统一处理请求、解码、业务码校验。
- `APIResponse<T>` 统一响应壳，`APIError` 统一错误语义。
- 标准化请求头（含 `userkey`、`Accept-Language`）、超时、日志输出，便于问题排查。
- `JSONDecoder.convertFromSnakeCase` 降低模型映射成本。

### 2) 播放链路：本地优先 + 可降级

`PlayerViewModel` 的核心策略：

- **播放地址解析优先级**：
  - 视频：本地 mp4 -> 远端 mp4 -> vod
  - 音频：本地 mp3 -> 远端 mp3
- **可用性保障**：
  - 本地路径二次校验，自动剔除失效映射
  - Audio Tap 附加失败时，自动降级到原生 `AVPlayer(url:)`
- **iOS 体验增强**：
  - `AVAudioSession` 分类与激活
  - 锁屏信息（Now Playing）与远程控制命令（播放/暂停/拖动）
  - 音频中断与路由变化监听（如耳机拔出自动暂停）

### 3) 人声降噪：AVPlayer Audio Tap + RNNoise

- 在 `AVPlayerItem` 上挂载 `MTAudioProcessingTap`，对播放中的 PCM 数据实时处理。
- 将多声道统一到 mono，按 RNNoise 固定 480 帧处理，再回写到各声道。
- 对非 48k 采样率音频执行重采样，并通过 pending queue 减少边界伪影。
- 提供 0%~100% 降噪档位与 1x~5x 音量增强，并可在播放中动态生效。

### 4) 下载系统（iOS 优先，macOS 兼容）

`DownloadManager` 在 iOS 侧采用后台下载方案：

- `URLSessionConfiguration.background` + 稳定 Session Identifier
- 暂停时保存 `resumeData`，支持断点续传
- `download_manifest.json` 持久化任务记录（状态、进度、目标路径、resumeData 路径）
- App 冷启动后通过 `getAllTasks` 重新挂接系统托管任务
- resumeData 无效时自动降级为全量重下，避免任务“卡死”
- 本地文件缺失时自动清理失效记录，保持状态一致性

macOS 侧保留兼容路径：

- 使用 `NSSavePanel` 由用户选择保存位置
- 通过直链下载写入本地文件
- 暂停会退化为取消，当前不做下载状态持久化恢复

### 5) 本地化与语言跟随

- 当前支持 `zh-Hans` / `zh-Hant`
- 启动时根据 `Locale.preferredLanguages` 自动选择最佳匹配
- 系统语言变化时通过 `NSLocale.currentLocaleDidChangeNotification` 自动刷新文案

### 6) 脏数据与兼容性处理

- 音频系列中后端偶发将音频地址填入 `mp4_url`，下载与播放层均有兜底逻辑。
- 日期排序支持 `1983`、`1984.12`、`1994.6.4`、`1993.10-1985.10` 等多格式。
- iPhone / macOS 采用不同布局密度与交互细节，减少跨端体验割裂。

---

## 目录结构

```text
ZenPlayer/
├── ZenPlayerApp.swift               # App 入口，配置 Kingfisher、导航样式、iOS AppDelegate 桥接
├── ContentView.swift                # 根导航容器与值路由注册
├── Localization/                    # 语言匹配、L10n 封装与本地化配置
├── Models/                          # APIResponse / Category / Series / Episode
├── ViewModels/                      # Home / CategoryDetail / SeriesDetail / Player / DownloadManager
├── Views/                           # 页面与行组件（Home、Detail、Player、EpisodeRow 等）
├── Services/                        # APIService / 下载服务 / AVPlayerDenoiseTapProcessor / RNNoiseProcessor
├── Utilities/                       # LayoutConstants / OrientationManager / PlatformImage
├── Libraries/RNNoise/               # RNNoise C 源码与头文件
└── Localizable.xcstrings            # 本地化字符串资源
```

---
