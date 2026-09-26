import Foundation

nonisolated enum LegacyProgressMigration {
    enum MigrationError: Error { case invalidSource, ambiguousIdentity, occupiedUnreadableKey }
    struct Mapping {
        var records: [PlaybackProgress]
        var isolatedIndices: [Int]
        var duplicateCount: Int
    }

    static func map(_ data: Data) throws -> Mapping {
        guard let array = try JSONSerialization.jsonObject(with: data) as? [Any] else { throw MigrationError.invalidSource }
        var records: [String: PlaybackProgress] = [:]
        var isolated: [Int] = []
        var duplicates = 0
        for (index, object) in array.enumerated() {
            guard JSONSerialization.isValidJSONObject(object),
                  let bytes = try? JSONSerialization.data(withJSONObject: object),
                  let old = try? JSONDecoder().decode(RecentPlaybackRecord.self, from: bytes),
                  PlaybackProgress(legacy: old).isValid else {
                isolated.append(index)
                continue
            }
            let candidate = PlaybackProgress(legacy: old)
            if let existing = records[candidate.id] {
                // num 是现有抓包中的内容身份辅助证据；不按标题猜测合并。
                guard existing.context.episode.num == candidate.context.episode.num else { throw MigrationError.ambiguousIdentity }
                duplicates += 1
                if candidate.updatedAt <= existing.updatedAt { continue }
            }
            records[candidate.id] = candidate
        }
        return Mapping(records: records.values.sorted { $0.id < $1.id }, isolatedIndices: isolated, duplicateCount: duplicates)
    }
}
