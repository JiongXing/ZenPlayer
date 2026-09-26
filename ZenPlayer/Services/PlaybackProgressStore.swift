import Foundation
import Observation

@MainActor
@Observable
final class PlaybackProgressStore {
    static let shared = PlaybackProgressStore(persistence: FileProgressPersistence(root:
        URL.applicationSupportDirectory.appendingPathComponent("PlaybackProgress/v1")), legacySource: UserDefaults.standard.data(forKey: "recentPlayback.records"))

    private(set) var records: [String: PlaybackProgress] = [:]
    private(set) var dirty = Set<String>()
    private(set) var saveError: String?
    private(set) var recoveryIssues: [String] = []
    private(set) var isFlushing = false
    private(set) var lastCommittedAt: Date?
    private let persistence: FileProgressPersistence
    private let writer: (PlaybackProgress) async throws -> UInt64
    @ObservationIgnored private var flushWaiters: [CheckedContinuation<Void, Never>] = []
    private let legacySource: Data?
    private(set) var migrationError: String?
    private let now: () -> Date
    var hasUnsavedChanges: Bool { !dirty.isEmpty }
    var recentRecords: [PlaybackProgress] { PlaybackProgress.recent(records.values) }

    init(persistence: FileProgressPersistence, legacySource: Data? = nil, now: @escaping () -> Date = Date.init,
         writer: ((PlaybackProgress) async throws -> UInt64)? = nil) {
        self.legacySource = legacySource
        self.persistence = persistence
        self.now = now
        self.writer = writer ?? { try await persistence.commit($0) }
        do {
            let loaded = try persistence.load()
            records = Dictionary(uniqueKeysWithValues: loaded.records.map { ($0.id, $0) })
            recoveryIssues = loaded.issues
        } catch { recoveryIssues = ["load-failed"] }
        retryMigration()
    }

    func retryMigration() {
        guard let legacySource, dirty.isEmpty else { return }
        // 先提交用户最新进度，再补旧数据；不能在两次提交之间暴露旧位置。
        do {
            let mapping = try persistence.migrate(source: legacySource)
            let loaded = try persistence.load()
            for record in loaded.records where !dirty.contains(record.id) { records[record.id] = record }
            recoveryIssues = loaded.issues
            if !mapping.isolatedIndices.isEmpty { recoveryIssues.append("isolated-legacy:\(mapping.isolatedIndices.count)") }
            migrationError = nil
        } catch {
            migrationError = "migration-incomplete"
            // 备份失败仍可浏览有效旧项；不可将已占用的坏新文件当作缺失。
            if let loaded = try? persistence.load(), let mapped = try? LegacyProgressMigration.map(legacySource) {
                for record in mapped.records where records[record.id] == nil
                    && !loaded.occupied.contains(FileProgressPersistence.digest(Data(record.id.utf8))) {
                    records[record.id] = record
                }
            }
        }
    }

    func retry() {
        Task {
            await flush()
            retryMigration()
        }
    }

    func record(for context: PlaybackContext) -> PlaybackProgress? {
        records[RecentPlaybackRecord.recordID(for: context)]
    }

    func update(_ context: PlaybackContext, position: Double, duration: Double?, event: PlaybackProgress.Event) {
        let key = RecentPlaybackRecord.recordID(for: context)
        var record = records[key] ?? PlaybackProgress(context: context, now: now())
        let previous = record
        record.update(position: position, mediaDuration: duration, event: event, now: now())
        guard record != previous else { return }
        record.context = PlaybackContext(episode: context.episode, serverUrl: context.serverUrl,
                                         preferredMediaType: context.preferredMediaType,
                                         series: context.series ?? previous.context.series)
        if let series = record.context.series {
            record.seriesId = String(series.seriesID)
            record.seriesTitle = series.title
            record.seriesDetailURL = series.detailURL
            record.snapshotReference = series.snapshotID
        }
        records[key] = record
        dirty.insert(key)
    }

    func requestFlush() { Task { await flush() } }

    func flushSynchronously() {
        for key in dirty.sorted() {
            guard let record = records[key] else { continue }
            do {
                let revision = try persistence.commitSynchronously(record)
                if revision == record.revision { dirty.remove(key) }
                else { saveError = "revision-mismatch" }
            } catch { saveError = "write-failed" }
        }
        if dirty.isEmpty { saveError = nil }
    }

    /// 接受的内存值与成功落盘分开；旧回执不能清除新修订。
    func flush() async {
        if isFlushing {
            await withCheckedContinuation { flushWaiters.append($0) }
            return
        }
        isFlushing = true
        defer {
            isFlushing = false
            let waiters = flushWaiters
            flushWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
        }
        var failed = false
        repeat {
            let batch = dirty.sorted().compactMap { records[$0] }
            for record in batch {
                do {
                    let revision = try await writer(record)
                    guard revision == record.revision else { throw FileProgressPersistence.StorageError.verification }
                    if records[record.id]?.revision == revision { dirty.remove(record.id) }
                    let digest = FileProgressPersistence.digest(Data(record.id.utf8))
                    recoveryIssues.removeAll { $0 == "backup:\(digest)" || $0 == "unreadable:\(digest)" }
                    lastCommittedAt = now()
                } catch {
                    failed = true
                    saveError = "write-failed"
                }
            }
        } while !failed && !dirty.isEmpty
        if dirty.isEmpty { saveError = nil }
    }
}
