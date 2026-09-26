import XCTest

final class PlaybackProgressTests: XCTestCase {
    @MainActor
    func testThirtyRecordsAndListeningTimeIndependentOfWrites() async throws {
        let clock = TestClock()
        var records = (1...30).map { id -> PlaybackProgress in
            clock.advance(1)
            var record = PlaybackProgress(context: testContext(id: id), now: clock.now)
            record.update(position: 20, mediaDuration: nil, event: .advance, now: clock.now)
            return record
        }
        XCTAssertEqual(records.count, 30)
        XCTAssertEqual(PlaybackProgress.recent(records).map { $0.context.episode.id }, Array((21...30).reversed()))
        let listened = records[0].lastListenedAt
        clock.advance(10)
        records[0].update(position: 25, mediaDuration: nil, event: .position, now: clock.now)
        XCTAssertEqual(records[0].lastListenedAt, listened)
        XCTAssertEqual(PlaybackProgress.recent(records).first?.context.episode.id, 30)
        records[0].update(position: 26, mediaDuration: nil, event: .advance, now: clock.now)
        XCTAssertEqual(PlaybackProgress.recent(records).first?.context.episode.id, 1)
    }

    @MainActor
    func testCompletionReplayAndInvalidValues() async throws {
        var record = PlaybackProgress(context: testContext(), now: Date())
        record.update(position: 290, mediaDuration: 300, event: .position, now: Date())
        XCTAssertNotEqual(record.state, .completed)
        record.update(position: 290, mediaDuration: 300, event: .ended, now: Date())
        XCTAssertEqual(record.state, .completed)
        XCTAssertEqual(record.resumePosition, 0)
        let completed = record
        record.update(position: 0, mediaDuration: 300, event: .position, now: Date())
        XCTAssertEqual(record, completed)
        record.update(position: 1, mediaDuration: 200, event: .advance, now: Date())
        XCTAssertEqual(record.state, .inProgress)
        XCTAssertEqual(record.durationSeconds, 200)
        let valid = record
        for value in [Double.nan, .infinity, -1] {
            record.update(position: value, mediaDuration: nil, event: .position, now: Date())
            XCTAssertEqual(record, valid)
        }
        var unknown = try JSONDecoder().decode([RecentPlaybackRecord].self, from: fixture("legacy-representative"))[0]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(unknown)) as? [String: Any])
        var context = object["context"] as! [String: Any]
        var episode = context["episode"] as! [String: Any]; episode["duration"] = 0
        context["episode"] = episode; object["context"] = context
        unknown = try JSONDecoder().decode(RecentPlaybackRecord.self, from: JSONSerialization.data(withJSONObject: object))
        var progress = PlaybackProgress(legacy: unknown)
        progress.update(position: 42, mediaDuration: nil, event: .ended, now: Date())
        XCTAssertEqual(progress.state, .completed)
        XCTAssertNil(progress.durationSeconds)
        XCTAssertEqual(try JSONDecoder().decode(PlaybackProgress.self, from: JSONEncoder().encode(progress)), progress)
    }
}

extension PlaybackProgressTests {
    @MainActor
    func testExtremeFiniteLegacyPositionCanBeDisplayedWithoutLosingRawValue() async throws {
        let legacy = RecentPlaybackRecord(context: testContext(), playedAt: Date(), resumePositionSeconds: .greatestFiniteMagnitude)
        let progress = PlaybackProgress(legacy: legacy)
        XCTAssertTrue(progress.isValid)
        XCTAssertEqual(progress.positionSeconds, .greatestFiniteMagnitude)
        XCTAssertFalse(EpisodeItem.formatPlaybackDuration(seconds: .greatestFiniteMagnitude).isEmpty)
        XCTAssertEqual(EpisodeItem.formatPlaybackDuration(seconds: .nan), "0:00")
        XCTAssertEqual(EpisodeItem.formatPlaybackDuration(seconds: -.infinity), "0:00")
    }
}
