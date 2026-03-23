//
//  Episode.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import Foundation

/// 讲集详情响应数据（播放列表）
struct SpeechDetailData: Codable {
    let serverUrl: String
    let updateTime: Int
    let series: String           // 如 "全5集"
    let totalCount: Int
    let speechTitle: String
    let speechAuthor: String
    let speechAddress: String
    let speechDate: String
    let speechDesc: String
    let cateCoverUrl: String
    let cateId: String
    let albumNum: String
    let pathTitle: String        // 如 "講演全集 > 學佛基礎 > 念佛的功德"
    let type: String             // "mp4" 或 "mp3"
    let rows: [EpisodeItem]
}

/// 单集条目
struct EpisodeItem: Codable, Identifiable, Hashable {
    let id: Int
    let num: String
    let title: String
    let episode: String
    let mp4Url: String
    let vodUrl: String
    let mp3Url: String?
    let coverUrl: String
    let textUrl: String
    let filesize: Int
    let duration: Int            // 毫秒

    /// 格式化后的时长（如 "1:25:46"）
    var formattedDuration: String {
        Self.formatPlaybackDuration(seconds: playbackDurationSeconds)
    }

    /// 格式化后的文件大小（如 "224.8 MB"）
    var formattedFileSize: String {
        let mb = Double(filesize) / (1024 * 1024)
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        } else {
            return String(format: "%.1f MB", mb)
        }
    }

    /// 是否为视频
    var isVideo: Bool {
        !mp4Url.isEmpty
    }

    var playbackDurationSeconds: Double {
        Double(duration) / 1000.0
    }

    static func formatPlaybackDuration(seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
