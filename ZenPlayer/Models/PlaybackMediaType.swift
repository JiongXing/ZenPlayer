import Foundation

nonisolated enum PlaybackMediaType: String, CaseIterable, Identifiable, Codable, Hashable {
    case audio
    case video

    var id: String { rawValue }

    var isVideo: Bool {
        self == .video
    }
}
