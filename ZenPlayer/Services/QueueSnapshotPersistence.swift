import Foundation

/// 派生播放上下文独立于长期进度；I/O 在 actor executor 上串行执行。
actor QueueSnapshotPersistence {
    struct Loaded {
        var snapshots: [QueueSnapshot] = []
        var issueCount = 0
    }
    private let root: URL

    init(root: URL) { self.root = root }

    func load() throws -> Loaded {
        guard FileManager.default.fileExists(atPath: root.path) else { return Loaded() }
        var result = Loaded()
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where url.pathExtension == "json" {
            do {
                let snapshot = try JSONDecoder().decode(QueueSnapshot.self, from: Data(contentsOf: url))
                guard snapshot.isValid, url.deletingPathExtension().lastPathComponent == snapshot.id else {
                    result.issueCount += 1
                    continue
                }
                result.snapshots.append(snapshot)
            } catch { result.issueCount += 1 }
        }
        return result
    }

    func save(_ snapshot: QueueSnapshot) throws {
        guard snapshot.isValid else { throw CocoaError(.fileWriteInvalidFileName) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(snapshot.id + ".json")
        if FileManager.default.fileExists(atPath: url.path) {
            // 版本不可变；不能覆盖损坏、未知版本或不匹配的现有文件。
            let existing = try JSONDecoder().decode(QueueSnapshot.self, from: Data(contentsOf: url))
            guard existing == snapshot else { throw CocoaError(.fileWriteFileExists) }
            return
        }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}
