import Foundation

nonisolated enum EpisodeNumberParser {
    static func digits(_ input: String) -> Int? {
        let text = input.folding(options: .widthInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        return Int(text)
    }

    static func parse(_ input: String) -> Int? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("第"), text.hasSuffix("集") {
            return digits(String(text.dropFirst().dropLast()))
        }
        return digits(text)
    }

    static func matches(_ number: Int, episodes: [EpisodeItem]) -> [EpisodeItem] {
        episodes.filter { digits($0.episode) == number }
    }
}
