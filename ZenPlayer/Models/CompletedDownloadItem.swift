//
//  CompletedDownloadItem.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import Foundation

struct CompletedDownloadItem: Codable, Identifiable, Hashable {
    let downloadKey: String
    let context: PlaybackContext
    let type: DownloadType
    let completedAt: Date

    var id: String { downloadKey }
}

extension DownloadType {
    var playbackMediaType: PlaybackMediaType {
        switch self {
        case .mp3:
            return .audio
        case .mp4:
            return .video
        }
    }
}
