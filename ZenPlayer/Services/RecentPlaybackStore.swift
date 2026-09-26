import Foundation
import Observation

/// 旧页面接口的薄适配；唯一权威数据源是长期进度仓库。
@MainActor
@Observable
final class RecentPlaybackStore {
    static let shared = RecentPlaybackStore(progressStore: .shared)
    let progressStore: PlaybackProgressStore
    var records: [RecentPlaybackRecord] { progressStore.recentRecords.map(RecentPlaybackRecord.init(progress:)) }

    init(progressStore: PlaybackProgressStore) { self.progressStore = progressStore }

    func record(for context: PlaybackContext) -> RecentPlaybackRecord? {
        progressStore.record(for: context).map(RecentPlaybackRecord.init(progress:))
    }

    // 准备成功并非实际收听；保留调用兼容性，后续由有效推进更新最近。
    func recordPlayback(_ context: PlaybackContext) {}

    func updateProgress(for context: PlaybackContext, resumePositionSeconds: Double) {
        progressStore.update(context, position: resumePositionSeconds, duration: nil, event: .position)
        progressStore.requestFlush()
    }

    func markPlaybackCompleted(for context: PlaybackContext) {
        let position = progressStore.record(for: context)?.positionSeconds ?? 0
        progressStore.update(context, position: position, duration: nil, event: .ended)
        progressStore.requestFlush()
    }
}
