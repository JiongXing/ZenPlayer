import XCTest

final class ProgressPersistenceTests: XCTestCase {
    @MainActor
    func testThirtyRecordsSurviveRestartAndCorruptionIsIsolated() async throws {
        let env = try ProgressTestEnvironment()
        let disk = FileProgressPersistence(root: env.directory)
        for id in 1...30 {
            var record = PlaybackProgress(context: testContext(id: id), now: Date())
            record.update(position: Double(id), mediaDuration: nil, event: .advance, now: Date())
            _ = try await disk.commit(record)
        }
        let reopened = FileProgressPersistence(root: env.directory)
        XCTAssertEqual(try reopened.load().records.count, 30)
        let first = try XCTUnwrap(reopened.load().records.first { $0.context.episode.id == 1 })
        var newer = first
        newer.update(position: 100, mediaDuration: nil, event: .position, now: Date())
        _ = try await reopened.commit(newer)
        try Data("broken".utf8).write(to: reopened.recordURL(first.legacyKey))
        let loaded = try reopened.load()
        XCTAssertEqual(loaded.records.count, 30)
        XCTAssertEqual(loaded.records.first { $0.id == first.id }?.positionSeconds, 1)
        XCTAssertFalse(loaded.issues.isEmpty)
        _ = try await reopened.commit(newer)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: env.directory.appendingPathComponent("records").path).contains { $0.contains(".corrupt-") })
    }

    @MainActor
    func testFailuresKeepLastCommittedRecordAndUnknownVersion() async throws {
        let env = try ProgressTestEnvironment()
        let faults = TestIOFaults()
        let disk = FileProgressPersistence(root: env.directory, fault: { point in
            if point == faults.failure?.persistencePoint { throw CocoaError(.fileWriteOutOfSpace) }
        })
        var record = PlaybackProgress(context: testContext(), now: Date())
        record.update(position: 100, mediaDuration: nil, event: .advance, now: Date())
        _ = try await disk.commit(record)
        let original = try Data(contentsOf: disk.recordURL(record.id))
        record.update(position: 120, mediaDuration: nil, event: .position, now: Date())
        for point in [TestIOFaults.Point.temporaryWrite, .readback, .backup, .replace] {
            faults.failure = point
            do { _ = try await disk.commit(record); XCTFail("Expected \(point)") } catch { }
            XCTAssertEqual(try Data(contentsOf: disk.recordURL(record.id)), original)
        }
        faults.failure = nil
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        object["schemaVersion"] = 999
        let future = try JSONSerialization.data(withJSONObject: object)
        try future.write(to: disk.recordURL(record.id))
        XCTAssertEqual(try disk.load().records.first?.positionSeconds, 100)
        XCTAssertTrue(try disk.load().issues.contains { $0.hasPrefix("unsupported:") })
        do { _ = try await disk.commit(record); XCTFail("Future schema must stay untouched") } catch { }
        XCTAssertEqual(try Data(contentsOf: disk.recordURL(record.id)), future)
    }
}

extension TestIOFaults.Point {
    var persistencePoint: FileProgressPersistence.FaultPoint {
        switch self {
        case .temporaryWrite: return .temporaryWrite
        case .readback: return .readback
        case .backup: return .backup
        case .replace: return .replace
        case .migrationBackup: return .migrationBackup
        case .migrationMarker: return .migrationMarker
        }
    }
}

extension ProgressPersistenceTests {
    @MainActor
    func testBothCopiesCorruptAndInterruptedTemporaryFileDoNotEraseOtherKeys() async throws {
        let env = try ProgressTestEnvironment()
        let disk = FileProgressPersistence(root: env.directory)
        var first = PlaybackProgress(context: testContext(), now: Date())
        first.update(position: 100, mediaDuration: nil, event: .advance, now: Date())
        _ = try await disk.commit(first)
        let second = PlaybackProgress(context: testContext(id: 2), now: Date())
        _ = try await disk.commit(second)
        let main = disk.recordURL(first.id)
        let backup = main.deletingPathExtension().appendingPathExtension("bak")
        let broken = Data("broken".utf8)
        try broken.write(to: main)
        try broken.write(to: backup)
        try broken.write(to: main.deletingLastPathComponent().appendingPathComponent(".pending-interrupted"))
        let loaded = try disk.load()
        XCTAssertEqual(loaded.records, [second])
        do { _ = try await disk.commit(first); XCTFail("Must preserve corrupt sources") } catch { }
        XCTAssertEqual(try Data(contentsOf: main), broken)
        XCTAssertEqual(try Data(contentsOf: backup), broken)
    }
}
