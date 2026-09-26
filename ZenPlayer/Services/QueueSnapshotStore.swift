import Foundation
import Observation

@MainActor
@Observable
final class QueueSnapshotStore {
    static let shared = QueueSnapshotStore(root: URL.applicationSupportDirectory.appendingPathComponent("PlaybackQueue/v1"))
    var autoAdvance: Bool {
        didSet { defaults.set(autoAdvance, forKey: "playback.autoAdvance") }
    }
    private(set) var saveError: String?
    private(set) var recoveryIssueCount = 0
    private var snapshots: [String: QueueSnapshot] = [:]
    private var dirty: Set<String> = []
    private var persisted: Set<String> = []
    private let defaults: UserDefaults
    private let reader: () async throws -> QueueSnapshotPersistence.Loaded
    private let writer: (QueueSnapshot) async throws -> Void
    @ObservationIgnored private var loadTask: Task<QueueSnapshotPersistence.Loaded, Error>?
    @ObservationIgnored private var writeTask: Task<Void, Never>?
    private var didLoad = false

    init(root: URL, defaults: UserDefaults = .standard,
         reader: (() async throws -> QueueSnapshotPersistence.Loaded)? = nil,
         writer: ((QueueSnapshot) async throws -> Void)? = nil) {
        self.defaults = defaults
        autoAdvance = defaults.object(forKey: "playback.autoAdvance") as? Bool ?? true
        let persistence = QueueSnapshotPersistence(root: root)
        self.reader = reader ?? { try await persistence.load() }
        self.writer = writer ?? { try await persistence.save($0) }
    }

    func cache(_ snapshot: QueueSnapshot) {
        guard snapshot.isValid else { return }
        snapshots[snapshot.id] = snapshot
    }

    func register(_ snapshot: QueueSnapshot) {
        guard snapshot.isValid else { saveError = "invalid-snapshot"; return }
        snapshots[snapshot.id] = snapshot
        guard !persisted.contains(snapshot.id) else { return }
        dirty.insert(snapshot.id)
        Task { await flush() }
    }

    func cached(for context: PlaybackContext) -> QueueSnapshot? {
        guard let reference = context.series, let snapshot = snapshots[reference.snapshotID],
              snapshot.seriesID == reference.seriesID, snapshot.detailURL == reference.detailURL,
              snapshot.index(of: context) != nil else { return nil }
        return snapshot
    }

    func restore(for context: PlaybackContext) async -> QueueSnapshot? {
        if let cached = cached(for: context) { return cached }
        if !didLoad {
            if loadTask == nil { loadTask = Task { try await reader() } }
            do {
                if let loaded = try await loadTask?.value {
                    for snapshot in loaded.snapshots where snapshots[snapshot.id] == nil { snapshots[snapshot.id] = snapshot }
                    persisted.formUnion(loaded.snapshots.map(\.id))
                    recoveryIssueCount = loaded.issueCount
                }
            } catch { recoveryIssueCount += 1 }
            didLoad = true
            loadTask = nil
        }
        if context.series != nil { return cached(for: context) }
        let matches = snapshots.values.filter { (persisted.contains($0.id) || dirty.contains($0.id)) && $0.index(of: context) != nil }
        // 同系列的不同版本取最新；跨系列碰撞不凭标题猜测。
        let identities = Set(matches.map { "\($0.seriesID)|\($0.detailURL)|\($0.serverURL)" })
        guard identities.count == 1 else { return nil }
        return matches.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt > $1.createdAt
        }.first
    }

    func flush() async {
        if let writeTask { await writeTask.value; return }
        let task = Task { await writePending() }
        writeTask = task
        await task.value
        writeTask = nil
    }

    private func writePending() async {
        var failed = Set<String>()
        while let id = dirty.subtracting(failed).sorted().first, let snapshot = snapshots[id] {
            do {
                try await writer(snapshot)
                dirty.remove(id)
                persisted.insert(id)
            } catch { failed.insert(id) }
        }
        saveError = dirty.isEmpty ? nil : "snapshot-write-failed"
    }
}
