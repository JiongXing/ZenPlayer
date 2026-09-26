import XCTest

final class PlaybackSavingTests: XCTestCase {
    @MainActor
    func testPeriodicAndImmediateActionsPersistWithControlledClock() async throws {
        let env = try ProgressTestEnvironment()
        let clock = TestClock()
        let disk = FileProgressPersistence(root: env.directory)
        let store = PlaybackProgressStore(persistence: disk, now: { clock.now })
        var gate = PlaybackProgressGate()
        let context = testContext()
        let token = gate.begin(position: 100)
        gate.restored(token: token, success: true, position: 100)
        var committed: [Date] = []
        for second in 1...12 {
            clock.advance(1)
            let position = 100 + Double(second)
            if gate.tick(token: token, position: position, playing: true, uptime: clock.uptime) {
                store.update(context, position: position, duration: nil, event: .advance)
            }
            if gate.shouldFlush(uptime: clock.uptime) {
                gate.didRequestFlush(uptime: clock.uptime)
                await store.flush()
                committed.append(try XCTUnwrap(store.lastCommittedAt))
            }
        }
        XCTAssertEqual(committed.count, 3)
        for pair in zip(committed, committed.dropFirst()) { XCTAssertLessThanOrEqual(pair.1.timeIntervalSince(pair.0), 5) }
        // 任一动作都采即时值，不等周期；显式 seek 到 0 是合法落点。
        for position in [113.0, 0, 103] {
            let sampled = try XCTUnwrap(gate.action(token: token, position: position, explicitSeek: true))
            store.update(context, position: sampled, duration: nil, event: .position)
            await store.flush()
            XCTAssertEqual(try disk.load().records.first?.positionSeconds, position)
        }
        let saved = try Data(contentsOf: disk.recordURL(RecentPlaybackRecord.recordID(for: context)))
        gate.invalidate()
        XCTAssertNil(gate.action(token: token, position: 0))
        XCTAssertEqual(try Data(contentsOf: disk.recordURL(RecentPlaybackRecord.recordID(for: context))), saved)
    }

    @MainActor
    func testSwitchUsesImmediatePositionAndTargetDurationWithoutClearingOnFailure() async throws {
        let env = try ProgressTestEnvironment()
        let disk = FileProgressPersistence(root: env.directory)
        let store = PlaybackProgressStore(persistence: disk)
        let context = testContext()
        store.update(context, position: 100, duration: 300, event: .advance)
        await store.flush()
        var gate = PlaybackProgressGate()
        let old = gate.begin(position: 100)
        gate.restored(token: old, success: true, position: 100)
        let immediate = try XCTUnwrap(gate.action(token: old, position: 103))
        store.update(context, position: immediate, duration: 300, event: .position)
        await store.flush()
        let next = gate.begin(position: immediate)
        gate.restored(token: next, success: false, position: 0)
        XCTAssertNil(gate.action(token: next, position: 0))
        XCTAssertEqual(try disk.load().records.first?.positionSeconds, 103)
        let bounded = min(immediate, try XCTUnwrap(PlaybackProgress.trustedDuration(80, metadata: 300)))
        gate.restored(token: next, success: true, position: bounded)
        XCTAssertEqual(gate.action(token: next, position: bounded), 80)
        XCTAssertNil(gate.action(token: old, position: 0))
    }

    @MainActor
    func testLargeLibraryStartupAndRecentQuery() async throws {
        let env = try ProgressTestEnvironment()
        let disk = FileProgressPersistence(root: env.directory)
        for id in 1...1_000 {
            var record = PlaybackProgress(context: testContext(id: id), now: Date())
            record.update(position: Double(id), mediaDuration: nil, event: .advance, now: Date())
            _ = try await disk.commit(record)
        }
        let start = ProcessInfo.processInfo.systemUptime
        let loaded = try disk.load()
        let readTime = ProcessInfo.processInfo.systemUptime - start
        let queryStart = ProcessInfo.processInfo.systemUptime
        let recent = PlaybackProgress.recent(loaded.records)
        let queryTime = ProcessInfo.processInfo.systemUptime - queryStart
        XCTAssertEqual(loaded.records.count, 1_000)
        XCTAssertEqual(recent.count, 10)
        print("M0 1000 records: cold read \(readTime)s, recent query \(queryTime)s")
    }
}
