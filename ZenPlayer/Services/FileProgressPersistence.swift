import Foundation
import CryptoKit
import Darwin

/// 全部文件操作由同一队列串行执行；没有跨 await 的文件事务。
nonisolated final class FileProgressPersistence: @unchecked Sendable {
    enum FaultPoint { case temporaryWrite, readback, backup, replace, migrationBackup, migrationMarker }
    enum StorageError: Error { case invalidRecord, unsupportedVersion, unreadableRecord, verification, replacement(Int32) }
    struct LoadResult {
        var records: [PlaybackProgress] = []
        var issues: [String] = []
        var occupied = Set<String>()
    }
    let root: URL
    private let queue = DispatchQueue(label: "ZenPlayer.PlaybackProgress.disk")
    private let fault: (FaultPoint) throws -> Void
    private let manager = FileManager.default

    init(root: URL, fault: @escaping (FaultPoint) throws -> Void = { _ in }) {
        self.root = root
        self.fault = fault
    }

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    func recordURL(_ key: String) -> URL { root.appendingPathComponent("records").appendingPathComponent(Self.digest(Data(key.utf8)) + ".json") }
    private func backupURL(_ url: URL) -> URL { url.deletingPathExtension().appendingPathExtension("bak") }

    private func decode(_ url: URL) throws -> PlaybackProgress {
        let data = try Data(contentsOf: url)
        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = object["schemaVersion"] as? Int, version != 1 {
            throw StorageError.unsupportedVersion
        }
        let record = try JSONDecoder().decode(PlaybackProgress.self, from: data)
        guard record.isValid, url.deletingPathExtension().lastPathComponent == Self.digest(Data(record.legacyKey.utf8)) else {
            throw StorageError.invalidRecord
        }
        return record
    }

    func load() throws -> LoadResult { try queue.sync { try loadOnQueue() } }

    private func loadOnQueue() throws -> LoadResult {
        let directory = root.appendingPathComponent("records")
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let stems = Set(files.filter { ["json", "bak"].contains($0.pathExtension) }.map { $0.deletingPathExtension().lastPathComponent })
        var result = LoadResult()
        for stem in stems.sorted() {
            result.occupied.insert(stem)
            let main = directory.appendingPathComponent(stem + ".json")
            do { result.records.append(try decode(main)) }
            catch StorageError.unsupportedVersion {
                if let backup = try? decode(backupURL(main)) { result.records.append(backup) }
                result.issues.append("unsupported:\(stem)")
            }
            catch {
                if let backup = try? decode(backupURL(main)) {
                    result.records.append(backup)
                    result.issues.append("backup:\(stem)")
                } else { result.issues.append("unreadable:\(stem)") }
            }
        }
        return result
    }

    func commitSynchronously(_ record: PlaybackProgress) throws -> UInt64 {
        try queue.sync { try commitOnQueue(record) }
    }

    func commit(_ record: PlaybackProgress) async throws -> UInt64 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try self.commitOnQueue(record)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func commitOnQueue(_ record: PlaybackProgress) throws -> UInt64 {
        guard record.isValid else { throw StorageError.invalidRecord }
        let url = recordURL(record.id)
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var old: PlaybackProgress?
        if manager.fileExists(atPath: url.path) {
            do { old = try decode(url) }
            catch StorageError.unsupportedVersion { throw StorageError.unsupportedVersion }
            catch {
                // 只允许从有效备份前向修复，原损坏字节独立留存。
                guard let backup = try? decode(backupURL(url)) else { throw StorageError.unreadableRecord }
                let quarantine = url.appendingPathExtension("corrupt-\(UUID().uuidString)")
                try manager.copyItem(at: url, to: quarantine)
                old = backup
            }
        } else if manager.fileExists(atPath: backupURL(url).path) {
            old = try decode(backupURL(url))
        }
        if let old, old.revision > record.revision { return old.revision }
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".pending-\(UUID().uuidString)")
        defer { try? manager.removeItem(at: temporary) }
        try fault(.temporaryWrite)
        let data = try JSONEncoder().encode(record)
        try data.write(to: temporary, options: .atomic)
        try fault(.readback)
        guard try JSONDecoder().decode(PlaybackProgress.self, from: Data(contentsOf: temporary)) == record else { throw StorageError.verification }
        if let old {
            try fault(.backup)
            try JSONEncoder().encode(old).write(to: backupURL(url), options: .atomic)
        }
        try fault(.replace)
        // POSIX rename 同卷原子替换：失败不先 unlink 目标文件。
        guard rename(temporary.path, url.path) == 0 else { throw StorageError.replacement(errno) }
        guard try decode(url) == record else { throw StorageError.verification }
        return record.revision
    }
}

extension FileProgressPersistence {
    func migrate(source: Data) throws -> LegacyProgressMigration.Mapping {
        try queue.sync {
            let directory = root.appendingPathComponent("migration")
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let digest = Self.digest(source)
            let backup = directory.appendingPathComponent(digest + ".source")
            try fault(.migrationBackup)
            if !manager.fileExists(atPath: backup.path) { try source.write(to: backup, options: .atomic) }
            guard try Data(contentsOf: backup) == source else { throw StorageError.verification }
            let mapping = try LegacyProgressMigration.map(source)
            let loaded = try loadOnQueue()
            let existing = Dictionary(uniqueKeysWithValues: loaded.records.map { ($0.id, $0) })
            var inserted: [String] = []
            var protected: [String] = []
            for record in mapping.records {
                if existing[record.id] != nil { protected.append(record.id); continue }
                guard !loaded.occupied.contains(Self.digest(Data(record.id.utf8))) else {
                    throw LegacyProgressMigration.MigrationError.occupiedUnreadableKey
                }
                _ = try commitOnQueue(record)
                guard try decode(recordURL(record.id)) == record else { throw StorageError.verification }
                inserted.append(record.id)
            }
            guard Set(inserted + protected) == Set(mapping.records.map(\.id)) else { throw StorageError.verification }
            let report: [String: Any] = ["schemaVersion": 1, "sourceDigest": digest,
                "inserted": inserted, "protected": protected, "isolatedIndices": mapping.isolatedIndices,
                "duplicateCount": mapping.duplicateCount, "validCount": mapping.records.count]
            try fault(.migrationMarker)
            try JSONSerialization.data(withJSONObject: report, options: .sortedKeys)
                .write(to: directory.appendingPathComponent(digest + ".complete.json"), options: .atomic)
            return mapping
        }
    }
}
