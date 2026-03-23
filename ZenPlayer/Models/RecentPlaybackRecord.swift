//
//  RecentPlaybackRecord.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import Foundation

struct RecentPlaybackRecord: Codable, Identifiable, Hashable {
    let context: PlaybackContext
    let playedAt: Date

    var id: String {
        Self.recordID(for: context)
    }

    static func recordID(for context: PlaybackContext) -> String {
        "\(context.episode.id)|\(context.serverUrl)"
    }
}
