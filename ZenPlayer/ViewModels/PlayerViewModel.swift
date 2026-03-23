//
//  PlayerViewModel.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/22.
//

import Foundation
import AVFoundation
#if os(iOS)
import MediaPlayer
#endif

enum PlaybackMediaType: String, CaseIterable, Identifiable, Codable, Hashable {
    case audio
    case video

    var id: String { rawValue }

    var isVideo: Bool {
        self == .video
    }
}

/// 播放上下文：单集 + 服务器地址，用于导航传递
struct PlaybackContext: Codable, Identifiable, Hashable {
    let episode: EpisodeItem
    let serverUrl: String
    let preferredMediaType: PlaybackMediaType?

    init(
        episode: EpisodeItem,
        serverUrl: String,
        preferredMediaType: PlaybackMediaType? = nil
    ) {
        self.episode = episode
        self.serverUrl = serverUrl
        self.preferredMediaType = preferredMediaType
    }

    var id: Int { episode.id }

    private enum CodingKeys: String, CodingKey {
        case episode
        case serverUrl
        case preferredMediaType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episode = try container.decode(EpisodeItem.self, forKey: .episode)
        serverUrl = try container.decode(String.self, forKey: .serverUrl)
        preferredMediaType = try container.decodeIfPresent(PlaybackMediaType.self, forKey: .preferredMediaType)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(episode, forKey: .episode)
        try container.encode(serverUrl, forKey: .serverUrl)
        try container.encodeIfPresent(preferredMediaType, forKey: .preferredMediaType)
    }
}

/// 播放 ViewModel：解析播放 URL（本地优先），管理 AVPlayer
@MainActor
@Observable
final class PlayerViewModel {

    private enum StorageKeys {
        static let denoiseLevel = "player.denoiseLevel"
    }

    enum DenoiseLevel: Int, CaseIterable {
        case original = 0
        case level25 = 25
        case level50 = 50
        case level75 = 75
        case level100 = 100

        var strength: Float {
            Float(rawValue) / 100.0
        }

        var isEnabled: Bool {
            self != .original
        }

        var label: String {
            switch self {
            case .original:
                return L10n.string(.playerOriginal)
            case .level25:
                return "25%"
            case .level50:
                return "50%"
            case .level75:
                return "75%"
            case .level100:
                return "100%"
            }
        }
    }

    /// 解析后的播放 URL（本地优先）
    var playbackURL: URL?

    /// 供视图绑定的播放器实例
    var player: AVPlayer?

    /// 是否为视频（用于决定使用视频或音频播放器）
    var isVideo: Bool = false

    /// 当前选择的媒体类型
    var selectedMediaType: PlaybackMediaType = .video

    /// 当前讲集可切换的媒体类型
    private(set) var availableMediaTypes: [PlaybackMediaType] = []

    var canSwitchMediaType: Bool {
        availableMediaTypes.count > 1
    }

    /// 解析错误信息
    var errorMessage: String?

    /// 是否正在准备播放（用于控制加载态与错误态展示时机）
    var isPreparingPlayback = false

    /// 降噪强度档位（播放中可动态生效）
    var denoiseLevel: DenoiseLevel = .original {
        didSet {
            UserDefaults.standard.set(denoiseLevel.rawValue, forKey: StorageKeys.denoiseLevel)
            denoiseTapProcessor?.setEnabled(denoiseLevel.isEnabled)
            denoiseTapProcessor?.updateStrength(denoiseLevel.strength)
        }
    }

    /// 音量放大倍数（播放中可动态生效）
    var amplificationMultiplier: Double = 1.0 {
        didSet {
            let clamped = Self.clampAmplification(amplificationMultiplier)
            if abs(clamped - amplificationMultiplier) > 0.0001 {
                amplificationMultiplier = clamped
                return
            }
            denoiseTapProcessor?.updateGainMultiplier(Float(amplificationMultiplier))
        }
    }

    private let downloadManager = DownloadManager.shared
    private let recentPlaybackStore = RecentPlaybackStore.shared
    private var denoiseTapProcessor: AVPlayerDenoiseTapProcessor?
    private var currentEpisode: EpisodeItem?
    private var currentServerURL: String?
    private var activePlaybackContext: PlaybackContext?
    private let playbackProgressSaveInterval: Double = 5
    private var shouldPersistPlaybackProgress = false
    private var lastPersistedPlaybackSecond: Double = 0

    init() {
        if let stored = UserDefaults.standard.object(forKey: StorageKeys.denoiseLevel) as? Int,
           let level = DenoiseLevel(rawValue: stored) {
            denoiseLevel = level
        }
    }

