import Foundation

nonisolated struct QueueSnapshot: Codable, Hashable, Identifiable {
    var schemaVersion = 1
    let id: String
    let seriesID: Int
    let title: String
    let detailURL: String
    let serverURL: String
    let episodes: [EpisodeItem]
    let isComplete: Bool
    let createdAt: Date

    init(seriesID: Int, title: String, detailURL: String, serverURL: String,
         episodes: [EpisodeItem], isComplete: Bool, createdAt: Date = Date()) {
        id = UUID().uuidString
        self.seriesID = seriesID
        self.title = title
        self.detailURL = detailURL
        self.serverURL = serverURL
        self.episodes = episodes
        self.isComplete = isComplete
        self.createdAt = createdAt
    }

    var isValid: Bool {
        schemaVersion == 1 && UUID(uuidString: id) != nil && !serverURL.isEmpty && !detailURL.isEmpty
            && !episodes.isEmpty && Set(episodes.map(\.id)).count == episodes.count
            && createdAt.timeIntervalSinceReferenceDate.isFinite
    }

    func index(of context: PlaybackContext) -> Int? {
        guard isValid, serverURL == context.serverUrl else { return nil }
        return episodes.firstIndex { $0.id == context.episode.id }
    }

    func context(at index: Int, preferred: PlaybackMediaType? = nil) -> PlaybackContext? {
        guard isValid, episodes.indices.contains(index) else { return nil }
        return PlaybackContext(episode: episodes[index], serverUrl: serverURL, preferredMediaType: preferred,
                               series: PlaybackSeriesReference(seriesID: seriesID, title: title, detailURL: detailURL,
                                                               snapshotID: id, index: index))
    }
}
