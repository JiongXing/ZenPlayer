import Foundation

/// 只管理当前页面媒体请求的进度许可，不拥有全局播放会话。
nonisolated struct PlaybackProgressGate {
    private(set) var token = UUID()
    private(set) var ready = false
    private var lastPosition: Double?
    private var lastUptime: Double?
    private var lastFlushRequest: Double = 0
    private var hasAdvanced = false
    private var finished = false
    private var restoredPosition: Double = 0

    mutating func begin(position: Double, uptime: Double = 0) -> UUID {
        token = UUID(); ready = false; hasAdvanced = false; finished = false
        restoredPosition = position; lastPosition = nil; lastUptime = nil
        lastFlushRequest = uptime
        return token
    }

    mutating func invalidate() { token = UUID(); ready = false }

    mutating func restored(token: UUID, success: Bool, position: Double) {
        guard token == self.token else { return }
        ready = success && position.isFinite && position >= 0
        if ready { lastPosition = position; restoredPosition = position }
    }

    mutating func ended(token: UUID) {
        guard token == self.token, ready else { return }
        finished = true
    }

    mutating func playbackStarted(token: UUID) {
        guard token == self.token, ready else { return }
        finished = false
    }

    mutating func jumped(token: UUID, position: Double) {
        guard token == self.token, position.isFinite, position >= 0 else { return }
        lastPosition = position
        lastUptime = nil
    }

    mutating func tick(token: UUID, position: Double, playing: Bool, uptime: Double) -> Bool {
        guard token == self.token, ready, !finished, playing, position.isFinite, position >= 0 else { return false }
        defer { lastPosition = position; lastUptime = uptime }
        let delta = position - (lastPosition ?? position)
        let elapsed = lastUptime.map { max(0, uptime - $0) } ?? 1
        // 跳变由 timeJumped 单独处理；异常大步进不能冒充实际收听。
        let advanced = playing && delta > 0 && delta <= elapsed * 2 + 0.5
        if advanced { hasAdvanced = true }
        return advanced
    }

    func action(token: UUID, position: Double, explicitSeek: Bool = false) -> Double? {
        guard token == self.token, ready, position.isFinite, position >= 0,
              hasAdvanced || restoredPosition > 0 || explicitSeek else { return nil }
        return position
    }

    func shouldFlush(uptime: Double) -> Bool { uptime - lastFlushRequest >= 4 }
    mutating func didRequestFlush(uptime: Double) { lastFlushRequest = uptime }
}
