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
        let existingRecord = record(for: context)
        upsertRecord(
            RecentPlaybackRecord(
                context: context,
                playedAt: Date(),
                resumePositionSeconds: existingRecord?.resumePositionSeconds ?? 0
            ),
            moveToFront: true
        )
    }

    func record(for context: PlaybackContext) -> RecentPlaybackRecord? {
        records.first { $0.id == RecentPlaybackRecord.recordID(for: context) }
    }

    func updateProgress(for context: PlaybackContext, resumePositionSeconds: Double) {
        let currentPlayedAt = record(for: context)?.playedAt ?? Date()
        upsertRecord(
            RecentPlaybackRecord(
                context: context,
                playedAt: currentPlayedAt,
                resumePositionSeconds: max(0, resumePositionSeconds)
            ),
            moveToFront: false
        )
    }

    func markPlaybackCompleted(for context: PlaybackContext) {
        updateProgress(
            for: context,
            resumePositionSeconds: context.episode.playbackDurationSeconds
        )
    }

    private func upsertRecord(_ record: RecentPlaybackRecord, moveToFront: Bool) {
        var updatedRecords = records.filter { $0.id != record.id }
        if moveToFront {
            updatedRecords.insert(record, at: 0)
        } else if let existingIndex = records.firstIndex(where: { $0.id == record.id }) {
            let targetIndex = min(existingIndex, updatedRecords.count)
            updatedRecords.insert(record, at: targetIndex)
        } else {
            updatedRecords.insert(record, at: 0)
        }

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
