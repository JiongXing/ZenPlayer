import XCTest

final class ProgressStoreTests: XCTestCase {
    @MainActor
    func testFailureKeepsLatestMemoryAndRetryCommitsIt() async throws {
        let env = try ProgressTestEnvironment()
        let faults = TestIOFaults()
        let disk = FileProgressPersistence(root: env.directory) { point in
            if point == faults.failure?.persistencePoint { throw CocoaError(.fileWriteOutOfSpace) }
        }
        let store = PlaybackProgressStore(persistence: disk)
        let context = testContext()
        store.update(context, position: 100, duration: nil, event: .advance)
        await store.flush()
        faults.failure = .replace
        store.update(context, position: 120, duration: nil, event: .position)
        await store.flush()
        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertNotNil(store.saveError)
        XCTAssertEqual(try disk.load().records.first?.positionSeconds, 100)
        XCTAssertEqual(store.record(for: context)?.positionSeconds, 120)
        store.update(context, position: 130, duration: nil, event: .position)
        faults.failure = nil
        await store.flush()
        XCTAssertFalse(store.hasUnsavedChanges)
        XCTAssertNil(store.saveError)
        XCTAssertEqual(try disk.load().records.first?.positionSeconds, 130)
    }

    @MainActor
    func testOldAcknowledgementCannotClearNewRevision() async throws {
        let env = try ProgressTestEnvironment()
        var held: CheckedContinuation<UInt64, Error>?
        var commits: [PlaybackProgress] = []
        let store = PlaybackProgressStore(persistence: FileProgressPersistence(root: env.directory), writer: { record in
            commits.append(record)
            if commits.count == 1 {
                return try await withCheckedThrowingContinuation { held = $0 }
            }
            throw CocoaError(.fileWriteOutOfSpace)
        })
        let context = testContext()
        store.update(context, position: 100, duration: nil, event: .advance)
        let flush = Task { await store.flush() }
        while held == nil { await Task.yield() }
        store.update(context, position: 120, duration: nil, event: .position)
        held?.resume(returning: commits[0].revision)
        await flush.value
        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertEqual(store.record(for: context)?.positionSeconds, 120)
        XCTAssertEqual(commits.last?.positionSeconds, 120)
    }
}

extension ProgressStoreTests {
    @MainActor
    func testLegacyAdapterUsesOneStoreWithoutTenRecordEviction() async throws {
        let env = try ProgressTestEnvironment()
        let source = try fixture("legacy-representative")
        env.defaults.set(source, forKey: "recentPlayback.records")
        let disk = FileProgressPersistence(root: env.directory)
        let store = PlaybackProgressStore(persistence: disk, legacySource: env.defaults.data(forKey: "recentPlayback.records"))
        let adapter = RecentPlaybackStore(progressStore: store)
        XCTAssertEqual(store.records.count, 16)
        XCTAssertEqual(adapter.records.count, 10)
        let old = try JSONDecoder().decode([RecentPlaybackRecord].self, from: source)[0]
        XCTAssertEqual(adapter.record(for: old.context)?.resumePositionSeconds, 120)
        XCTAssertEqual(env.defaults.data(forKey: "recentPlayback.records"), source)
        for id in 1...30 { store.update(testContext(id: id), position: Double(id), duration: nil, event: .advance) }
        await store.flush()
        let reopened = PlaybackProgressStore(persistence: disk, legacySource: source)
        XCTAssertEqual(reopened.records.count, 46)
        XCTAssertEqual(reopened.recentRecords.count, 10)
        XCTAssertEqual(reopened.record(for: testContext(id: 1))?.positionSeconds, 1)
        var record = try XCTUnwrap(reopened.record(for: testContext(id: 1)))
        record.seriesId = "series"; record.seriesTitle = "title"; record.seriesDetailURL = "detail"; record.snapshotReference = "snapshot"
        _ = try await disk.commit(record)
        XCTAssertEqual(try disk.load().records.first { $0.id == record.id }, record)
    }
}

extension ProgressStoreTests {
    @MainActor
    func testMigrationRetryDoesNotWriteLegacyValueWhileNewProgressIsDirty() async throws {
        let env = try ProgressTestEnvironment()
        let faults = TestIOFaults()
        faults.failure = .migrationBackup
        let source = try fixture("legacy-representative")
        let disk = FileProgressPersistence(root: env.directory) { point in
            if point == faults.failure?.persistencePoint { throw CocoaError(.fileWriteOutOfSpace) }
        }
        let store = PlaybackProgressStore(persistence: disk, legacySource: source)
        let legacy = try JSONDecoder().decode([RecentPlaybackRecord].self, from: source)[0]
        store.update(legacy.context, position: 211, duration: nil, event: .advance)
        faults.failure = nil
        store.retryMigration()
        XCTAssertTrue(try disk.load().records.isEmpty, "Dirty playback must reach disk before migration can retry")
        XCTAssertNotNil(store.migrationError)
        await store.flush()
        store.retryMigration()
        XCTAssertNil(store.migrationError)
        XCTAssertEqual(try disk.load().records.first { $0.id == legacy.id }?.positionSeconds, 211)
    }
}
