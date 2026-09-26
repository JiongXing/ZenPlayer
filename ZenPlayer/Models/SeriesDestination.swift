import Foundation

/// 从历史的轻量关联回到系列；不要求填充并不存在的远端完整元数据。
nonisolated struct SeriesDestination: Hashable {
    let id: Int
    let title: String
    let url: String
    var targetEpisodeID: Int?

    init(id: Int, title: String, url: String, targetEpisodeID: Int? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.targetEpisodeID = targetEpisodeID
    }

    init(reference: PlaybackSeriesReference, targetEpisodeID: Int) {
        self.init(id: reference.seriesID, title: reference.title, url: reference.detailURL, targetEpisodeID: targetEpisodeID)
    }
}
