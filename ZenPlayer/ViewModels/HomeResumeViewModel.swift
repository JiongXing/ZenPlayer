import Foundation
import Observation

@MainActor
@Observable
final class HomeResumeViewModel {
    let progressStore: PlaybackProgressStore
    private let queueStore: QueueSnapshotStore
    private var nextSnapshot: QueueSnapshot?
    private var refreshedContext: PlaybackContext?
    private var request = UUID()

    init(progressStore: PlaybackProgressStore, queueStore: QueueSnapshotStore) {
        self.progressStore = progressStore
        self.queueStore = queueStore
    }

    var lookupContext: PlaybackContext? {
        guard let latest = ResumeCandidatePolicy.latest(progressStore.records.values), latest.state == .completed else { return nil }
        return latest.context
    }

    func candidate(session: PlaybackSessionState, position: Double) -> ResumeCandidate? {
        ResumeCandidatePolicy.candidate(session: session, position: position, records: Array(progressStore.records.values), nextSnapshot: nextSnapshot)
    }

    func refresh() async {
        let context = lookupContext
        guard context != refreshedContext else { return }
        nextSnapshot = nil
        request = UUID()
        let token = request
        guard let context else { refreshedContext = nil; return }
        let snapshot = await queueStore.restore(for: context)
        guard !Task.isCancelled, request == token, lookupContext == context else { return }
        refreshedContext = context
        nextSnapshot = snapshot
    }
}
