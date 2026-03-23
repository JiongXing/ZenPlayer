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
    let resumePositionSeconds: Double

    init(
        context: PlaybackContext,
        playedAt: Date,
        resumePositionSeconds: Double = 0
    ) {
        self.context = context
        self.playedAt = playedAt
        self.resumePositionSeconds = resumePositionSeconds
    }

    var id: String {
        Self.recordID(for: context)
    }

    var boundedResumePositionSeconds: Double {
        let totalDuration = context.episode.playbackDurationSeconds
        let clamped = max(0, resumePositionSeconds)
        guard totalDuration > 0 else { return clamped }
        return min(clamped, totalDuration)
    }

    var restorableResumePositionSeconds: Double {
        let totalDuration = context.episode.playbackDurationSeconds
        guard totalDuration > 0 else { return boundedResumePositionSeconds }
        if boundedResumePositionSeconds >= totalDuration {
            return 0
        }
        return boundedResumePositionSeconds
    }

    var progressFraction: Double {
        let totalDuration = context.episode.playbackDurationSeconds
        guard totalDuration > 0 else { return 0 }
        return boundedResumePositionSeconds / totalDuration
    }

    var progressPercentage: Int {
        Int((progressFraction * 100).rounded())
    }

    var progressSummaryText: String {
        L10n.string(
            .recentPlaybackProgressSummary,
            progressPercentage,
            EpisodeItem.formatPlaybackDuration(seconds: boundedResumePositionSeconds),
            context.episode.formattedDuration
        )
    }

    static func recordID(for context: PlaybackContext) -> String {
        "\(context.episode.id)|\(context.serverUrl)"
    }

    func updating(
        context: PlaybackContext? = nil,
        playedAt: Date? = nil,
        resumePositionSeconds: Double? = nil
    ) -> RecentPlaybackRecord {
        RecentPlaybackRecord(
            context: context ?? self.context,
            playedAt: playedAt ?? self.playedAt,
            resumePositionSeconds: resumePositionSeconds ?? self.resumePositionSeconds
        )
    }

    private enum CodingKeys: String, CodingKey {
        case context
        case playedAt
        case resumePositionSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        context = try container.decode(PlaybackContext.self, forKey: .context)
        playedAt = try container.decode(Date.self, forKey: .playedAt)
        resumePositionSeconds = try container.decodeIfPresent(Double.self, forKey: .resumePositionSeconds) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(context, forKey: .context)
        try container.encode(playedAt, forKey: .playedAt)
        try container.encode(resumePositionSeconds, forKey: .resumePositionSeconds)
    }
}
