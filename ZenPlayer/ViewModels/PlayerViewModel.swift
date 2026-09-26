//
//  PlayerViewModel.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/22.
//

import Foundation
import AVFoundation
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import MediaPlayer
import UIKit
#endif

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
    var selectedMediaType: PlaybackMediaType = .audio

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
            defaults.set(denoiseLevel.rawValue, forKey: StorageKeys.denoiseLevel)
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

    private let defaults: UserDefaults
    private let localFile: (Int, PlaybackMediaType) -> URL?
    private let makeAudioProcessor: (Float, Bool) -> any PlaybackAudioProcessing
    let progressStore: PlaybackProgressStore
    let queueStore: QueueSnapshotStore
    private let isOffline: () -> Bool
    private(set) var queue = PlaybackQueueState()
    private(set) var isRestoringQueue = false
    private(set) var mediaSelectionNotice: String?
    @ObservationIgnored private var queueRestoreTask: Task<Void, Never>?
    private var queueSelection = UUID()
    var canPlayPrevious: Bool { queue.context(offset: -1, preferred: selectedMediaType) != nil }
    var canPlayNext: Bool { queue.context(offset: 1, preferred: selectedMediaType) != nil }
    var queueStatus: String {
        if isRestoringQueue { return L10n.string(.queueRestoring) }
        guard let snapshot = queue.snapshot else { return L10n.string(.queueUnavailable) }
        return L10n.string(snapshot.isComplete ? .queueComplete : .queuePartial, Int64(snapshot.episodes.count))
    }

    private var denoiseTapProcessor: (any PlaybackAudioProcessing)?
    private var currentEpisode: EpisodeItem?
    private var currentServerURL: String?
    private var activePlaybackContext: PlaybackContext?
    private var progressGate = PlaybackProgressGate()
    private let uptime: () -> Double
    private var pendingResumePosition: Double = 0
    private(set) var session = PlaybackSessionState()
    private(set) var currentPosition: Double = 0
    private(set) var showsLoading = false
    @ObservationIgnored private var preparationTask: Task<Void, Never>?
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    @ObservationIgnored private var controlObservation: NSKeyValueObservation?
    var currentContext: PlaybackContext? { session.context }
    var isPlaying: Bool { session.wantsPlayback && session.phase != .failed && session.phase != .ended }
    var hasSession: Bool { session.hasSession }

    var sessionStatus: String {
        switch session.phase {
        case .idle: return L10n.string(.sessionStopped)
        case .preparing, .buffering: return showsLoading ? L10n.string(.playerLoading) : L10n.string(.sessionPreparing)
        case .playing: return L10n.string(.sessionPlaying)
        case .paused: return L10n.string(.sessionPaused)
        case .ended: return L10n.string(.progressCompleted)
        case .failed: return errorMessage ?? L10n.string(.playerCannotPlay)
        }
    }
    private var restoreAttempted = false
    private var seekInFlight = false
    private var seekRequest = UUID()
    var restoreError = false
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var rateObservation: NSKeyValueObservation?
    @ObservationIgnored private var timeJumpObserver: NSObjectProtocol?
