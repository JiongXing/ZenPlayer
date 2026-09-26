import XCTest

final class LegacyProgressTests: XCTestCase {
    @MainActor
    func testLegacyKeyAndMissingPositionRemainCompatible() async throws {
        let environment = try ProgressTestEnvironment()
        let context = testContext()
        let record = RecentPlaybackRecord(context: context, playedAt: Date(timeIntervalSinceReferenceDate: 10), resumePositionSeconds: 120)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        json.removeValue(forKey: "resumePositionSeconds")
        let data = try JSONSerialization.data(withJSONObject: [json])
        environment.defaults.set(data, forKey: "recentPlayback.records")
        let restored = try JSONDecoder().decode([RecentPlaybackRecord].self, from: XCTUnwrap(environment.defaults.data(forKey: "recentPlayback.records")))
        XCTAssertEqual(restored[0].id, "1|https://EXAMPLE.test/")
        XCTAssertEqual(restored[0].resumePositionSeconds, 0)
        XCTAssertNil(restored[0].context.preferredMediaType)
        XCTAssertNotEqual(restored[0].id, RecentPlaybackRecord.recordID(for: testContext(server: "https://example.test/")))
        XCTAssertNotEqual(restored[0].id, RecentPlaybackRecord.recordID(for: testContext(server: "https://EXAMPLE.test")))
        XCTAssertEqual(environment.defaults.data(forKey: "recentPlayback.records"), data)
    }
}

extension LegacyProgressTests {
    @MainActor
    func testCapturedSeriesHaveDistinctLegacyKeysAndRoundTrip() async throws {
        let data = try fixture("legacy-representative")
        let records = try JSONDecoder().decode([RecentPlaybackRecord].self, from: data)
        let ledger = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture("identity-ledger")) as? [[String: String]])
        XCTAssertEqual(records.count, 16)
        XCTAssertEqual(Set(records.map(\.id)).count, 16)
        XCTAssertEqual(Set(records.map { $0.context.episode.num.prefix(6) }).count, 3)
        XCTAssertEqual(records.map(\.id), ledger.compactMap { $0["key"] })
        XCTAssertEqual(try JSONDecoder().decode([RecentPlaybackRecord].self, from: JSONEncoder().encode(records)), records)
    }

    @MainActor
    func testMixedFixturePreservesSourceAndDecodesItemsIndependently() async throws {
        let data = try fixture("legacy-mixed")
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [Any])
        let records = objects.compactMap { object -> RecentPlaybackRecord? in
            guard let bytes = try? JSONSerialization.data(withJSONObject: object) else { return nil }
            return try? JSONDecoder().decode(RecentPlaybackRecord.self, from: bytes)
        }
        XCTAssertEqual(objects.count, 5)
        XCTAssertEqual(records.count, 4)
        XCTAssertEqual(records[1].resumePositionSeconds, 0)
        XCTAssertEqual(records[0].id, records[2].id)
        XCTAssertGreaterThan(records[2].playedAt, records[0].playedAt)
        XCTAssertEqual(records[3].context.episode.duration, 0)
        XCTAssertThrowsError(try JSONDecoder().decode([RecentPlaybackRecord].self, from: fixture("legacy-broken")))
    }
}

func fixture(_ name: String) throws -> Data {
    let url = Bundle(for: LegacyProgressTests.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        ?? Bundle(for: LegacyProgressTests.self).url(forResource: name, withExtension: "json")
    return try Data(contentsOf: XCTUnwrap(url))
}
