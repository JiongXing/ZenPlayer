import Foundation

/// 同一条目可被再次定位；用请求身份隔离两秒高亮结束的迟到回调。
nonisolated struct EpisodeLocation: Identifiable {
    let id = UUID()
    let episodeID: Int
}
