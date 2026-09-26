import XCTest

final class ProgressMigrationTests: XCTestCase {
    @MainActor
    func testMixedMigrationBackupDedupAndReentryProtectNewerProgress() async throws {
        let env = try ProgressTestEnvironment()
        let data = try fixture("legacy-mixed")
        let disk = FileProgressPersistence(root: env.directory)
        let first = try disk.migrate(source: data)
        XCTAssertEqual(first.records.count, 3)
        XCTAssertEqual(first.isolatedIndices, [3])
        XCTAssertEqual(first.duplicateCount, 1)
        let key = first.records[0].id
        let backup = env.directory.appendingPathComponent("migration/\(FileProgressPersistence.digest(data)).source")
        XCTAssertEqual(try Data(contentsOf: backup), data)
        var new = try XCTUnwrap(disk.load().records.first { $0.id == key })
        new.update(position: 199, mediaDuration: nil, event: .advance, now: Date())
        _ = try await disk.commit(new)
        _ = try disk.migrate(source: data)
        XCTAssertEqual(try disk.load().records.first { $0.id == key }?.positionSeconds, 199)
        XCTAssertEqual(try disk.load().records.count, 3)
    }

    @MainActor
    func testMigrationFailuresRemainRetryableAndNeverDeleteSource() async throws {
        for point in [TestIOFaults.Point.migrationBackup, .temporaryWrite, .readback, .replace, .migrationMarker] {
            let env = try ProgressTestEnvironment()
            let data = try fixture("legacy-representative")
            env.defaults.set(data, forKey: "recentPlayback.records")
            let faults = TestIOFaults(); faults.failure = point
            let disk = FileProgressPersistence(root: env.directory) { stage in
                if stage == faults.failure?.persistencePoint { throw CocoaError(.fileWriteOutOfSpace) }
            }
            XCTAssertThrowsError(try disk.migrate(source: data))
            XCTAssertEqual(env.defaults.data(forKey: "recentPlayback.records"), data)
            let marker = env.directory.appendingPathComponent("migration/\(FileProgressPersistence.digest(data)).complete.json")
            XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
            faults.failure = nil
            _ = try disk.migrate(source: data)
            XCTAssertEqual(try disk.load().records.count, 16)
            XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        }
    }

    @MainActor
    func testBrokenSourceAndIdentityCollisionArePreservedWithoutSuccessMarker() async throws {
        let env = try ProgressTestEnvironment()
        let disk = FileProgressPersistence(root: env.directory)
        let broken = try fixture("legacy-broken")
        XCTAssertThrowsError(try disk.migrate(source: broken))
        XCTAssertEqual(try Data(contentsOf: env.directory.appendingPathComponent("migration/\(FileProgressPersistence.digest(broken)).source")), broken)
        var objects = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture("legacy-mixed")) as? [[String: Any]])
        var context = objects[2]["context"] as! [String: Any]
        var episode = context["episode"] as! [String: Any]; episode["num"] = "different-series-001"
        context["episode"] = episode; objects[2]["context"] = context
        let collision = try JSONSerialization.data(withJSONObject: objects)
        XCTAssertThrowsError(try disk.migrate(source: collision))
        XCTAssertTrue(try disk.load().records.isEmpty)
    }

    @MainActor
    func testUnreadableNewFileCannotBeOverwrittenByOldMigration() async throws {
        let env = try ProgressTestEnvironment()
        let disk = FileProgressPersistence(root: env.directory)
        let source = try fixture("legacy-representative")
        let first = try JSONDecoder().decode([RecentPlaybackRecord].self, from: source)[0]
        _ = try disk.load()
        let url = disk.recordURL(first.id)
        let broken = Data("broken".utf8)
        try broken.write(to: url)
        XCTAssertThrowsError(try disk.migrate(source: source))
        XCTAssertEqual(try Data(contentsOf: url), broken)
    }
}

extension ProgressMigrationTests {
    @MainActor
    func testInterruptedMigrationKeepsPlaybackWrittenBeforeReentry() async throws {
        let env = try ProgressTestEnvironment()
        var writes = 0
        var interrupt = true
        let disk = FileProgressPersistence(root: env.directory) { point in
            if point == .temporaryWrite { writes += 1; if interrupt && writes == 2 { throw CocoaError(.fileWriteOutOfSpace) } }
        }
        let source = try fixture("legacy-representative")
        XCTAssertThrowsError(try disk.migrate(source: source))
        var record = try XCTUnwrap(disk.load().records.first)
        XCTAssertEqual(try disk.load().records.count, 1)
        interrupt = false
        record.update(position: 211, mediaDuration: nil, event: .advance, now: Date())
        _ = try await disk.commit(record)
        _ = try disk.migrate(source: source)
        XCTAssertEqual(try disk.load().records.count, 16)
        XCTAssertEqual(try disk.load().records.first { $0.id == record.id }, record)
    }

    @MainActor
    func testLegacyEndInferencePreservesRawPositionAndStableDuplicateTie() async throws {
        var rows = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture("legacy-mixed")) as? [[String: Any]])
        rows[2]["playedAt"] = rows[0]["playedAt"]
        rows[0]["resumePositionSeconds"] = 100_000
        rows[1]["resumePositionSeconds"] = -1
        let mapped = try LegacyProgressMigration.map(JSONSerialization.data(withJSONObject: rows))
        let completed = try XCTUnwrap(mapped.records.first { $0.positionSeconds == 100_000 })
        XCTAssertEqual(completed.state, .completed)
        XCTAssertEqual(completed.resumePosition, 0)
        XCTAssertEqual(mapped.isolatedIndices, [1, 3])
        XCTAssertEqual(mapped.duplicateCount, 1)
    }
}
