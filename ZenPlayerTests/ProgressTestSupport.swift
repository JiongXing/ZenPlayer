import Foundation

/// 每个测试独占目录和 defaults suite，不启动 App 或接触其容器。
final class ProgressTestEnvironment {
    let directory: URL
    let defaults: UserDefaults
    private let suite = "ZenPlayerTests.\(UUID().uuidString)"

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: suite)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

final class TestClock {
    var now = Date(timeIntervalSince1970: 1_000)
    var uptime: TimeInterval = 0
    func advance(_ seconds: Double) { now += seconds; uptime += seconds }
}

final class TestIOFaults {
    enum Point: CaseIterable { case temporaryWrite, readback, backup, replace, migrationBackup, migrationMarker }
    var failure: Point?
    func check(_ point: Point) throws {
        if failure == point { throw CocoaError(.fileWriteOutOfSpace) }
    }
}

func testContext(id: Int = 1, server: String = "https://EXAMPLE.test/") -> PlaybackContext {
    PlaybackContext(episode: EpisodeItem(id: id, num: "01-001-\(id)", title: "Fixture", episode: "\(id)", mp4Url: "video/\(id).mp4", vodUrl: "", mp3Url: "audio/\(id).mp3", coverUrl: "", textUrl: "", filesize: 0, duration: 300_000), serverUrl: server)
}
