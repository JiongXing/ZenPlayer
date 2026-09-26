import Foundation

/// 播放上下文：单集 + 服务器地址，用于导航传递
nonisolated struct PlaybackContext: Codable, Identifiable, Hashable {
    let episode: EpisodeItem
    let serverUrl: String
    let preferredMediaType: PlaybackMediaType?

    init(
        episode: EpisodeItem,
        serverUrl: String,
        preferredMediaType: PlaybackMediaType? = nil
    ) {
        self.episode = episode
        self.serverUrl = serverUrl
        self.preferredMediaType = preferredMediaType
    }

    var id: Int { episode.id }

    private enum CodingKeys: String, CodingKey {
        case episode
        case serverUrl
        case preferredMediaType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episode = try container.decode(EpisodeItem.self, forKey: .episode)
        serverUrl = try container.decode(String.self, forKey: .serverUrl)
        preferredMediaType = try container.decodeIfPresent(PlaybackMediaType.self, forKey: .preferredMediaType)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(episode, forKey: .episode)
        try container.encode(serverUrl, forKey: .serverUrl)
        try container.encodeIfPresent(preferredMediaType, forKey: .preferredMediaType)
    }
}
