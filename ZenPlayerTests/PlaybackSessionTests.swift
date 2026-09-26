import XCTest

final class PlaybackSessionTests: XCTestCase {
    func testSameSelectionPreservesPausedSessionAndLatestRequestWins() {
        var session = PlaybackSessionState()
        let a = testContext()
        XCTAssertTrue(session.select(a, now: 0))
        let request = session.request
        session.ready(request: request, now: 1)
        session.pause()
        XCTAssertFalse(session.select(a, now: 2))
        XCTAssertEqual(session.request, request)
        XCTAssertFalse(session.wantsPlayback)
        XCTAssertTrue(session.select(testContext(id: 2), now: 3))
        let b = session.request
        XCTAssertTrue(session.select(testContext(id: 3), now: 4))
        session.ready(request: b, now: 5)
        session.fail(request: b)
        XCTAssertEqual(session.context?.episode.id, 3)
        XCTAssertEqual(session.phase, .preparing)
        session.fail(request: session.request)
        XCTAssertEqual(session.context?.episode.id, 3)
        XCTAssertEqual(session.phase, .failed)
    }

    func testInterruptionOnlyResumesEligiblePlayback() {
        var session = PlaybackSessionState()
        session.select(testContext(), now: 0)
        session.ready(request: session.request, now: 1)
        session.observedPlaying(request: session.request, now: 1)
        session.interruptionBegan()
        XCTAssertTrue(session.interruptionEnded(systemAllows: true, now: 2))
        session.observedPlaying(request: session.request, now: 2)
        session.interruptionBegan()
        session.pause()
        XCTAssertFalse(session.interruptionEnded(systemAllows: true, now: 3))
        XCTAssertFalse(session.wantsPlayback)
        session.interruptionBegan()
        XCTAssertFalse(session.interruptionEnded(systemAllows: true, now: 4))
    }

    func testTimeoutExcludesPauseAndProgressResetsDeadline() {
        var session = PlaybackSessionState()
        session.select(testContext(), now: 0)
        XCTAssertFalse(session.loadingVisible(now: 0.299))
        XCTAssertTrue(session.loadingVisible(now: 0.3))
        XCTAssertFalse(session.timedOut(now: 29.99))
        XCTAssertTrue(session.timedOut(now: 30))
        session.pause()
        XCTAssertFalse(session.timedOut(now: 100))
        session.play(now: 100)
        session.ready(request: session.request, now: 101)
        session.advanced(request: session.request, now: 120)
        XCTAssertFalse(session.timedOut(now: 149))
        XCTAssertTrue(session.timedOut(now: 150))
    }

    func testStopAndEndNeverRestartOrEraseTargetUnexpectedly() {
        var session = PlaybackSessionState()
        XCTAssertFalse(session.hasSession)
        session.select(testContext(), now: 0)
        session.ended(request: session.request)
        XCTAssertEqual(session.phase, .ended)
        XCTAssertFalse(session.wantsPlayback)
        session.observedPlaying(request: session.request, now: 2)
        XCTAssertEqual(session.phase, .ended)
        session.stop()
        XCTAssertNil(session.context)
        XCTAssertFalse(session.wantsPlayback)
        XCTAssertEqual(session.phase, .idle)
    }
    func testSystemPauseObservationKeepsInterruptionEligibilityButUserPauseRevokesIt() {
        var session = PlaybackSessionState()
        session.select(testContext(), now: 0)
        session.ready(request: session.request, now: 1)
        session.observedPlaying(request: session.request, now: 1)
        session.interruptionBegan()
        session.observedPause()
        session.interruptionBegan() // 重复通知不能丢失恢复资格。
        XCTAssertTrue(session.interruptionEnded(systemAllows: true, now: 2))
        session.observedPlaying(request: session.request, now: 2)
        session.interruptionBegan()
        session.observedPause()
        session.pause()
        XCTAssertFalse(session.interruptionEnded(systemAllows: true, now: 3))
    }

    func testNoSystemPermissionOrNewSelectionNeverResumesInterruptedItem() {
        var session = PlaybackSessionState()
        session.select(testContext(), now: 0)
        session.ready(request: session.request, now: 1)
        session.observedPlaying(request: session.request, now: 1)
        session.interruptionBegan()
        XCTAssertFalse(session.interruptionEnded(systemAllows: false, now: 2))
        session.select(testContext(id: 2), now: 3)
        session.pause()
        XCTAssertFalse(session.interruptionEnded(systemAllows: true, now: 4))
        XCTAssertFalse(session.wantsPlayback)
    }

    func testPausedSwitchFailureRetryPreservesPositionIntent() {
        var session = PlaybackSessionState()
        let context = testContext()
        session.select(context, now: 0, wantsPlayback: false)
        session.ready(request: session.request, now: 1)
        XCTAssertEqual(session.phase, .paused)
        session.fail(request: session.request)
        XCTAssertFalse(session.retryWantsPlayback)
        session.select(context, now: 2, force: true, wantsPlayback: session.retryWantsPlayback)
        session.ready(request: session.request, now: 3)
        XCTAssertEqual(session.phase, .paused)
        XCTAssertFalse(session.wantsPlayback)
        session.play(now: 4)
        XCTAssertTrue(session.wantsPlayback)
    }

    func testEachBufferingEpisodeHasLoadingDelayAndTimeoutBudget() {
        var session = PlaybackSessionState()
        session.select(testContext(), now: 0)
        session.ready(request: session.request, now: 1)
        session.observedPlaying(request: session.request, now: 1)
        session.buffering(request: session.request, now: 100)
        XCTAssertFalse(session.loadingVisible(now: 100.2))
        XCTAssertTrue(session.loadingVisible(now: 100.4))
        session.buffering(request: session.request, now: 120)
        XCTAssertTrue(session.timedOut(now: 130)) // 重复 waiting 不能无期限重置。
        session.pause()
        XCTAssertFalse(session.loadingVisible(now: 200))
        XCTAssertFalse(session.timedOut(now: 200))
        session.play(now: 200)
        XCTAssertFalse(session.timedOut(now: 229))
    }

    func testStopInvalidatesAllDelayedMediaEvents() {
        var session = PlaybackSessionState()
        session.select(testContext(), now: 0)
        let old = session.request
        session.stop()
        session.ready(request: old, now: 1)
        session.observedPlaying(request: old, now: 1)
        session.buffering(request: old, now: 2)
        session.advanced(request: old, now: 3)
        session.ended(request: old)
        session.fail(request: old)
        session.play(now: 4)
        XCTAssertEqual(session.phase, .idle)
        XCTAssertFalse(session.hasSession)
        XCTAssertFalse(session.wantsPlayback)
    }

    func testNativePlayWaitingUpdatesPausedIntentAndTimesOut() {
        var session = PlaybackSessionState()
        session.select(testContext(), now: 0)
        session.ready(request: session.request, now: 1)
        session.pause()
        session.observedWaiting(request: session.request, now: 100)
        XCTAssertTrue(session.wantsPlayback)
        XCTAssertEqual(session.phase, .buffering)
        XCTAssertTrue(session.timedOut(now: 130))
        session.observedPlaying(request: session.request, now: 131)
        session.interruptionBegan()
        session.observedWaiting(request: session.request, now: 132)
        XCTAssertFalse(session.wantsPlayback)
        XCTAssertEqual(session.phase, .paused)
        session.stop()
        session.observedWaiting(request: session.request, now: 133)
        XCTAssertEqual(session.phase, .idle)
    }

}
