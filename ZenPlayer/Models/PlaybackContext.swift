import Foundation

/// 播放上下文：单集 + 服务器地址，用于导航传递
nonisolated struct PlaybackContext: Codable, Identifiable, Hashable {
    let episode: EpisodeItem
    let serverUrl: String
    let preferredMediaType: PlaybackMediaType?
    let series: PlaybackSeriesReference?

    init(
        episode: EpisodeItem,
        serverUrl: String,
        preferredMediaType: PlaybackMediaType? = nil,
        series: PlaybackSeriesReference? = nil
    ) {
        self.episode = episode
        self.serverUrl = serverUrl
        self.preferredMediaType = preferredMediaType
        self.series = series
    }

    var id: Int { episode.id }

    private enum CodingKeys: String, CodingKey {
        case episode
        case serverUrl
        case preferredMediaType
        case series
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episode = try container.decode(EpisodeItem.self, forKey: .episode)
        serverUrl = try container.decode(String.self, forKey: .serverUrl)
        preferredMediaType = try container.decodeIfPresent(PlaybackMediaType.self, forKey: .preferredMediaType)
        // 队列关联是可选附加信息，损坏不能使有效的旧进度整条解码失败。
        series = try? container.decodeIfPresent(PlaybackSeriesReference.self, forKey: .series)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(episode, forKey: .episode)
        try container.encode(serverUrl, forKey: .serverUrl)
        try container.encodeIfPresent(preferredMediaType, forKey: .preferredMediaType)
        try container.encodeIfPresent(series, forKey: .series)
    }
}
