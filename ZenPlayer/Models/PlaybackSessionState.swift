import Foundation

/// 播放选择与用户意图独立于 AVPlayer；页面生命周期不改变该状态。
nonisolated struct PlaybackSessionState {
    enum Phase { case idle, preparing, playing, buffering, paused, ended, failed }
    private(set) var context: PlaybackContext?
    private(set) var phase: Phase = .idle
    private(set) var request = UUID()
    private(set) var wantsPlayback = false
    private var resumeAfterInterruption = false
    private(set) var interruptionActive = false
    private(set) var retryWantsPlayback = true
    private var lastProgressAt: Double = 0
    private var preparationStartedAt: Double = 0

    var hasSession: Bool { context != nil }
    var isActive: Bool { [.preparing, .playing, .buffering, .paused].contains(phase) }

    @discardableResult
    mutating func select(_ context: PlaybackContext, now: Double, force: Bool = false, wantsPlayback: Bool = true) -> Bool {
        if !force, let current = self.context,
           RecentPlaybackRecord.recordID(for: current) == RecentPlaybackRecord.recordID(for: context) { return false }
        self.context = context
        request = UUID()
        self.wantsPlayback = wantsPlayback
        retryWantsPlayback = wantsPlayback
        phase = .preparing
        preparationStartedAt = now
        lastProgressAt = now
        resumeAfterInterruption = false
        interruptionActive = false
        return true
    }

    mutating func ready(request: UUID, now: Double) {
        guard self.request == request, phase == .preparing else { return }
        phase = wantsPlayback ? .buffering : .paused
        lastProgressAt = now
    }

    mutating func play(now: Double) {
        guard hasSession, phase != .failed, phase != .ended else { return }
        if interruptionActive { return }
        wantsPlayback = true
        if phase != .preparing { phase = .buffering }
        preparationStartedAt = now
        lastProgressAt = now
    }

    mutating func pause() {
        guard hasSession else { return }
        wantsPlayback = false
        resumeAfterInterruption = false
        if phase != .preparing && phase != .ended && phase != .failed { phase = .paused }
    }

    /// AVPlayer 在系统中断期间产生的暂停不是用户的新指令。
    mutating func observedPause() {
        guard !interruptionActive else { return }
        pause()
    }

    mutating func observedPlaying(request: UUID, now: Double) {
        guard self.request == request, wantsPlayback, phase != .preparing, phase != .failed, phase != .ended else { return }
        phase = .playing
        lastProgressAt = now
    }

    /// 原生控件可能先进入 waiting；同步意图后才计缓冲超时。
    mutating func observedWaiting(request: UUID, now: Double) {
        guard self.request == request, isActive, !interruptionActive else { return }
        if !wantsPlayback { play(now: now) }
        buffering(request: request, now: now)
    }

    mutating func buffering(request: UUID, now: Double) {
        guard self.request == request, wantsPlayback, phase != .preparing, phase != .failed, phase != .ended else { return }
        if phase != .buffering {
            lastProgressAt = now
            preparationStartedAt = now
        }
        phase = .buffering
    }

    mutating func advanced(request: UUID, now: Double) {
        guard self.request == request, wantsPlayback, phase != .failed, phase != .ended else { return }
        lastProgressAt = now
    }

    mutating func fail(request: UUID) {
        guard self.request == request, hasSession else { return }
        retryWantsPlayback = wantsPlayback
        phase = .failed
        wantsPlayback = false
        resumeAfterInterruption = false
    }

    mutating func ended(request: UUID) {
        guard self.request == request, phase != .failed, phase != .idle else { return }
        phase = .ended
        wantsPlayback = false
        resumeAfterInterruption = false
    }

    mutating func interruptionBegan() {
        guard !interruptionActive else { return }
        resumeAfterInterruption = phase == .playing && wantsPlayback
        interruptionActive = true
        wantsPlayback = false
        if phase != .preparing && phase != .failed && phase != .ended { phase = .paused }
    }

    mutating func interruptionEnded(systemAllows: Bool, now: Double) -> Bool {
        let resume = interruptionActive && resumeAfterInterruption && systemAllows
        interruptionActive = false
        resumeAfterInterruption = false
        if resume { play(now: now) }
        return resume
    }

    func loadingVisible(now: Double) -> Bool {
        wantsPlayback && (phase == .preparing || phase == .buffering) && now - preparationStartedAt >= 0.3
    }

    func timedOut(now: Double) -> Bool {
        wantsPlayback && [.preparing, .buffering].contains(phase) && now - lastProgressAt >= 30
    }

    mutating func stop() { self = PlaybackSessionState() }
}