    @ObservationIgnored
    private var playbackTimeObserverToken: Any?
    @ObservationIgnored
    private var playbackCompletionObserver: NSObjectProtocol?
#if os(iOS)
    @ObservationIgnored
    private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored
    private var routeChangeObserver: NSObjectProtocol?
    @ObservationIgnored
    private var playCommandTarget: Any?
    @ObservationIgnored
    private var pauseCommandTarget: Any?
    @ObservationIgnored
    private var toggleCommandTarget: Any?
    @ObservationIgnored
    private var seekCommandTarget: Any?
    private var nowPlayingBaseInfo: [String: Any] = [:]
#endif

    /// 统一准备播放：先解析 URL，再构建带降噪回退能力的 AVPlayer
    /// - Parameters:
    ///   - episode: 单集
    ///   - serverUrl: 服务器根地址
    ///   - preferVideo: 若同时有 mp3 和 mp4，true 表示优先视频
    func preparePlayback(context: PlaybackContext) async {
        await preparePlayback(
            episode: context.episode,
            serverUrl: context.serverUrl,
            preferredMediaType: context.preferredMediaType
        )
    }

    /// 统一准备播放：先解析 URL，再构建带降噪回退能力的 AVPlayer
    /// - Parameters:
    ///   - episode: 单集
    ///   - serverUrl: 服务器根地址
    ///   - preferVideo: 若同时有 mp3 和 mp4，true 表示优先视频
    func preparePlayback(episode: EpisodeItem, serverUrl: String, preferVideo: Bool = true) async {
        let preferredMediaType: PlaybackMediaType = preferVideo ? .video : .audio
        await preparePlayback(episode: episode, serverUrl: serverUrl, preferredMediaType: preferredMediaType)
    }

    /// 统一准备播放：先解析 URL，再构建带降噪回退能力的 AVPlayer
    /// - Parameters:
    ///   - episode: 单集
    ///   - serverUrl: 服务器根地址
    ///   - preferredMediaType: 首选媒体类型
    private func preparePlayback(
        episode: EpisodeItem,
        serverUrl: String,
        preferredMediaType: PlaybackMediaType?
    ) async {
        currentEpisode = episode
        currentServerURL = serverUrl
        availableMediaTypes = supportedMediaTypes(for: episode)

        guard let mediaType = initialMediaType(preferred: preferredMediaType) else {
            stopPlayback()
            errorMessage = L10n.string(.errorNoPlayableAddress)
            playbackURL = nil
            isVideo = false
            isPreparingPlayback = false
            return
        }

        selectedMediaType = mediaType
        await reloadCurrentPlayback()
    }

    func switchMediaType(to mediaType: PlaybackMediaType) async {
        guard availableMediaTypes.contains(mediaType) else { return }
        guard mediaType != selectedMediaType || player == nil else { return }

        selectedMediaType = mediaType
        await reloadCurrentPlayback()
    }

    private func reloadCurrentPlayback() async {
        guard let episode = currentEpisode, let serverUrl = currentServerURL else { return }
        let playbackContext = PlaybackContext(
            episode: episode,
            serverUrl: serverUrl,
            preferredMediaType: selectedMediaType
        )
        let resumePositionSeconds = recentPlaybackStore.record(for: playbackContext)?.restorableResumePositionSeconds ?? 0
        isPreparingPlayback = true
        errorMessage = nil
        stopPlayback()
        isPreparingPlayback = true
        shouldPersistPlaybackProgress = false
        lastPersistedPlaybackSecond = 0
        resolvePlaybackURL(episode: episode, serverUrl: serverUrl, mediaType: selectedMediaType)
        guard let url = playbackURL else {
            isPreparingPlayback = false
            return
        }
#if os(iOS)
        configureAudioSessionForPlayback(isVideo: isVideo)
        setupAudioSessionObserversIfNeeded()
#endif
        await buildPlayer(for: url, episode: episode)
        if player != nil {
            activePlaybackContext = playbackContext
            recentPlaybackStore.recordPlayback(playbackContext)
            await restorePlaybackPositionIfNeeded(to: resumePositionSeconds)
        }
        isPreparingPlayback = false
    }

    /// 停止并释放当前播放链路资源
    func stopPlayback() {
        persistCurrentPlaybackProgress(force: true)
        stopPlaybackObservation()
        isPreparingPlayback = false
        player?.pause()
        player = nil
        denoiseTapProcessor = nil
        activePlaybackContext = nil
        shouldPersistPlaybackProgress = false
        lastPersistedPlaybackSecond = 0
#if os(iOS)
        clearNowPlaying()
        removeRemoteCommandTargets()
        removeAudioSessionObservers()
        deactivateAudioSession()
#endif
    }

