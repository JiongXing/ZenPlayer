import XCTest

func testQueue(seriesID: Int = 10, ids: [Int] = [1, 2, 5], complete: Bool = true) -> QueueSnapshot {
    QueueSnapshot(seriesID: seriesID, title: "系列", detailURL: "https://example.test/series/\(seriesID)",
                  serverURL: testContext().serverUrl, episodes: ids.map { testContext(id: $0).episode }, isComplete: complete)
}

final class PlaybackQueueTests: XCTestCase {
    func testActualOrderBoundariesAndDuplicateEnd() throws {
        let snapshot = testQueue(complete: false)
        var queue = PlaybackQueueState()
        queue.select(try XCTUnwrap(snapshot.context(at: 1)), snapshot: snapshot)
        let token = UUID()
        queue.bindMedia(token)
        XCTAssertEqual(queue.context(offset: -1, preferred: .audio)?.episode.id, 1)
        XCTAssertEqual(queue.context(offset: 1, preferred: .audio)?.episode.id, 5)
        XCTAssertEqual(queue.snapshot?.isComplete, false)
        XCTAssertTrue(queue.consumeEnd(media: token, revision: queue.revision))
        XCTAssertFalse(queue.consumeEnd(media: token, revision: queue.revision))
        queue.select(try XCTUnwrap(snapshot.context(at: 2)), snapshot: snapshot)
        XCTAssertNil(queue.context(offset: 1, preferred: .audio))
        queue.select(try XCTUnwrap(snapshot.context(at: 0)), snapshot: snapshot)
        XCTAssertNil(queue.context(offset: -1, preferred: .video))
    }

    func testOldMediaAndQueueRevisionCannotConsumeCurrentEnd() throws {
        let snapshot = testQueue()
        var queue = PlaybackQueueState()
        queue.select(try XCTUnwrap(snapshot.context(at: 0)), snapshot: snapshot)
        let oldMedia = UUID(), currentMedia = UUID(), oldRevision = queue.revision
        queue.bindMedia(oldMedia)
        queue.select(try XCTUnwrap(snapshot.context(at: 1)), snapshot: snapshot)
        queue.bindMedia(currentMedia)
        XCTAssertFalse(queue.consumeEnd(media: oldMedia, revision: queue.revision))
        XCTAssertFalse(queue.consumeEnd(media: currentMedia, revision: oldRevision))
        XCTAssertTrue(queue.consumeEnd(media: currentMedia, revision: queue.revision))
    }

    func testInvalidIdentityAndLateSnapshotNeverChangeSelectedEpisode() throws {
        let snapshot = testQueue()
        XCTAssertFalse(testQueue(ids: [1, 1]).isValid)
        var queue = PlaybackQueueState()
        let selected = testContext(id: 99)
        queue.select(selected, snapshot: snapshot)
        XCTAssertNil(queue.snapshot)
        XCTAssertFalse(queue.attach(snapshot, to: selected))
        queue.select(testContext(id: 2, server: "https://example.test/"), snapshot: snapshot)
        XCTAssertNil(queue.snapshot) // 服务器原串不归一化。
        queue.select(testContext(id: 2), snapshot: nil)
        let token = UUID()
        queue.bindMedia(token)
        XCTAssertTrue(queue.consumeEnd(media: token, revision: queue.revision))
        XCTAssertTrue(queue.attach(snapshot, to: testContext(id: 2)))
        XCTAssertFalse(queue.consumeEnd(media: token, revision: queue.revision))
    }

    func testOldContextDecodesAndQueueReferenceDoesNotEmbedEpisodes() throws {
        let old = testContext()
        let oldData = try JSONEncoder().encode(old)
        XCTAssertNil(try JSONDecoder().decode(PlaybackContext.self, from: oldData).series)
        let snapshot = testQueue()
        let context = try XCTUnwrap(snapshot.context(at: 1))
        let encoded = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(PlaybackContext.self, from: encoded)
        XCTAssertEqual(decoded.series?.index, 1)
        XCTAssertEqual(decoded.series?.snapshotID, snapshot.id)
        XCTAssertEqual(RecentPlaybackRecord.recordID(for: decoded), RecentPlaybackRecord.recordID(for: testContext(id: 2)))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil((json["series"] as? [String: Any])?["episodes"])
    }

    func testNextEpisodeUsesItsOwnResumeStateWithoutSkippingCompleted() throws {
        let snapshot = testQueue()
        var queue = PlaybackQueueState()
        queue.select(try XCTUnwrap(snapshot.context(at: 1)), snapshot: snapshot)
        let next = try XCTUnwrap(queue.context(offset: 1, preferred: .video))
        var progress = PlaybackProgress(context: next, now: Date())
        progress.update(position: 72, mediaDuration: 300, event: .advance, now: Date())
        XCTAssertEqual(progress.resumePosition, 72)
        progress.update(position: 300, mediaDuration: 300, event: .ended, now: Date())
        XCTAssertEqual(progress.resumePosition, 0)
        XCTAssertEqual(next.episode.id, 5)
        XCTAssertEqual(next.preferredMediaType, .video)
    }
    func testBrokenOptionalSeriesMetadataCannotEraseValidLegacyContext() throws {
        let data = try JSONEncoder().encode(testContext())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["series"] = ["snapshotID": "broken"]
        let decoded = try JSONDecoder().decode(PlaybackContext.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.series)
        XCTAssertEqual(decoded.episode, testContext().episode)
        XCTAssertEqual(decoded.serverUrl, testContext().serverUrl)
    }

}
