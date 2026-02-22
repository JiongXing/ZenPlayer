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

    /// 解析后的播放 URL（本地优先）
    var playbackURL: URL?

    /// 是否为视频（用于决定使用视频或音频播放器）
    var isVideo: Bool = false

    /// 解析错误信息
    var errorMessage: String?

    private let downloadManager = DownloadManager.shared

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
            if let localURL = downloadManager.completedFileURL(for: episode.id, type: .mp4) {
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
        if let localURL = downloadManager.completedFileURL(for: episode.id, type: .mp3) {
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
            if let localURL = downloadManager.completedFileURL(for: episode.id, type: .mp4) {
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
}
