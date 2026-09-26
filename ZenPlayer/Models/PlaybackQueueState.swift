import Foundation

nonisolated struct PlaybackQueueState {
    private(set) var snapshot: QueueSnapshot?
    private(set) var index: Int?
    private(set) var revision = UUID()
    private var selectedKey: String?
    private var media: UUID?
    private var consumedEnd = false

    mutating func select(_ context: PlaybackContext, snapshot: QueueSnapshot?) {
        self = PlaybackQueueState()
        selectedKey = RecentPlaybackRecord.recordID(for: context)
        if let snapshot { attach(snapshot, to: context) }
    }

    @discardableResult
    mutating func attach(_ snapshot: QueueSnapshot, to context: PlaybackContext) -> Bool {
        guard selectedKey == RecentPlaybackRecord.recordID(for: context), let index = snapshot.index(of: context) else { return false }
        self.snapshot = snapshot
        self.index = index
        revision = UUID()
        // 媒体身份和已经消费的结束事件不因迟到的快照重置。
        return true
    }

    mutating func bindMedia(_ token: UUID) {
        media = token
        consumedEnd = false
    }

    mutating func consumeEnd(media token: UUID, revision: UUID) -> Bool {
        guard media == token, self.revision == revision, !consumedEnd else { return false }
        consumedEnd = true
        return true
    }

    func context(offset: Int, preferred: PlaybackMediaType?) -> PlaybackContext? {
        guard let index, offset == -1 || offset == 0 || offset == 1 else { return nil }
        return snapshot?.context(at: index + offset, preferred: preferred)
    }
}
