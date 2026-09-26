import Foundation

nonisolated struct CatalogSearchIndex {
    struct Entry {
        let id: Int
        let fields: [String]
        let episodeNumber: Int?

        init(id: Int, fields: [String], episode: String? = nil) {
            self.id = id
            self.fields = fields.map(SearchNormalization.normalize)
            episodeNumber = episode.flatMap(EpisodeNumberParser.digits)
        }
    }

    private let entries: [Entry]

    init(entries: [Entry] = []) { self.entries = entries }

    init(episodes: [EpisodeItem]) {
        entries = episodes.map { Entry(id: $0.id, fields: [$0.title, $0.num, $0.episode], episode: $0.episode) }
    }

    init(series: [SeriesItem]) {
        entries = series.map { Entry(id: $0.id, fields: [$0.title, $0.num]) }
    }

    func matchingIDs(query: String) -> [Int] {
        let normalized = SearchNormalization.normalize(query)
        let tokens = normalized.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return entries.map(\.id) }
        let number = EpisodeNumberParser.digits(normalized)
        var exact: [Int] = [], remainder: [Int] = []
        for entry in entries {
            if let number, entry.episodeNumber == number {
                exact.append(entry.id)
            } else if tokens.allSatisfy({ token in entry.fields.contains(where: { $0.contains(token) }) }) {
                remainder.append(entry.id)
            }
        }
        return exact + remainder
    }
}
