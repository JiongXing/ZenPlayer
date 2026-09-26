import Foundation

/// 仅在已知离线时限制到本地媒体，未知网络仍沿用正常远端尝试。
nonisolated enum QueueMediaPolicy {
    static func select(preferred: PlaybackMediaType?, supported: [PlaybackMediaType],
                       local: [PlaybackMediaType], offline: Bool) -> PlaybackMediaType? {
        let candidates = offline ? supported.filter { local.contains($0) } : supported
        if let preferred, candidates.contains(preferred) { return preferred }
        if candidates.contains(.audio) { return .audio }
        return candidates.first
    }
}