    /// 根据上下文解析播放 URL
    /// - Parameters:
    ///   - episode: 单集
    ///   - serverUrl: 服务器根地址
    ///   - mediaType: 当前要播放的媒体类型
    func resolvePlaybackURL(episode: EpisodeItem, serverUrl: String, mediaType: PlaybackMediaType) {
        errorMessage = nil
        isVideo = mediaType.isVideo
        playbackURL = nil
        selectedMediaType = mediaType

        switch mediaType {
        case .audio:
            playbackURL = resolveAudioPlaybackURL(for: episode, serverUrl: serverUrl)
        case .video:
            playbackURL = resolveVideoPlaybackURL(for: episode, serverUrl: serverUrl)
        }

        if playbackURL == nil {
            errorMessage = L10n.string(.errorNoPlayableAddress)
        }
    }

    private func initialMediaType(preferred: PlaybackMediaType?) -> PlaybackMediaType? {
        if let preferred, availableMediaTypes.contains(preferred) {
            return preferred
        }
        if availableMediaTypes.contains(.video) {
            return .video
        }
        if availableMediaTypes.contains(.audio) {
            return .audio
        }
        return nil
    }

    private func supportedMediaTypes(for episode: EpisodeItem) -> [PlaybackMediaType] {
        var mediaTypes: [PlaybackMediaType] = []
        if hasAudioSource(for: episode) {
            mediaTypes.append(.audio)
        }
        if hasVideoSource(for: episode) {
            mediaTypes.append(.video)
        }
        return mediaTypes
    }

    private func hasAudioSource(for episode: EpisodeItem) -> Bool {
        if verifiedLocalURL(for: episode.id, type: .mp3) != nil {
            return true
        }
        if let mp3URL = episode.mp3Url, !mp3URL.isEmpty {
            return true
        }
        if hasFallbackAudioSource(for: episode) {
            return true
        }
        return false
    }

    private func hasVideoSource(for episode: EpisodeItem) -> Bool {
        if verifiedLocalURL(for: episode.id, type: .mp4) != nil {
            return true
        }
        if !episode.mp4Url.isEmpty, !looksLikeAudioPath(episode.mp4Url) {
            return true
        }
        if !episode.vodUrl.isEmpty, !looksLikeAudioPath(episode.vodUrl) {
            return true
        }
        return false
    }

    private func resolveAudioPlaybackURL(for episode: EpisodeItem, serverUrl: String) -> URL? {
        if let localURL = verifiedLocalURL(for: episode.id, type: .mp3) {
            return localURL
        }
        if let mp3 = episode.mp3Url, !mp3.isEmpty {
            return URL(string: mp3)
        }
        if let fallbackURL = resolveFallbackAudioPlaybackURL(for: episode, serverUrl: serverUrl) {
            return fallbackURL
        }
        return nil
    }

    private func resolveVideoPlaybackURL(for episode: EpisodeItem, serverUrl: String) -> URL? {
        if let localURL = verifiedLocalURL(for: episode.id, type: .mp4) {
            return localURL
        }
        if !episode.mp4Url.isEmpty {
            return remoteVideoURL(serverUrl: serverUrl, path: episode.mp4Url)
        }
        if !episode.vodUrl.isEmpty {
            return URL(string: episode.vodUrl)
        }
        return nil
    }

    private func hasFallbackAudioSource(for episode: EpisodeItem) -> Bool {
        looksLikeAudioPath(episode.mp4Url) || looksLikeAudioPath(episode.vodUrl)
    }

    private func resolveFallbackAudioPlaybackURL(for episode: EpisodeItem, serverUrl: String) -> URL? {
        if looksLikeAudioPath(episode.vodUrl), let url = URL(string: episode.vodUrl) {
            return url
        }
        if looksLikeAudioPath(episode.mp4Url) {
            return remoteVideoURL(serverUrl: serverUrl, path: episode.mp4Url)
        }
        return nil
    }

