import Foundation

nonisolated enum ResumeCandidatePolicy {
    static func latest(_ records: some Sequence<PlaybackProgress>) -> PlaybackProgress? {
        records.filter { $0.isValid && $0.lastListenedAt != nil }.min {
            if $0.lastListenedAt == $1.lastListenedAt { return $0.legacyKey < $1.legacyKey }
            return $0.lastListenedAt! > $1.lastListenedAt!
        }
    }

    static func candidate(session: PlaybackSessionState, position: Double, records: [PlaybackProgress], nextSnapshot: QueueSnapshot?) -> ResumeCandidate? {
        if session.isActive, let context = session.context {
            let record = records.first { $0.legacyKey == RecentPlaybackRecord.recordID(for: context) }
            return ResumeCandidate(kind: .active, context: context, position: position.isFinite ? max(0, position) : 0,
                                   duration: record?.durationSeconds ?? PlaybackProgress.trustedDuration(nil, metadata: context.episode.playbackDurationSeconds))
        }
        guard let recent = latest(records) else { return nil }
        if unfinished(recent) { return result(recent, kind: .resume) }
        if recent.state == .completed, let snapshot = nextSnapshot,
           recent.context.series.map({ $0.snapshotID == snapshot.id }) ?? true,
           let index = snapshot.index(of: recent.context),
           let context = snapshot.context(at: index + 1, preferred: recent.context.preferredMediaType) {
            let next = records.first { $0.legacyKey == RecentPlaybackRecord.recordID(for: context) }
            if next?.state != .completed {
                return ResumeCandidate(kind: .next, context: context, position: next?.resumePosition ?? 0,
                                       duration: next?.durationSeconds ?? PlaybackProgress.trustedDuration(nil, metadata: context.episode.playbackDurationSeconds))
            }
        }
        return latest(records.filter(unfinished)).map { result($0, kind: .resume) }
    }

    static func latestInSeries(episodes: [EpisodeItem], serverURL: String, records: some Sequence<PlaybackProgress>) -> PlaybackProgress? {
        let ids = Set(episodes.map(\.id))
        return latest(records.filter { $0.context.serverUrl == serverURL && ids.contains($0.context.episode.id) })
    }

    private static func unfinished(_ record: PlaybackProgress) -> Bool {
        record.isValid && record.state == .inProgress && record.lastListenedAt != nil && record.positionSeconds > 0
    }

    private static func result(_ record: PlaybackProgress, kind: ResumeCandidate.Kind) -> ResumeCandidate {
        ResumeCandidate(kind: kind, context: record.context, position: record.resumePosition, duration: record.durationSeconds)
    }
}
