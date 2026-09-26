import Foundation

/// 轻量引用随进度保存；完整列表独立持久化，索引仅为提示，身份以原键核实。
nonisolated struct PlaybackSeriesReference: Codable, Hashable {
    let seriesID: Int
    let title: String
    let detailURL: String
    let snapshotID: String
    let index: Int
}
