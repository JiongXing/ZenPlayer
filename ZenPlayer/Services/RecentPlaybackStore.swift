//
//  RecentPlaybackStore.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import Foundation

@MainActor
@Observable
final class RecentPlaybackStore {
    static let shared = RecentPlaybackStore()

    private enum StorageKeys {
        static let recentPlaybackRecords = "recentPlayback.records"
    }

    private let maxRecordCount = 10
    private let userDefaults: UserDefaults

    var records: [RecentPlaybackRecord] = []

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadRecords()
    }

    func loadRecords() {
        guard let data = userDefaults.data(forKey: StorageKeys.recentPlaybackRecords) else {
            records = []
            return
        }

        do {
            records = try JSONDecoder().decode([RecentPlaybackRecord].self, from: data)
        } catch {
            records = []
            userDefaults.removeObject(forKey: StorageKeys.recentPlaybackRecords)
        }
    }

    func recordPlayback(_ context: PlaybackContext) {
        var updatedRecords = records.filter { $0.id != RecentPlaybackRecord.recordID(for: context) }
        updatedRecords.insert(
            RecentPlaybackRecord(context: context, playedAt: Date()),
            at: 0
        )
        records = Array(updatedRecords.prefix(maxRecordCount))
        persistRecords()
    }

    private func persistRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            userDefaults.set(data, forKey: StorageKeys.recentPlaybackRecords)
        } catch {
            userDefaults.removeObject(forKey: StorageKeys.recentPlaybackRecords)
        }
    }
}