#if os(macOS)
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?
#endif

    init(progressStore: PlaybackProgressStore, queueStore: QueueSnapshotStore, defaults: UserDefaults,
         localFile: @escaping (Int, PlaybackMediaType) -> URL?,
         makeAudioProcessor: @escaping (Float, Bool) -> any PlaybackAudioProcessing,
         isOffline: @escaping () -> Bool,
         uptime: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.progressStore = progressStore
        self.queueStore = queueStore
        self.defaults = defaults
        self.localFile = localFile
        self.makeAudioProcessor = makeAudioProcessor
        self.isOffline = isOffline
        self.uptime = uptime
        if let stored = defaults.object(forKey: StorageKeys.denoiseLevel) as? Int,
           let level = DenoiseLevel(rawValue: stored) {
            denoiseLevel = level
        }
    }

    @ObservationIgnored
    private var playbackTimeObserverToken: Any?
    @ObservationIgnored
    private var playbackCompletionObserver: NSObjectProtocol?
    @ObservationIgnored private var playbackFailureObserver: NSObjectProtocol?
    @ObservationIgnored private var bufferObservation: NSKeyValueObservation?
    private var bufferedThrough: Double = 0
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
    func selectPlayback(_ incoming: PlaybackContext, force: Bool = false, wantsPlayback: Bool = true,
                        snapshot suppliedSnapshot: QueueSnapshot? = nil) {
        let context = PlaybackContext(episode: incoming.episode, serverUrl: incoming.serverUrl,
                                      preferredMediaType: incoming.preferredMediaType,
                                      series: incoming.series ?? progressStore.record(for: incoming)?.context.series)
        guard session.select(context, now: uptime(), force: force, wantsPlayback: wantsPlayback) else { return }
        let snapshot = suppliedSnapshot ?? queueStore.cached(for: context)
        queue.select(context, snapshot: snapshot)
        queueSelection = UUID()
        queueRestoreTask?.cancel()
        isRestoringQueue = snapshot == nil
        mediaSelectionNotice = nil
        if let snapshot { queueStore.register(snapshot) }
        else { restoreQueue(for: context, selection: queueSelection) }
        preparationTask?.cancel()
        releasePlayback()
        currentEpisode = context.episode
        currentServerURL = context.serverUrl
        currentPosition = progressStore.record(for: context)?.resumePosition ?? 0
        availableMediaTypes = supportedMediaTypes(for: context.episode)
        isPreparingPlayback = true
        restoreError = false
        let local = localMediaTypes(for: context.episode)
        guard let mediaType = QueueMediaPolicy.select(preferred: context.preferredMediaType,
                                                     supported: availableMediaTypes, local: local, offline: isOffline()) else {
            failPlayback(message: L10n.string(isOffline() ? .queueOffline : .errorNoPlayableAddress))
            return
        }
        selectedMediaType = mediaType
        if let preferred = context.preferredMediaType, preferred != mediaType {
            mediaSelectionNotice = L10n.string(mediaType == .audio ? .queueFallbackAudio : .queueFallbackVideo)
        }
        let request = session.request
        startMonitoring()
        preparationTask = Task { [weak self] in
            guard let self, self.session.request == request else { return }
            await self.reloadCurrentPlayback()
        }
    }

    private func restoreQueue(for context: PlaybackContext, selection: UUID) {
        queueRestoreTask = Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.queueStore.restore(for: context)
            guard !Task.isCancelled, self.queueSelection == selection, self.session.hasSession else { return }
            self.isRestoringQueue = false
            guard let snapshot, self.queue.attach(snapshot, to: context),
                  let reference = self.queue.context(offset: 0, preferred: self.selectedMediaType)?.series else { return }
            self.session.associateSeries(reference, for: context)
            if let active = self.activePlaybackContext {
                self.activePlaybackContext = PlaybackContext(episode: active.episode, serverUrl: active.serverUrl,
                                                             preferredMediaType: active.preferredMediaType, series: reference)
            }
            self.queueStore.register(snapshot)
        }
    }

    func playAdjacent(_ offset: Int) {
        guard offset == -1 || offset == 1, let context = queue.context(offset: offset, preferred: selectedMediaType) else { return }
        selectPlayback(context, force: true, snapshot: queue.snapshot)
    }

    private func localMediaTypes(for episode: EpisodeItem) -> [PlaybackMediaType] {
        var types: [PlaybackMediaType] = []
        if verifiedLocalURL(for: episode.id, type: .audio) != nil { types.append(.audio) }
        if verifiedLocalURL(for: episode.id, type: .video) != nil { types.append(.video) }
        return types
    }

    func preparePlayback(context: PlaybackContext) async {
        selectPlayback(context)
        await preparationTask?.value
    }

    func pausePlayback() {
        session.pause()
        player?.pause()
        persistCurrentPlaybackProgress(force: true)
#if os(iOS)
        updateNowPlayingPlaybackState()
#endif
    }

    func resumePlayback() {
        if session.phase == .failed {
            retryPlayback()
            return
        }
        if session.phase == .ended {
            if let context = currentContext { selectPlayback(context, force: true, snapshot: queue.snapshot) }
            return
        }
        session.play(now: uptime())
        if progressGate.ready, session.wantsPlayback { player?.play() }
    }

    func togglePlayback() {
        if isPlaying { pausePlayback() } else { resumePlayback() }
    }

    private func startMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self, self.session.hasSession else { return }
                self.showsLoading = self.session.loadingVisible(now: self.uptime())
                if self.session.timedOut(now: self.uptime()) {
                    self.failPlayback(message: L10n.string(.sessionTimedOut))
                    return
                }
            }
        }
    }

    private func failPlayback(message: String, offline: Bool = false) {
        if (offline || isOffline()), let context = currentContext,
           !localMediaTypes(for: context.episode).contains(selectedMediaType),
           let alternate = QueueMediaPolicy.select(preferred: selectedMediaType, supported: availableMediaTypes,
                                                   local: localMediaTypes(for: context.episode), offline: true) {
            let fallback = PlaybackContext(episode: context.episode, serverUrl: context.serverUrl,
                                           preferredMediaType: alternate, series: context.series)
            selectPlayback(fallback, force: true, wantsPlayback: session.wantsPlayback, snapshot: queue.snapshot)
            mediaSelectionNotice = L10n.string(alternate == .audio ? .queueFallbackAudio : .queueFallbackVideo)
            return
        }
        session.fail(request: session.request)
        releasePlayback()
        errorMessage = offline ? L10n.string(.queueOffline) : message
        preparationTask?.cancel()
        monitoringTask?.cancel()
        showsLoading = false
    }

    func switchMediaType(to mediaType: PlaybackMediaType) async {
        guard session.hasSession, availableMediaTypes.contains(mediaType) else { return }
        guard mediaType != selectedMediaType || player == nil else { return }

        selectedMediaType = mediaType
        await reloadCurrentPlayback()
    }

    private func reloadCurrentPlayback() async {
        guard let episode = currentEpisode, let serverUrl = currentServerURL else { return }
        let context = PlaybackContext(episode: episode, serverUrl: serverUrl, preferredMediaType: selectedMediaType, series: currentContext?.series)
        // 切源先抓当前媒体即时位置和播放意图；stop 后才读取最新仓库值。
        let switching = activePlaybackContext.map { RecentPlaybackRecord.recordID(for: $0) == RecentPlaybackRecord.recordID(for: context) } ?? false
        let immediate = switching ? player?.currentTime().seconds : nil
        // 原生暂停的 KVO 可能尚未送达；媒体已恢复时以即时播放器状态为准。
        let wasPlaying: Bool
        if progressGate.ready, let player {
            wasPlaying = player.rate > 0 || player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        } else {
            wasPlaying = session.phase == .failed ? session.retryWantsPlayback : session.wantsPlayback
        }
        let usableImmediate = immediate.flatMap { progressGate.action(token: progressGate.token, position: $0) }
        releasePlayback()
        let stored = progressStore.record(for: context)
        pendingResumePosition = usableImmediate ?? stored?.resumePosition ?? 0
        session.select(context, now: uptime(), force: true, wantsPlayback: wasPlaying)
        startMonitoring()
        let token = progressGate.begin(position: pendingResumePosition, uptime: uptime())
        queue.bindMedia(token)
        isPreparingPlayback = true
        restoreAttempted = false
        restoreError = false
        errorMessage = nil
        resolvePlaybackURL(episode: episode, serverUrl: serverUrl, mediaType: selectedMediaType)
        guard let url = playbackURL else { failPlayback(message: L10n.string(.errorNoPlayableAddress)); return }
#if os(iOS)
        configureAudioSessionForPlayback(isVideo: isVideo)
        setupAudioSessionObserversIfNeeded()
#endif
        await buildPlayer(for: url, episode: episode, token: token)
        guard progressGate.token == token, player != nil else { return }
        activePlaybackContext = PlaybackContext(episode: context.episode, serverUrl: context.serverUrl,
                                                preferredMediaType: context.preferredMediaType, series: currentContext?.series)
        setupPlaybackObservation()
    }

    /// 停止并释放当前播放链路资源
    func stopPlayback() {
        preparationTask?.cancel()
        preparationTask = nil
        monitoringTask?.cancel()
        monitoringTask = nil
        releasePlayback()
        session.stop()
        queue = PlaybackQueueState()
        queueSelection = UUID()
        queueRestoreTask?.cancel()
        queueRestoreTask = nil
        isRestoringQueue = false
        mediaSelectionNotice = nil
        errorMessage = nil
        restoreError = false
        currentEpisode = nil
        currentServerURL = nil
        currentPosition = 0
        playbackURL = nil
        availableMediaTypes = []
        showsLoading = false
    }

    private func releasePlayback() {
        persistCurrentPlaybackProgress(force: true)
        progressGate.invalidate()
        stopPlaybackObservation()
        isPreparingPlayback = false
        player?.pause()
        player = nil
        denoiseTapProcessor = nil
        activePlaybackContext = nil
        restoreAttempted = false
        seekInFlight = false
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
        if verifiedLocalURL(for: episode.id, type: .audio) != nil {
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
        if verifiedLocalURL(for: episode.id, type: .video) != nil {
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
        if let localURL = verifiedLocalURL(for: episode.id, type: .audio) {
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
        if let localURL = verifiedLocalURL(for: episode.id, type: .video) {
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
    private func verifiedLocalURL(for episodeId: Int, type: PlaybackMediaType) -> URL? {
        guard let localURL = localFile(episodeId, type) else { return nil }
        guard FileManager.default.fileExists(atPath: localURL.path) else { return nil }
        return localURL
    }

    private func buildPlayer(for url: URL, episode: EpisodeItem, token: UUID) async {
        let item = AVPlayerItem(url: url)
        let tap = makeAudioProcessor(denoiseLevel.strength, denoiseLevel.isEnabled)
        do {
            try await tap.attach(to: item)
            guard progressGate.token == token, !Task.isCancelled else { return }
            tap.updateStrength(denoiseLevel.strength)
            tap.updateGainMultiplier(Float(amplificationMultiplier))
            denoiseTapProcessor = tap
            player = AVPlayer(playerItem: item)
        } catch {
            guard progressGate.token == token, !Task.isCancelled else { return }
            // Tap 失败时回退原声直通，优先保证可播放。
            denoiseTapProcessor = nil
            player = AVPlayer(url: url)
        }

#if os(iOS)
        setupRemoteCommandCenter()
        setupNowPlayingInfo(episode: episode)
#endif
    }

    private func isCurrent(_ observed: AVPlayer, item: AVPlayerItem, token: UUID) -> Bool {
        player === observed && observed.currentItem === item && progressGate.token == token
    }

    private func setupPlaybackObservation() {
        guard let player, let item = player.currentItem else { return }
        stopPlaybackObservation()
        let token = progressGate.token
        playbackTimeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
        ) { [weak self, weak player, weak item] time in
            Task { @MainActor [weak self, weak player, weak item] in
                guard let self, let player, let item, self.isCurrent(player, item: item, token: token) else { return }
                self.handlePlaybackTick(currentTimeSeconds: time.seconds)
            }
        }
        controlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self, weak player, weak item] _, _ in
            Task { @MainActor [weak self, weak player, weak item] in
                guard let self, let player, let item, self.isCurrent(player, item: item, token: token), self.progressGate.ready else { return }
                switch player.timeControlStatus {
                case .playing:
                    if self.session.interruptionActive { player.pause(); return }
                    if self.session.phase == .ended { self.resumePlayback(); return }
                    if !self.session.wantsPlayback { self.session.play(now: self.uptime()) }
                    self.session.observedPlaying(request: self.session.request, now: self.uptime())
                case .waitingToPlayAtSpecifiedRate:
                    if self.session.interruptionActive { player.pause(); return }
                    if self.session.phase == .ended { self.resumePlayback(); return }
                    self.session.observedWaiting(request: self.session.request, now: self.uptime())
                case .paused:
                    if self.session.phase != .ended { self.session.observedPause() }
                @unknown default: break
                }
            }
        }
        bufferedThrough = 0
        bufferObservation = item.observe(\.loadedTimeRanges, options: [.initial, .new]) { [weak self, weak player, weak item] _, _ in
            Task { @MainActor [weak self, weak player, weak item] in
                guard let self, let player, let item, self.isCurrent(player, item: item, token: token) else { return }
                let position = player.currentTime().seconds
                // 仅当前播放位置所在缓冲段的增长算有效进展。
                let end = item.loadedTimeRanges.map(\.timeRangeValue).filter {
                    $0.start.seconds <= position && CMTimeRangeGetEnd($0).seconds > position
                }.map { CMTimeRangeGetEnd($0).seconds }.max() ?? 0
                if end.isFinite, end > self.bufferedThrough {
                    self.bufferedThrough = end
                    self.session.advanced(request: self.session.request, now: self.uptime())
                }
            }
        }
        playbackFailureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self, weak player, weak item] _ in
            Task { @MainActor [weak self, weak player, weak item] in
                guard let self, let player, let item, self.isCurrent(player, item: item, token: token) else { return }
                self.failPlayback(message: item.error?.localizedDescription ?? L10n.string(.playerCannotPlay), offline: Self.isOfflineError(item.error))
            }
        }
        rateObservation = player.observe(\.rate, options: [.old, .new]) { [weak self, weak player, weak item] _, change in
            let paused = change.newValue == 0 && change.oldValue != 0
            let started = (change.newValue ?? 0) > 0
            Task { @MainActor [weak self, weak player, weak item] in
                guard let self, let player, let item, self.isCurrent(player, item: item, token: token) else { return }
                if started, player.rate > 0 { self.progressGate.playbackStarted(token: token) }
                if paused {
                    self.recordMovement(position: player.currentTime().seconds, playing: true)
                    self.persistCurrentPlaybackProgress(force: true)
                }
            }
        }
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak player, weak item] _, _ in
            Task { @MainActor [weak self, weak player, weak item] in
                guard let self, let player, let item, self.isCurrent(player, item: item, token: token) else { return }
                if item.status == .failed {
                    self.failPlayback(message: item.error?.localizedDescription ?? L10n.string(.playerCannotPlay), offline: Self.isOfflineError(item.error))
                } else if item.status == .readyToPlay, !self.restoreAttempted {
                    self.restoreAttempted = true
                    await self.restorePlaybackPositionIfNeeded(to: self.pendingResumePosition, player: player, item: item, token: token)
                }
            }
        }
        timeJumpObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemTimeJumped, object: item, queue: .main) { [weak self, weak player, weak item] _ in
            MainActor.assumeIsolated {
                guard let self, let player, let item, self.isCurrent(player, item: item, token: token),
                      self.progressGate.ready, !self.seekInFlight, item.status == .readyToPlay else { return }
                let position = player.currentTime().seconds
                self.progressGate.jumped(token: token, position: position)
                self.savePosition(position, explicitSeek: true)
            }
        }
        playbackCompletionObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self, weak player, weak item] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let eventQueueRevision = self.queue.revision
                Task { @MainActor [weak self, weak player, weak item] in
                    guard let self, let player, let item, self.isCurrent(player, item: item, token: token), self.progressGate.ready,
                          let context = self.activePlaybackContext,
                          self.queue.consumeEnd(media: token, revision: self.queue.revision) else { return }
                    let current = player.currentTime().seconds
                    let position = current.isFinite && current >= 0 ? current : self.progressStore.record(for: context)?.positionSeconds ?? 0
                    self.session.ended(request: self.session.request)
                    self.progressGate.ended(token: token)
                    self.progressStore.update(context, position: position, duration: self.mediaDuration, event: .ended)
                    self.progressStore.requestFlush()
                    // 快照迟到不丢弃本集 completed，但不能事后触发自动开播。
                    if self.queue.revision == eventQueueRevision, self.queueStore.autoAdvance,
                       let next = self.queue.context(offset: 1, preferred: self.selectedMediaType) {
                        self.selectPlayback(next, force: true, snapshot: self.queue.snapshot)
                    }
                }
            }
        }
