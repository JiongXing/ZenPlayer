import XCTest
import AVFoundation

@MainActor
private final class TestAudioProcessor: PlaybackAudioProcessing {
    let attachAction: (AVPlayerItem) async throws -> Void
    init(_ attachAction: @escaping (AVPlayerItem) async throws -> Void = { _ in }) { self.attachAction = attachAction }
    func attach(to item: AVPlayerItem) async throws { try await attachAction(item) }
    func updateStrength(_ value: Float) {}
    func setEnabled(_ isEnabled: Bool) {}
    func updateGainMultiplier(_ value: Float) {}
}

/// 编译真实 PlayerViewModel，使用真实 AVPlayer 和临时静音文件，不启动生产 App。
@MainActor
final class PlayerQueueIntegrationTests: XCTestCase {
    func testRealNaturalEndSavesCompletedThenAdvancesOnceToNextOwnPosition() async throws {
        let environment = try ProgressTestEnvironment()
        let model = try makeModel(environment)
        defer { model.stopPlayback() }
        let snapshot = testQueue()
        let second = try XCTUnwrap(snapshot.context(at: 1, preferred: .audio))
        let fifth = try XCTUnwrap(snapshot.context(at: 2, preferred: .audio))
        model.progressStore.update(fifth, position: 1, duration: 4, event: .advance)
        model.selectPlayback(second, snapshot: snapshot)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        let oldItem = try XCTUnwrap(model.player?.currentItem)
        model.pausePlayback()
        await model.seek(to: 3.8)
        model.resumePlayback()
        try await waitUntil { model.currentContext?.episode.id == 5 && !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        let current = model.player
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: oldItem)
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: oldItem)
        await Task.yield()
        XCTAssertTrue(model.player === current)
        XCTAssertEqual(model.queue.index, 2)
        XCTAssertEqual(model.progressStore.record(for: second)?.state, .completed)
        XCTAssertGreaterThanOrEqual(model.currentPosition, 0.95)
        XCTAssertFalse(model.canPlayNext)
        await finish(model)
    }

    func testDisabledAutoAdvanceConsumesEndAndTogglingOnDoesNotRestart() async throws {
        let environment = try ProgressTestEnvironment()
        let model = try makeModel(environment)
        defer { model.stopPlayback() }
        model.queueStore.autoAdvance = false
        let snapshot = testQueue()
        model.selectPlayback(try XCTUnwrap(snapshot.context(at: 1)), snapshot: snapshot)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        await model.seek(to: 3.8)
        model.resumePlayback()
        try await waitUntil { model.session.phase == .ended }
        let endedItem = try XCTUnwrap(model.player?.currentItem)
        model.queueStore.autoAdvance = true
        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: endedItem)
        await Task.yield()
        XCTAssertEqual(model.currentContext?.episode.id, 2)
        XCTAssertEqual(model.session.phase, .ended)
        XCTAssertFalse(model.isPlaying)
        await finish(model)
    }

    func testLatePreparationCannotReplaceLastSelectionAndSameSelectionKeepsPausedPlayer() async throws {
        let environment = try ProgressTestEnvironment()
        var releaseSecond: CheckedContinuation<Void, Never>?
        let model = try makeModel(environment, processor: {
            TestAudioProcessor { item in
                if (item.asset as? AVURLAsset)?.url.lastPathComponent == "2.wav" {
                    await withCheckedContinuation { releaseSecond = $0 }
                }
            }
        })
        defer { releaseSecond?.resume(); model.stopPlayback() }
        let snapshot = testQueue()
        let first = try XCTUnwrap(snapshot.context(at: 0))
        model.selectPlayback(first, snapshot: snapshot)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        let existing = model.player
        model.selectPlayback(first, snapshot: snapshot)
        XCTAssertTrue(model.player === existing)
        XCTAssertFalse(model.session.wantsPlayback)
        model.selectPlayback(try XCTUnwrap(snapshot.context(at: 1)), snapshot: snapshot)
        try await waitUntil { releaseSecond != nil }
        model.selectPlayback(try XCTUnwrap(snapshot.context(at: 2)), snapshot: snapshot)
        XCTAssertTrue(model.isPreparingPlayback)
        try await waitUntil { model.currentContext?.episode.id == 5 && !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        let newest = model.player
        releaseSecond?.resume()
        releaseSecond = nil
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(model.player === newest)
        XCTAssertEqual(model.currentContext?.episode.id, 5)
        XCTAssertEqual(model.queue.index, 2)
        await finish(model)
    }

    func testPausedSourceSwitchKeepsImmediatePositionAndQueue() async throws {
        let environment = try ProgressTestEnvironment()
        let model = try makeModel(environment)
        defer { model.stopPlayback() }
        let snapshot = testQueue()
        model.selectPlayback(try XCTUnwrap(snapshot.context(at: 1, preferred: .audio)), wantsPlayback: false, snapshot: snapshot)
        try await waitUntil { !model.isPreparingPlayback && model.session.phase == .paused }
        await model.seek(to: 1.25)
        await model.switchMediaType(to: .video)
        try await waitUntil { !model.isPreparingPlayback && model.session.phase == .paused }
        XCTAssertEqual(model.currentPosition, 1.25, accuracy: 0.05)
        XCTAssertFalse(model.session.wantsPlayback)
        XCTAssertEqual(model.queue.snapshot?.id, snapshot.id)
        XCTAssertEqual(model.queue.index, 1)
        await finish(model)
    }

    func testOfflineAlternateAndDenoiseFailureUseLocalOriginalWithoutLosingTarget() async throws {
        let environment = try ProgressTestEnvironment()
        let model = try makeModel(environment, offline: true, audioOnly: true, processor: {
            TestAudioProcessor { _ in throw CocoaError(.fileReadCorruptFile) }
        })
        defer { model.stopPlayback() }
        let snapshot = testQueue()
        model.selectPlayback(try XCTUnwrap(snapshot.context(at: 1, preferred: .video)), wantsPlayback: false, snapshot: snapshot)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        XCTAssertEqual(model.selectedMediaType, .audio)
        XCTAssertNotNil(model.mediaSelectionNotice)
        XCTAssertEqual(model.session.phase, .paused)
        XCTAssertEqual(model.queue.index, 1)
        await finish(model)
        let noFiles = PlayerViewModel(progressStore: model.progressStore, queueStore: model.queueStore, defaults: environment.defaults,
                                      localFile: { _, _ in nil }, makeAudioProcessor: { _, _ in TestAudioProcessor() }, isOffline: { true })
        defer { noFiles.stopPlayback() }
        noFiles.selectPlayback(try XCTUnwrap(snapshot.context(at: 2, preferred: .video)), snapshot: snapshot)
        XCTAssertEqual(noFiles.session.phase, .failed)
        XCTAssertEqual(noFiles.currentContext?.episode.id, 5)
        XCTAssertEqual(noFiles.queue.index, 2)
        XCTAssertNil(noFiles.player)
        await finish(noFiles)
    }

    func testFailedNextRetainsPreviousCompletionAndItsOwnProgressUntilManualRetry() async throws {
        let environment = try ProgressTestEnvironment()
        let model = try makeModel(environment)
        defer { model.stopPlayback() }
        let snapshot = testQueue()
        let second = try XCTUnwrap(snapshot.context(at: 1))
        let fifth = try XCTUnwrap(snapshot.context(at: 2))
        model.progressStore.update(fifth, position: 2, duration: 4, event: .advance)
        model.denoiseLevel = .level50
        model.amplificationMultiplier = 3
        try Data("invalid-media".utf8).write(to: environment.directory.appendingPathComponent("5.wav"))
        model.selectPlayback(second, snapshot: snapshot)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        await model.seek(to: 3.8)
        model.resumePlayback()
        try await waitUntil { model.currentContext?.episode.id == 5 && model.session.phase == .failed }
        XCTAssertEqual(model.progressStore.record(for: second)?.state, .completed)
        XCTAssertEqual(model.progressStore.record(for: fifth)?.positionSeconds, 2)
        XCTAssertNil(model.player)
        XCTAssertEqual(model.queue.index, 2)
        XCTAssertEqual(model.denoiseLevel, .level50)
        XCTAssertEqual(model.amplificationMultiplier, 3)
        try silentWave().write(to: environment.directory.appendingPathComponent("5.wav"))
        model.retryPlayback()
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        XCTAssertGreaterThanOrEqual(model.currentPosition, 1.95)
        XCTAssertEqual(model.currentContext?.episode.id, 5)
        await finish(model)
    }

    func testLateSnapshotCannotAttachToNewSelectionOrDelayCurrentPlayer() async throws {
        let environment = try ProgressTestEnvironment()
        let old = testQueue(seriesID: 10), current = testQueue(seriesID: 20)
        var releaseLoad: CheckedContinuation<QueueSnapshotPersistence.Loaded, Error>?
        let queues = QueueSnapshotStore(root: environment.directory.appendingPathComponent("queues"), defaults: environment.defaults,
                                        reader: { try await withCheckedThrowingContinuation { releaseLoad = $0 } })
        for id in [1, 2, 5] { try silentWave().write(to: environment.directory.appendingPathComponent("\(id).wav")) }
        let progress = PlaybackProgressStore(persistence: FileProgressPersistence(root: environment.directory.appendingPathComponent("progress")))
        let model = PlayerViewModel(progressStore: progress, queueStore: queues, defaults: environment.defaults,
                                    localFile: { id, _ in environment.directory.appendingPathComponent("\(id).wav") },
                                    makeAudioProcessor: { _, _ in TestAudioProcessor() }, isOffline: { false })
        defer { releaseLoad?.resume(returning: .init()); model.stopPlayback() }
        model.selectPlayback(testContext(id: 1))
        try await waitUntil { releaseLoad != nil && !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        XCTAssertTrue(model.isRestoringQueue) // 本集已可播放，不等快照 I/O。
        model.selectPlayback(try XCTUnwrap(current.context(at: 1)), snapshot: current)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        releaseLoad?.resume(returning: .init(snapshots: [old], issueCount: 0))
        releaseLoad = nil
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.queue.snapshot?.id, current.id)
        XCTAssertEqual(model.currentContext?.series?.seriesID, 20)
        XCTAssertEqual(model.currentContext?.episode.id, 2)
        await finish(model)
    }

    func testHomeContinueRestoresLegacyEntrySeriesAndRetriesSameFailedTarget() async throws {
        let environment = try ProgressTestEnvironment()
        let model = try makeModel(environment, offline: true)
        defer { model.stopPlayback() }
        let snapshot = testQueue()
        let known = try XCTUnwrap(snapshot.context(at: 1, preferred: .audio))
        model.queueStore.register(snapshot)
        model.progressStore.update(known, position: 1.5, duration: 4, event: .advance)
        // 旧历史／下载入口只有原键；已有系列关联仍能贯通到首页动作。
        let oldEntry = testContext(id: 2)
        model.continueListening(oldEntry)
        XCTAssertTrue(model.isPreparingPlayback)
        let preparingRequest = model.session.request
        model.continueListening(oldEntry)
        XCTAssertEqual(model.session.request, preparingRequest)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        XCTAssertGreaterThanOrEqual(model.currentPosition, 1.45)
        XCTAssertEqual(model.currentContext?.series?.snapshotID, snapshot.id)
        let existing = model.player
        model.continueListening(oldEntry)
        XCTAssertTrue(model.player === existing)
        XCTAssertTrue(model.session.wantsPlayback)
        model.stopPlayback()
        try FileManager.default.removeItem(at: environment.directory.appendingPathComponent("2.wav"))
        model.continueListening(oldEntry)
        XCTAssertEqual(model.session.phase, .failed)
        try silentWave().write(to: environment.directory.appendingPathComponent("2.wav"))
        model.continueListening(oldEntry)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        XCTAssertEqual(model.currentContext?.episode.id, 2)
        XCTAssertTrue(model.session.wantsPlayback)
        XCTAssertEqual(model.queue.index, 1)
        await finish(model)
    }

    func testExplicitContinueOfEndedEpisodeRestartsFromZero() async throws {
        let environment = try ProgressTestEnvironment()
        let model = try makeModel(environment)
        defer { model.stopPlayback() }
        model.queueStore.autoAdvance = false
        let context = try XCTUnwrap(testQueue().context(at: 1))
        model.continueListening(context)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        await model.seek(to: 3.8)
        model.resumePlayback()
        try await waitUntil { model.session.phase == .ended }
        XCTAssertEqual(model.progressStore.record(for: context)?.state, .completed)
        let endedPlayer = model.player
        model.continueListening(context)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        XCTAssertFalse(model.player === endedPlayer)
        XCTAssertLessThan(model.currentPosition, 0.5)
        XCTAssertEqual(model.currentContext?.episode.id, context.episode.id)
        await finish(model)
    }

    func testFilteredEpisodeStillNaturallyAdvancesThroughFullLoadedQueue() async throws {
        let environment = try ProgressTestEnvironment()
        let model = try makeModel(environment)
        defer { model.stopPlayback() }
        let allEpisodes = testQueue().episodes
        let series = SeriesDetailViewModel(loader: { _ in searchDetail(allEpisodes, total: allEpisodes.count) })
        await series.loadSpeechDetail(url: "fixture", series: searchDestination)
        let snapshot = try XCTUnwrap(series.queueSnapshot)
        series.searchQuery = "2"
        XCTAssertEqual(series.visibleEpisodes.map(\.id), [2])
        let selected = try XCTUnwrap(series.visibleEpisodes.first)
        let index = try XCTUnwrap(snapshot.episodes.firstIndex(where: { $0.id == selected.id }))
        model.selectPlayback(try XCTUnwrap(snapshot.context(at: index)), snapshot: snapshot)
        try await waitUntil { !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        await model.seek(to: 3.8)
        model.resumePlayback()
        try await waitUntil { model.currentContext?.episode.id == 5 && !model.isPreparingPlayback && model.player?.currentItem?.status == .readyToPlay }
        model.pausePlayback()
        XCTAssertEqual(model.queue.snapshot?.episodes.map(\.id), [1, 2, 5])
        XCTAssertEqual(model.queue.snapshot?.id, snapshot.id)
        XCTAssertEqual(series.visibleEpisodes.map(\.id), [2])
        XCTAssertEqual(series.queueSnapshot, snapshot)
        await finish(model)
    }

    private func makeModel(_ environment: ProgressTestEnvironment, offline: Bool = false, audioOnly: Bool = false,
                           processor: (() -> any PlaybackAudioProcessing)? = nil) throws -> PlayerViewModel {
        for id in [1, 2, 5] { try silentWave().write(to: environment.directory.appendingPathComponent("\(id).wav")) }
        let progress = PlaybackProgressStore(persistence: FileProgressPersistence(root: environment.directory.appendingPathComponent("progress")))
        let queues = QueueSnapshotStore(root: environment.directory.appendingPathComponent("queues"), defaults: environment.defaults)
        return PlayerViewModel(progressStore: progress, queueStore: queues, defaults: environment.defaults,
                               localFile: { id, type in
                                   if audioOnly && type == .video { return nil }
                                   return environment.directory.appendingPathComponent("\(id).wav")
                               }, makeAudioProcessor: { _, _ in processor?() ?? TestAudioProcessor() }, isOffline: { offline })
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(8)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        if !condition() {
            XCTFail("Timed out waiting for real playback state")
            throw NSError(domain: "PlaybackTest", code: 1)
        }
    }

    private func finish(_ model: PlayerViewModel) async {
        model.stopPlayback()
        await model.progressStore.flush()
        await model.queueStore.flush()
    }

    private func silentWave() -> Data {
        let sampleCount: UInt32 = 8_000 * 4
        var data = Data()
        func text(_ string: String) { data.append(contentsOf: string.utf8) }
        func word<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        text("RIFF"); word(UInt32(36) + sampleCount * 2); text("WAVEfmt ")
        word(UInt32(16)); word(UInt16(1)); word(UInt16(1)); word(UInt32(8_000))
        word(UInt32(16_000)); word(UInt16(2)); word(UInt16(16)); text("data"); word(sampleCount * 2)
        data.append(Data(count: Int(sampleCount * 2)))
        return data
    }
}