    private func remoteVideoURL(serverUrl: String, path: String) -> URL? {
        let normalizedServerURL = serverUrl.hasSuffix("/") ? serverUrl : serverUrl + "/"
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: normalizedServerURL + normalizedPath)
    }

    private func looksLikeAudioPath(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return (value as NSString).pathExtension.lowercased() == "mp3"
    }

    /// 二次校验本地文件存在，避免映射残留导致播放失败。
    private func verifiedLocalURL(for episodeId: Int, type: DownloadType) -> URL? {
        guard let localURL = downloadManager.completedFileURL(for: episodeId, type: type) else { return nil }
        guard FileManager.default.fileExists(atPath: localURL.path) else { return nil }
        return localURL
    }

    private func buildPlayer(for url: URL, episode: EpisodeItem) async {
        let item = AVPlayerItem(url: url)
        let tap = AVPlayerDenoiseTapProcessor(
            strength: denoiseLevel.strength,
            enabled: denoiseLevel.isEnabled
        )
        do {
            try await tap.attach(to: item)
            tap.updateStrength(denoiseLevel.strength)
            tap.updateGainMultiplier(Float(amplificationMultiplier))
            denoiseTapProcessor = tap
            player = AVPlayer(playerItem: item)
        } catch {
            // Tap 失败时回退原声直通，优先保证可播放。
            denoiseTapProcessor = nil
            player = AVPlayer(url: url)
        }

        setupPlaybackObservation()
#if os(iOS)
        setupRemoteCommandCenter()
        setupNowPlayingInfo(episode: episode)
#endif
    }

    private func setupPlaybackObservation() {
        guard let player else { return }
        stopPlaybackObservation()
        playbackTimeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.handlePlaybackTick(currentTimeSeconds: time.seconds)
            }
        }

        if let item = player.currentItem {
            playbackCompletionObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handlePlaybackDidFinish()
                }
            }
        }
    }

    private func stopPlaybackObservation() {
        if let player, let token = playbackTimeObserverToken {
            player.removeTimeObserver(token)
        }
        playbackTimeObserverToken = nil

        if let playbackCompletionObserver {
            NotificationCenter.default.removeObserver(playbackCompletionObserver)
            self.playbackCompletionObserver = nil
        }
    }

    private func handlePlaybackTick(currentTimeSeconds: Double) {
#if os(iOS)
        updateNowPlayingPlaybackState()
#endif
        persistPlaybackProgressIfNeeded(currentTimeSeconds: currentTimeSeconds)
    }

    private func handlePlaybackDidFinish() {
        guard let context = activePlaybackContext else { return }
        recentPlaybackStore.markPlaybackCompleted(for: context)
        lastPersistedPlaybackSecond = context.episode.playbackDurationSeconds
        shouldPersistPlaybackProgress = true
#if os(iOS)
        updateNowPlayingPlaybackState()
#endif
    }

    private func restorePlaybackPositionIfNeeded(to resumePositionSeconds: Double) async {
        guard let player else {
            shouldPersistPlaybackProgress = true
            return
        }

        let clampedResumePosition = max(0, resumePositionSeconds)
        lastPersistedPlaybackSecond = clampedResumePosition

        guard clampedResumePosition > 0 else {
            shouldPersistPlaybackProgress = true
            return
        }

        await withCheckedContinuation { continuation in
            let targetTime = CMTime(seconds: clampedResumePosition, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.lastPersistedPlaybackSecond = clampedResumePosition
                    self?.shouldPersistPlaybackProgress = true
#if os(iOS)
                    self?.updateNowPlayingPlaybackState()
#endif
                    continuation.resume()
                }
            }
        }
    }

    private func persistCurrentPlaybackProgress(force: Bool) {
        guard let currentTimeSeconds = player?.currentTime().seconds else { return }
        persistPlaybackProgress(currentTimeSeconds: currentTimeSeconds, force: force)
    }

    private func persistPlaybackProgressIfNeeded(currentTimeSeconds: Double) {
        persistPlaybackProgress(currentTimeSeconds: currentTimeSeconds, force: false)
    }

    private func persistPlaybackProgress(currentTimeSeconds: Double, force: Bool) {
        guard shouldPersistPlaybackProgress else { return }
        guard let context = activePlaybackContext else { return }
        guard currentTimeSeconds.isFinite else { return }

        let boundedTime: Double
        if context.episode.playbackDurationSeconds > 0 {
            boundedTime = min(max(0, currentTimeSeconds), context.episode.playbackDurationSeconds)
        } else {
            boundedTime = max(0, currentTimeSeconds)
        }

        guard force || abs(boundedTime - lastPersistedPlaybackSecond) >= playbackProgressSaveInterval else {
            return
        }

        recentPlaybackStore.updateProgress(for: context, resumePositionSeconds: boundedTime)
        lastPersistedPlaybackSecond = boundedTime
    }