#if os(macOS)
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.persistCurrentPlaybackProgress(force: true)
                self?.progressStore.flushSynchronously()
            }
        }
#endif
    }

    private func stopPlaybackObservation() {
        if let player, let token = playbackTimeObserverToken { player.removeTimeObserver(token) }
        playbackTimeObserverToken = nil
        statusObservation = nil
        rateObservation = nil
        controlObservation = nil
        bufferObservation = nil
        for observer in [playbackCompletionObserver, playbackFailureObserver, timeJumpObserver].compactMap({ $0 }) { NotificationCenter.default.removeObserver(observer) }
        playbackCompletionObserver = nil
        playbackFailureObserver = nil
        timeJumpObserver = nil
#if os(macOS)
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        terminationObserver = nil
#endif
    }

    private var mediaDuration: Double? {
        guard let duration = player?.currentItem?.duration.seconds, duration.isFinite, duration > 0 else { return nil }
        return duration
    }

    private func handlePlaybackTick(currentTimeSeconds: Double) {
#if os(iOS)
        updateNowPlayingPlaybackState()
#endif
        recordMovement(position: currentTimeSeconds, playing: player?.timeControlStatus == .playing)

        if progressGate.ready, progressGate.shouldFlush(uptime: uptime()) {
            progressGate.didRequestFlush(uptime: uptime())
            progressStore.requestFlush()
        }
    }

    private func restorePlaybackPositionIfNeeded(to position: Double, player: AVPlayer, item: AVPlayerItem, token: UUID) async {
        let duration = PlaybackProgress.trustedDuration(mediaDuration, metadata: activePlaybackContext?.episode.playbackDurationSeconds ?? 0)
        let target = min(max(0, position), duration ?? position)
        seekInFlight = true
        let success = await player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        guard isCurrent(player, item: item, token: token) else { return }
        seekInFlight = false
        let actual = player.currentTime().seconds
        progressGate.restored(token: token, success: success && item.status == .readyToPlay && (target == 0 || actual > 0), position: actual)
        restoreError = !progressGate.ready
        isPreparingPlayback = false
        if progressGate.ready {
            currentPosition = actual
            session.ready(request: session.request, now: uptime())
            savePosition(actual)
            if session.wantsPlayback { player.play() }
        } else {
            failPlayback(message: L10n.string(.progressRestoreFailed))
        }
    }

    func retryPlayback() {
        guard let context = currentContext else { return }
        selectPlayback(context, force: true, wantsPlayback: session.retryWantsPlayback, snapshot: queue.snapshot)
    }

    func seek(to position: Double) async {
        guard let player, let item = player.currentItem, progressGate.ready, position.isFinite, position >= 0 else { return }
        let token = progressGate.token
        let request = UUID()
        seekRequest = request
        seekInFlight = true
        let success = await player.seek(to: CMTime(seconds: position, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        guard isCurrent(player, item: item, token: token), seekRequest == request else { return }
        seekInFlight = false
        guard success else { return }
        let actual = player.currentTime().seconds
        progressGate.jumped(token: token, position: actual)
        savePosition(actual, explicitSeek: true)
    }

    private func recordMovement(position: Double, playing: Bool) {
        guard !seekInFlight, player?.currentItem?.status == .readyToPlay, let context = activePlaybackContext else { return }
        if progressGate.tick(token: progressGate.token, position: position, playing: playing, uptime: uptime()) {
            currentPosition = position
            session.advanced(request: session.request, now: uptime())
            progressStore.update(context, position: position, duration: mediaDuration, event: .advance)
        }
    }

    private func savePosition(_ position: Double, explicitSeek: Bool = false) {
        guard !seekInFlight, player?.currentItem?.status == .readyToPlay, let context = activePlaybackContext,
              let position = progressGate.action(token: progressGate.token, position: position, explicitSeek: explicitSeek) else { return }
        currentPosition = position
        progressStore.update(context, position: position, duration: mediaDuration, event: .position)
        progressStore.requestFlush()
    }

    private func persistCurrentPlaybackProgress(force: Bool) {
        if let position = player?.currentTime().seconds {
            recordMovement(position: position, playing: player?.timeControlStatus == .playing)
            savePosition(position)
        }
        // 恢复门未开时也允许重试其他已接受的 dirty 数据，绝不采纳当前初始零。
        if force { progressStore.requestFlush() }
    }

    func saveForLifecycleChange() {
        persistCurrentPlaybackProgress(force: true)
#if os(iOS)
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SavePlaybackProgress") {
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask); backgroundTask = .invalid }
        }
        Task {
            await progressStore.flush()
            if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask); backgroundTask = .invalid }
        }
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
        let token = progressGate.token
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        playCommandTarget = commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.progressGate.token == token else { return }
                self.resumePlayback()
                self.updateNowPlayingPlaybackState()
            }
            return .success
        }

        pauseCommandTarget = commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.progressGate.token == token else { return }
                self.pausePlayback()
                self.updateNowPlayingPlaybackState()
            }
            return .success
        }

        toggleCommandTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.progressGate.token == token else { return }
                self.togglePlayback()
                self.updateNowPlayingPlaybackState()
            }
            return .success
        }

        seekCommandTarget = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor [weak self] in
                guard let self, self.progressGate.token == token else { return }
                await self.seek(to: event.positionTime)
                self.updateNowPlayingPlaybackState()
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
        let token = progressGate.token
        if interruptionObserver == nil {
            interruptionObserver = center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self, self.progressGate.token == token else { return }
                    self.handleAudioInterruption(notification)
                }
            }
        }
        if routeChangeObserver == nil {
            routeChangeObserver = center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self, self.progressGate.token == token else { return }
                    self.handleRouteChange(notification)
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
            session.interruptionBegan()
            player?.pause()
            persistCurrentPlaybackProgress(force: true)
            updateNowPlayingPlaybackState()
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            if session.interruptionEnded(systemAllows: options.contains(.shouldResume), now: uptime()) {
                configureAudioSessionForPlayback(isVideo: isVideo)
                if progressGate.ready { player?.play() }
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
            pausePlayback()
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

    private static func isOfflineError(_ error: Error?) -> Bool {
        var current = error as NSError?
        for _ in 0..<5 {
            guard let error = current else { return false }
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet { return true }
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    private static func clampAmplification(_ value: Double) -> Double {
        min(5.0, max(1.0, value))
    }
}

extension EpisodeItem {
    var fallbackMediaType: PlaybackMediaType {
        if let mp3Url, !mp3Url.isEmpty {
            return .audio
        }
        if (mp4Url as NSString).pathExtension.lowercased() == "mp3"
            || (vodUrl as NSString).pathExtension.lowercased() == "mp3" {
            return .audio
        }
        if isVideo {
            return .video
        }
        return .audio
    }
}
