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

/// 播放上下文：单集 + 服务器地址，用于导航传递
struct PlaybackContext: Identifiable, Hashable {
    let episode: EpisodeItem
    let serverUrl: String

    var id: Int { episode.id }
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

    /// 解析错误信息
    var errorMessage: String?

    /// 是否正在准备播放（用于控制加载态与错误态展示时机）
    var isPreparingPlayback = false

    /// 降噪强度档位（播放中可动态生效）
    var denoiseLevel: DenoiseLevel = .level100 {
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
    private var denoiseTapProcessor: AVPlayerDenoiseTapProcessor?

#if os(iOS)
    @ObservationIgnored
    private var playbackTimeObserverToken: Any?
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

    init() {
        if let stored = UserDefaults.standard.object(forKey: StorageKeys.denoiseLevel) as? Int,
           let level = DenoiseLevel(rawValue: stored) {
            denoiseLevel = level
        }
    }

    /// 统一准备播放：先解析 URL，再构建带降噪回退能力的 AVPlayer
    /// - Parameters:
    ///   - episode: 单集
    ///   - serverUrl: 服务器根地址
    ///   - preferVideo: 若同时有 mp3 和 mp4，true 表示优先视频
    func preparePlayback(episode: EpisodeItem, serverUrl: String, preferVideo: Bool = true) async {
        isPreparingPlayback = true
        errorMessage = nil
        stopPlayback()
        resolvePlaybackURL(episode: episode, serverUrl: serverUrl, preferVideo: preferVideo)
        guard let url = playbackURL else {
            isPreparingPlayback = false
            return
        }
#if os(iOS)
        configureAudioSessionForPlayback(isVideo: isVideo)
        setupAudioSessionObserversIfNeeded()
#endif
        await buildPlayer(for: url, episode: episode)
        isPreparingPlayback = false
    }

    /// 停止并释放当前播放链路资源
    func stopPlayback() {
#if os(iOS)
        stopPlaybackObservation()
#endif
        isPreparingPlayback = false
        player?.pause()
        player = nil
        denoiseTapProcessor = nil
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
    ///   - preferVideo: 若同时有 mp3 和 mp4，true 表示优先视频
    func resolvePlaybackURL(episode: EpisodeItem, serverUrl: String, preferVideo: Bool = true) {
        errorMessage = nil
        isVideo = episode.isVideo
        playbackURL = nil

        if preferVideo, episode.isVideo {
            // 视频：优先本地 mp4
            if let localURL = verifiedLocalURL(for: episode.id, type: .mp4) {
                playbackURL = localURL
                return
            }
            if !episode.mp4Url.isEmpty {
                let remoteURLString = serverUrl.hasSuffix("/") ? serverUrl + episode.mp4Url : serverUrl + "/" + episode.mp4Url
                playbackURL = URL(string: remoteURLString)
                return
            }
            if !episode.vodUrl.isEmpty {
                playbackURL = URL(string: episode.vodUrl)
                return
            }
        }

        // 音频：优先本地 mp3
        if let localURL = verifiedLocalURL(for: episode.id, type: .mp3) {
            playbackURL = localURL
            isVideo = false
            return
        }
        if let mp3 = episode.mp3Url, !mp3.isEmpty {
            playbackURL = URL(string: mp3)
            isVideo = false
            return
        }

        // 若 preferVideo 为 false 或没有音频，再尝试视频
        if !preferVideo || playbackURL == nil, episode.isVideo {
            if let localURL = verifiedLocalURL(for: episode.id, type: .mp4) {
                playbackURL = localURL
                isVideo = true
                return
            }
            if !episode.mp4Url.isEmpty {
                let remoteURLString = serverUrl.hasSuffix("/") ? serverUrl + episode.mp4Url : serverUrl + "/" + episode.mp4Url
                playbackURL = URL(string: remoteURLString)
                isVideo = true
                return
            }
            if !episode.vodUrl.isEmpty {
                playbackURL = URL(string: episode.vodUrl)
                isVideo = true
                return
            }
        }

        errorMessage = L10n.string(.errorNoPlayableAddress)
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

#if os(iOS)
        setupPlaybackObservation()
        setupRemoteCommandCenter()
        setupNowPlayingInfo(episode: episode)
#endif
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
            MPMediaItemPropertyPlaybackDuration: Double(episode.duration) / 1000.0
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

    // MARK: - 播放状态观察

    private func setupPlaybackObservation() {
        guard let player else { return }
        stopPlaybackObservation()
        playbackTimeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNowPlayingPlaybackState()
            }
        }
    }

    private func stopPlaybackObservation() {
        guard let player, let token = playbackTimeObserverToken else { return }
        player.removeTimeObserver(token)
        playbackTimeObserverToken = nil
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