#if os(iOS)
    /// 后台播放依赖 AVAudioSession.playback。
    private func configureAudioSessionForPlayback(isVideo: Bool) {
        let session = AVAudioSession.sharedInstance()
        let preferredMode: AVAudioSession.Mode = isVideo ? .moviePlayback : .spokenAudio
        let attempts: [(mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)] = [
            (preferredMode, [.allowAirPlay, .allowBluetoothA2DP]),
            (preferredMode, []),
            (.default, [])
        ]

        var didSetCategory = false
        for attempt in attempts {
            do {
                try session.setCategory(.playback, mode: attempt.mode, options: attempt.options)
                didSetCategory = true
                break
            } catch {
                continue
            }
        }

        guard didSetCategory else {
            // 音频会话异常不应打断播放页加载态，避免短暂误报“无法播放”。
            return
        }

        do {
            try session.setActive(true)
        } catch {
            // 音频会话激活失败时静默降级，避免影响页面主流程。
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // 停播时的会话释放失败不影响主流程。
        }
    }

    // MARK: - 锁屏信息与远程控制

    private func setupNowPlayingInfo(episode: EpisodeItem) {
        nowPlayingBaseInfo = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: "净宗学院",
            MPMediaItemPropertyPlaybackDuration: episode.playbackDurationSeconds
        ]
        updateNowPlayingPlaybackState()
    }

    private func updateNowPlayingPlaybackState() {
        guard let player else { return }
        var info = nowPlayingBaseInfo
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        nowPlayingBaseInfo = [:]
    }

    private func setupRemoteCommandCenter() {
        removeRemoteCommandTargets()
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        playCommandTarget = commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.play()
                self?.updateNowPlayingPlaybackState()
            }
            return .success
        }

        pauseCommandTarget = commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.pause()
                self?.updateNowPlayingPlaybackState()
            }
            return .success
        }

        toggleCommandTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.player?.rate == 0 {
                    self.player?.play()
                } else {
                    self.player?.pause()
                }
                self.updateNowPlayingPlaybackState()
            }
            return .success
        }

        seekCommandTarget = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in
                let target = CMTime(seconds: event.positionTime, preferredTimescale: 600)
                self?.player?.seek(to: target)
                self?.updateNowPlayingPlaybackState()
            }
            return .success
        }
    }

    private func removeRemoteCommandTargets() {
        let commandCenter = MPRemoteCommandCenter.shared()
        if let playCommandTarget {
            commandCenter.playCommand.removeTarget(playCommandTarget)
        }
        if let pauseCommandTarget {
            commandCenter.pauseCommand.removeTarget(pauseCommandTarget)
        }
        if let toggleCommandTarget {
            commandCenter.togglePlayPauseCommand.removeTarget(toggleCommandTarget)
        }
        if let seekCommandTarget {
            commandCenter.changePlaybackPositionCommand.removeTarget(seekCommandTarget)
        }
        playCommandTarget = nil
        pauseCommandTarget = nil
        toggleCommandTarget = nil
        seekCommandTarget = nil
    }

    // MARK: - 音频中断/路由变化

    private func setupAudioSessionObserversIfNeeded() {
        let center = NotificationCenter.default
        if interruptionObserver == nil {
            interruptionObserver = center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleAudioInterruption(notification)
                }
            }
        }
        if routeChangeObserver == nil {
            routeChangeObserver = center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor [weak self] in
                    self?.handleRouteChange(notification)
                }
            }
        }
    }

    private func removeAudioSessionObservers() {
        let center = NotificationCenter.default
        if let interruptionObserver {
            center.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        if let routeChangeObserver {
            center.removeObserver(routeChangeObserver)
            self.routeChangeObserver = nil
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
            return
        }
        switch type {
        case .began:
            player?.pause()
            updateNowPlayingPlaybackState()
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if options.contains(.shouldResume) {
                player?.play()
            }
            updateNowPlayingPlaybackState()
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonRaw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else {
            return
        }
        // 耳机拔出时自动暂停，避免外放打扰。
        if reason == .oldDeviceUnavailable {
            player?.pause()
            updateNowPlayingPlaybackState()
        }
    }
#endif

    static let supportedAmplificationOptions: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]

    static func amplificationLabel(_ value: Double) -> String {
        switch value {
        case 1.0: return "1x"
        case 2.0: return "2x"
        case 3.0: return "3x"
        case 4.0: return "4x"
        case 5.0: return "5x"
        default: return String(format: "%.2fx", value)
        }
    }

    private static func clampAmplification(_ value: Double) -> Double {
        min(5.0, max(1.0, value))
    }
}

extension EpisodeItem {
    var fallbackMediaType: PlaybackMediaType {
        if (mp4Url as NSString).pathExtension.lowercased() == "mp3"
            || (vodUrl as NSString).pathExtension.lowercased() == "mp3" {
            return .audio
        }
        if isVideo {
            return .video
        }
        if let mp3Url, !mp3Url.isEmpty {
            return .audio
        }
        return .audio
    }
}
