import XCTest

@MainActor
final class HomeResumeViewModelTests: XCTestCase {
    func testLocalCandidateAndNextSnapshotNeedNoCategoryRequest() async throws {
        let environment = try ProgressTestEnvironment()
        let progress = PlaybackProgressStore(persistence: FileProgressPersistence(root: environment.directory.appendingPathComponent("progress")))
        let queue = QueueSnapshotStore(root: environment.directory.appendingPathComponent("queue"), defaults: environment.defaults)
        let snapshot = testQueue()
        let context = try XCTUnwrap(snapshot.context(at: 1))
        progress.update(context, position: 40, duration: 300, event: .advance)
        let model = HomeResumeViewModel(progressStore: progress, queueStore: queue)
        XCTAssertEqual(model.candidate(session: .init(), position: 0)?.position, 40)
        queue.register(snapshot)
        progress.update(context, position: 300, duration: 300, event: .ended)
        await model.refresh()
        XCTAssertEqual(model.candidate(session: .init(), position: 0)?.context.episode.id, 5)
        XCTAssertEqual(model.candidate(session: .init(), position: 0)?.position, 0)
        await queue.flush()
        await progress.flush()
    }

    func testLateSnapshotDoesNotReplaceMoreRecentListeningAndDoesNotReloadOnTick() async throws {
        let environment = try ProgressTestEnvironment()
        let progress = PlaybackProgressStore(persistence: FileProgressPersistence(root: environment.directory.appendingPathComponent("progress")))
        var release: CheckedContinuation<QueueSnapshotPersistence.Loaded, Error>?
        var loads = 0
        let queue = QueueSnapshotStore(root: environment.directory.appendingPathComponent("queue"), defaults: environment.defaults, reader: {
            loads += 1
            return try await withCheckedThrowingContinuation { release = $0 }
        })
        let snapshot = testQueue()
        let context = try XCTUnwrap(snapshot.context(at: 1))
        progress.update(context, position: 40, duration: 300, event: .advance)
        progress.update(context, position: 300, duration: 300, event: .ended)
        let model = HomeResumeViewModel(progressStore: progress, queueStore: queue)
        let pending = Task { await model.refresh() }
        let deadline = ContinuousClock.now + .seconds(2)
        while release == nil, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        let continuation = try XCTUnwrap(release)
        progress.update(testContext(id: 99), position: 70, duration: 300, event: .advance)
        await model.refresh()
        continuation.resume(returning: .init(snapshots: [snapshot]))
        release = nil
        await pending.value
        XCTAssertEqual(model.candidate(session: .init(), position: 0)?.context.episode.id, 99)
        progress.update(testContext(id: 99), position: 71, duration: 300, event: .advance)
        await model.refresh()
        XCTAssertEqual(loads, 1)
        await progress.flush()
    }

    func testAbsentSnapshotKeepsOtherReliableRecordAndEmptyHistoryHidesCard() async throws {
        let environment = try ProgressTestEnvironment()
        let progress = PlaybackProgressStore(persistence: FileProgressPersistence(root: environment.directory.appendingPathComponent("progress")))
        let queue = QueueSnapshotStore(root: environment.directory.appendingPathComponent("queue"), defaults: environment.defaults)
        let model = HomeResumeViewModel(progressStore: progress, queueStore: queue)
        XCTAssertNil(model.candidate(session: .init(), position: 0))
        progress.update(testContext(id: 1), position: 5, duration: 300, event: .advance)
        progress.update(testContext(id: 2), position: 5, duration: 300, event: .advance)
        progress.update(testContext(id: 2), position: 300, duration: 300, event: .ended)
        await model.refresh()
        XCTAssertEqual(model.candidate(session: .init(), position: 0)?.context.episode.id, 1)
        await progress.flush()
    }
    func testCancelledSnapshotRefreshCanRunAgainForSameCandidate() async throws {
        let environment = try ProgressTestEnvironment()
        let progress = PlaybackProgressStore(persistence: FileProgressPersistence(root: environment.directory.appendingPathComponent("progress")))
        let snapshot = testQueue()
        let context = try XCTUnwrap(snapshot.context(at: 1))
        progress.update(context, position: 2, duration: 300, event: .advance)
        progress.update(context, position: 300, duration: 300, event: .ended)
        var release: CheckedContinuation<QueueSnapshotPersistence.Loaded, Error>?
        let queue = QueueSnapshotStore(root: environment.directory.appendingPathComponent("queue"), defaults: environment.defaults,
                                        reader: { try await withCheckedThrowingContinuation { release = $0 } })
        let model = HomeResumeViewModel(progressStore: progress, queueStore: queue)
        let pending = Task { await model.refresh() }
        let deadline = ContinuousClock.now + .seconds(2)
        while release == nil, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        let continuation = try XCTUnwrap(release)
        pending.cancel()
        continuation.resume(returning: .init(snapshots: [snapshot]))
        await pending.value
        XCTAssertNil(model.candidate(session: .init(), position: 0))
        await model.refresh()
        XCTAssertEqual(model.candidate(session: .init(), position: 0)?.context.episode.id, 5)
        await progress.flush()
    }

}
