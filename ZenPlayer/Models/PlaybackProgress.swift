import Foundation

/// 单条长期记录；磁盘修订与实际收听时间独立。
nonisolated struct PlaybackProgress: Codable, Equatable, Identifiable {
    enum State: String, Codable { case notStarted, inProgress, completed }
    enum Event { case position, advance, ended }

    var schemaVersion = 1
    let legacyKey: String
    var context: PlaybackContext
    var positionSeconds: Double
    var durationSeconds: Double?
    var state: State
    var lastListenedAt: Date?
    var updatedAt: Date
    var revision: UInt64
    var origin: String
    var seriesId: String?
    var seriesTitle: String?
    var seriesDetailURL: String?
    var snapshotReference: String?
    var id: String { legacyKey }
    var resumePosition: Double { state == .completed ? 0 : min(positionSeconds, durationSeconds ?? positionSeconds) }

    init(context: PlaybackContext, now: Date) {
        legacyKey = RecentPlaybackRecord.recordID(for: context)
        self.context = context
        positionSeconds = 0
        durationSeconds = Self.trustedDuration(nil, metadata: context.episode.playbackDurationSeconds)
        state = .notStarted
        updatedAt = now
        revision = 0
        origin = "playback"
    }

    init(legacy: RecentPlaybackRecord) {
        self.init(context: legacy.context, now: legacy.playedAt)
        positionSeconds = legacy.resumePositionSeconds
        lastListenedAt = legacy.playedAt
        state = durationSeconds.map { positionSeconds >= $0 ? .completed : (positionSeconds > 0 ? .inProgress : .notStarted) }
            ?? (positionSeconds > 0 ? .inProgress : .notStarted)
        revision = 1
        origin = "legacy"
    }

    var isValid: Bool {
        schemaVersion == 1 && legacyKey == RecentPlaybackRecord.recordID(for: context)
            && !context.serverUrl.isEmpty && positionSeconds.isFinite && positionSeconds >= 0
            && (durationSeconds.map { $0.isFinite && $0 > 0 } ?? true)
            && updatedAt.timeIntervalSinceReferenceDate.isFinite
            && (lastListenedAt?.timeIntervalSinceReferenceDate.isFinite ?? true)
    }

    mutating func update(position: Double, mediaDuration: Double?, event: Event, now: Date) {
        guard position.isFinite, position >= 0 else { return }
        // 完成记录在首次真实重听前不可被 stop／恢复／拖动清零。
        guard state != .completed || event == .advance || event == .ended else { return }
        durationSeconds = Self.trustedDuration(mediaDuration, metadata: context.episode.playbackDurationSeconds)
        positionSeconds = min(position, durationSeconds ?? position)
        if event == .ended { state = .completed }
        else if event == .advance { state = .inProgress; lastListenedAt = now }
        else if positionSeconds > 0 { state = .inProgress }
        updatedAt = now
        revision += 1
        origin = "playback"
    }

    static func trustedDuration(_ media: Double?, metadata: Double) -> Double? {
        if let media, media.isFinite, media > 0 { return media }
        return metadata.isFinite && metadata > 0 ? metadata : nil
    }

    static func recent(_ records: some Sequence<PlaybackProgress>, limit: Int = 10) -> [PlaybackProgress] {
        Array(records.filter { $0.lastListenedAt != nil }.sorted {
            if $0.lastListenedAt == $1.lastListenedAt { return $0.legacyKey < $1.legacyKey }
            return $0.lastListenedAt! > $1.lastListenedAt!
        }.prefix(max(0, limit)))
    }
}
