//
//  PlayerViewModel.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/22.
//

import Foundation
import AVFoundation

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
                return "原声"
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
        stopPlayback()
        resolvePlaybackURL(episode: episode, serverUrl: serverUrl, preferVideo: preferVideo)
        guard let url = playbackURL else { return }
        await buildPlayer(for: url)
    }

    /// 停止并释放当前播放链路资源
    func stopPlayback() {
        player?.pause()
        player = nil
        denoiseTapProcessor = nil
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

        errorMessage = "没有可播放的地址"
    }

    /// 二次校验本地文件存在，避免映射残留导致播放失败。
    private func verifiedLocalURL(for episodeId: Int, type: DownloadType) -> URL? {
        guard let localURL = downloadManager.completedFileURL(for: episodeId, type: type) else { return nil }
        guard FileManager.default.fileExists(atPath: localURL.path) else { return nil }
        return localURL
    }

    private func buildPlayer(for url: URL) async {
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
    }

    static let supportedAmplificationOptions: [Double] = [1.0, 2.0, 3.0, 4.0]

    static func amplificationLabel(_ value: Double) -> String {
        switch value {
        case 1.0: return "1x"
        case 2.0: return "2x"
        case 3.0: return "3x"
        case 4.0: return "4x"
        default: return String(format: "%.2fx", value)
        }
    }

    private static func clampAmplification(_ value: Double) -> Double {
        min(4.0, max(1.0, value))
    }
}
