import XCTest

@MainActor
final class QueueSnapshotStoreTests: XCTestCase {
    func testRestartRestoresSnapshotAndPreferenceWithoutProgressWrites() async throws {
        let environment = try ProgressTestEnvironment()
        let store = QueueSnapshotStore(root: environment.directory, defaults: environment.defaults)
        XCTAssertTrue(store.autoAdvance)
        let snapshot = testQueue()
        store.register(snapshot)
        await store.flush()
        XCTAssertNil(store.saveError)
        store.autoAdvance = false
        let reopened = QueueSnapshotStore(root: environment.directory, defaults: environment.defaults)
        XCTAssertFalse(reopened.autoAdvance)
        let restored = await reopened.restore(for: testContext(id: 2))
        XCTAssertEqual(restored, snapshot)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: environment.directory.path).count, 1)
    }

    func testCorruptAndUnknownVersionAreIsolatedWithoutDeletion() async throws {
        let environment = try ProgressTestEnvironment()
        let good = testQueue()
        let persistence = QueueSnapshotPersistence(root: environment.directory)
        try await persistence.save(good)
        let badURL = environment.directory.appendingPathComponent(UUID().uuidString + ".json")
        let bad = Data("broken".utf8)
        try bad.write(to: badURL)
        var future = testQueue(seriesID: 20)
        future.schemaVersion = 99
        let futureURL = environment.directory.appendingPathComponent(future.id + ".json")
        let futureData = try JSONEncoder().encode(future)
        try futureData.write(to: futureURL)
        let store = QueueSnapshotStore(root: environment.directory, defaults: environment.defaults)
        let restored = await store.restore(for: testContext(id: 2))
        XCTAssertEqual(restored, good)
        XCTAssertEqual(store.recoveryIssueCount, 2)
        XCTAssertEqual(try Data(contentsOf: badURL), bad)
        XCTAssertEqual(try Data(contentsOf: futureURL), futureData)
    }

    func testWriteFailureKeepsLiveQueueAndCanRetry() async throws {
        let environment = try ProgressTestEnvironment()
        var fail = true
        let persistence = QueueSnapshotPersistence(root: environment.directory)
        let store = QueueSnapshotStore(root: environment.directory, defaults: environment.defaults, writer: { snapshot in
            if fail { throw CocoaError(.fileWriteOutOfSpace) }
            try await persistence.save(snapshot)
        })
        let snapshot = testQueue()
        store.register(snapshot)
        await store.flush()
        XCTAssertNotNil(store.saveError)
        XCTAssertEqual(store.cached(for: try XCTUnwrap(snapshot.context(at: 1))), snapshot)
        fail = false
        await store.flush()
        XCTAssertNil(store.saveError)
        let reopened = QueueSnapshotStore(root: environment.directory, defaults: environment.defaults)
        let restored = await reopened.restore(for: testContext(id: 2))
        XCTAssertEqual(restored, snapshot)
    }

    func testAmbiguousLegacyKeyDoesNotGuessSeriesButExplicitReferenceWorks() async throws {
        let environment = try ProgressTestEnvironment()
        let store = QueueSnapshotStore(root: environment.directory, defaults: environment.defaults)
        let first = testQueue(seriesID: 10), other = testQueue(seriesID: 11)
        store.register(first)
        store.register(other)
        await store.flush()
        let ambiguous = await store.restore(for: testContext(id: 2))
        XCTAssertNil(ambiguous)
        let explicit = await store.restore(for: try XCTUnwrap(first.context(at: 1)))
        XCTAssertEqual(explicit, first)
        let absent = await store.restore(for: testContext(id: 999))
        XCTAssertNil(absent)
        let mismatched = PlaybackContext(episode: testContext(id: 999).episode, serverUrl: first.serverURL,
                                        series: first.context(at: 0)?.series)
        let invalid = await store.restore(for: mismatched)
        XCTAssertNil(invalid)
    }
    func testBrowsingDoesNotPersistAndRepeatedSelectionDoesNotRewriteSnapshot() async throws {
        let environment = try ProgressTestEnvironment()
        var writes = 0
        let persistence = QueueSnapshotPersistence(root: environment.directory)
        let store = QueueSnapshotStore(root: environment.directory, defaults: environment.defaults, writer: { snapshot in
            writes += 1
            try await persistence.save(snapshot)
        })
        let snapshot = testQueue()
        store.cache(snapshot)
        let oldEntry = await store.restore(for: testContext(id: 2))
        XCTAssertNil(oldEntry)
        XCTAssertEqual(writes, 0)
        store.register(snapshot)
        await store.flush()
        store.register(snapshot)
        await store.flush()
        XCTAssertEqual(writes, 1)
    }

    func testProgressKeepsSeriesReferenceWhenOldEntryHasNoMetadata() async throws {
        let environment = try ProgressTestEnvironment()
        let persistence = FileProgressPersistence(root: environment.directory)
        let store = PlaybackProgressStore(persistence: persistence)
        let context = try XCTUnwrap(testQueue().context(at: 1))
        store.update(context, position: 12, duration: 300, event: .advance)
        store.update(testContext(id: 2), position: 14, duration: 300, event: .position)
        await store.flush()
        let record = try XCTUnwrap(store.record(for: context))
        XCTAssertEqual(record.context.series, context.series)
        XCTAssertEqual(record.snapshotReference, context.series?.snapshotID)
        XCTAssertEqual(record.positionSeconds, 14)
        XCTAssertEqual(record.legacyKey, RecentPlaybackRecord.recordID(for: testContext(id: 2)))
    }

}
