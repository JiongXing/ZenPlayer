import XCTest

final class ResumeCandidateTests: XCTestCase {
    func testActiveSessionWinsAndFailureNeverCreatesFakeHistory() {
        var session = PlaybackSessionState()
        session.select(testContext(id: 99), now: 0)
        let records = [listened(1, at: 1)]
        XCTAssertEqual(ResumeCandidatePolicy.candidate(session: session, position: 20, records: records, nextSnapshot: nil)?.context.episode.id, 99)
        session.fail(request: session.request)
        XCTAssertEqual(ResumeCandidatePolicy.candidate(session: session, position: 0, records: records, nextSnapshot: nil)?.context.episode.id, 1)
        XCTAssertNil(ResumeCandidatePolicy.candidate(session: session, position: 0, records: [], nextSnapshot: nil))
    }

    func testLatestIncompleteWinsAndZeroPreloadIsExcluded() {
        let older = listened(1, at: 1), latest = listened(2, at: 2)
        let preload = PlaybackProgress(context: testContext(id: 99), now: Date(timeIntervalSince1970: 100))
        let candidate = ResumeCandidatePolicy.candidate(session: .init(), position: 0, records: [older, preload, latest], nextSnapshot: nil)
        XCTAssertEqual(candidate?.context.episode.id, 2)
        XCTAssertEqual(candidate?.kind, .resume)
        XCTAssertNil(ResumeCandidatePolicy.candidate(session: .init(), position: 0, records: [preload], nextSnapshot: nil))
    }

    func testCompletedLatestUsesOnlyImmediateUnfinishedNextAndItsOwnPosition() throws {
        let snapshot = testQueue()
        var latest = listened(2, at: 2)
        latest.context = try XCTUnwrap(snapshot.context(at: 1))
        latest.update(position: 300, mediaDuration: 300, event: .ended, now: Date(timeIntervalSince1970: 3))
        let next = listened(5, at: 1, position: 42)
        var candidate = ResumeCandidatePolicy.candidate(session: .init(), position: 0, records: [latest, next], nextSnapshot: snapshot)
        XCTAssertEqual(candidate?.kind, .next)
        XCTAssertEqual(candidate?.context.episode.id, 5)
        XCTAssertEqual(candidate?.position, 42)
        var completedNext = next
        completedNext.update(position: 300, mediaDuration: 300, event: .ended, now: Date(timeIntervalSince1970: 3))
        candidate = ResumeCandidatePolicy.candidate(session: .init(), position: 0, records: [latest, completedNext, listened(9, at: 0)], nextSnapshot: snapshot)
        XCTAssertEqual(candidate?.context.episode.id, 9)
        XCTAssertEqual(candidate?.kind, .resume)
        XCTAssertNil(ResumeCandidatePolicy.candidate(session: .init(), position: 0, records: [latest, completedNext], nextSnapshot: snapshot))
    }

    func testMissingQueueFallsBackToOtherUnfinishedAndUnknownDurationRemainsUnknown() {
        var completed = listened(2, at: 2)
        completed.update(position: 300, mediaDuration: 300, event: .ended, now: Date())
        var old = listened(1, at: 1, position: 61)
        old.durationSeconds = nil
        let result = ResumeCandidatePolicy.candidate(session: .init(), position: 0, records: [completed, old], nextSnapshot: nil)
        XCTAssertEqual(result?.context.episode.id, 1)
        XCTAssertNil(result?.duration)
        XCTAssertEqual(result?.position, 61)
    }

    func testSeriesLatestUsesAllLongTermRecordsAndRawServerIdentity() {
        let records = (1...30).map { listened($0, at: Double($0)) }
        let episodes = [testContext(id: 1).episode, testContext(id: 2).episode]
        XCTAssertEqual(ResumeCandidatePolicy.latestInSeries(episodes: episodes, serverURL: testContext().serverUrl, records: records)?.context.episode.id, 2)
        XCTAssertNil(ResumeCandidatePolicy.latestInSeries(episodes: episodes, serverURL: "https://example.test/", records: records))
    }

    func testSameListeningTimestampUsesStableLegacyKey() {
        let a = listened(1, at: 1), b = listened(2, at: 1)
        XCTAssertEqual(ResumeCandidatePolicy.latest([b, a])?.legacyKey, a.legacyKey)
    }

    func testHistorySeriesDestinationPreservesExplicitIdentityAndTarget() throws {
        let context = try XCTUnwrap(testQueue().context(at: 1))
        let reference = try XCTUnwrap(context.series)
        let route = SeriesDestination(reference: reference, targetEpisodeID: context.episode.id)
        XCTAssertEqual(route.id, reference.seriesID)
        XCTAssertEqual(route.url, reference.detailURL)
        XCTAssertEqual(route.title, reference.title)
        XCTAssertEqual(route.targetEpisodeID, 2)
    }

    private func listened(_ id: Int, at seconds: Double, position: Double = 10) -> PlaybackProgress {
        var record = PlaybackProgress(context: testContext(id: id), now: Date(timeIntervalSince1970: seconds))
        record.update(position: position, mediaDuration: 300, event: .advance, now: Date(timeIntervalSince1970: seconds))
        return record
    }
}
