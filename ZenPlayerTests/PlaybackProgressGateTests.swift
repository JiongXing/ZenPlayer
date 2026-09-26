import XCTest

final class PlaybackProgressGateTests: XCTestCase {
    @MainActor
    func testPrepareAndFailedSeekCannotWriteZeroOrAcceptOldCallbacks() async throws {
        var gate = PlaybackProgressGate()
        let a = gate.begin(position: 120)
        XCTAssertNil(gate.action(token: a, position: 0))
        gate.restored(token: a, success: false, position: 0)
        XCTAssertNil(gate.action(token: a, position: 0))
        let b = gate.begin(position: 50)
        gate.restored(token: a, success: true, position: 120)
        XCTAssertNil(gate.action(token: b, position: 0))
        gate.restored(token: b, success: true, position: 50)
        XCTAssertEqual(gate.action(token: b, position: 53), 53)
        XCTAssertNil(gate.action(token: a, position: 120))
        gate.invalidate()
        XCTAssertNil(gate.action(token: b, position: 0))
    }

    @MainActor
    func testClockScheduleActionsAndSeekAreNotListening() async throws {
        var gate = PlaybackProgressGate()
        let clock = TestClock()
        let token = gate.begin(position: 100, uptime: clock.uptime)
        gate.restored(token: token, success: true, position: 100)
        for second in 1...10 {
            clock.advance(1)
            XCTAssertTrue(gate.tick(token: token, position: 100 + Double(second), playing: true, uptime: clock.uptime))
            if second.isMultiple(of: 4) {
                XCTAssertTrue(gate.shouldFlush(uptime: clock.uptime))
                gate.didRequestFlush(uptime: clock.uptime)
            }
        }
        gate.jumped(token: token, position: 290)
        XCTAssertFalse(gate.tick(token: token, position: 290, playing: false, uptime: clock.uptime))
        XCTAssertEqual(gate.action(token: token, position: 0, explicitSeek: true), 0)
        XCTAssertEqual(gate.action(token: token, position: 103), 103)
    }
}

extension PlaybackProgressGateTests {
    @MainActor
    func testLatePauseAfterNaturalEndCannotTurnCompletedIntoReplay() async throws {
        var gate = PlaybackProgressGate()
        let token = gate.begin(position: 298)
        gate.restored(token: token, success: true, position: 298)
        XCTAssertTrue(gate.tick(token: token, position: 299, playing: true, uptime: 1))
        gate.ended(token: token)
        XCTAssertFalse(gate.tick(token: token, position: 300, playing: true, uptime: 2))
        gate.jumped(token: token, position: 0)
        XCTAssertFalse(gate.tick(token: token, position: 0, playing: false, uptime: 3))
        gate.playbackStarted(token: token)
        XCTAssertTrue(gate.tick(token: token, position: 1, playing: true, uptime: 4))
    }
}

extension PlaybackProgressGateTests {
    @MainActor
    func testPausedTickDoesNotConsumeSubsecondListeningBeforePauseCallback() async throws {
        var gate = PlaybackProgressGate()
        let token = gate.begin(position: 0)
        gate.restored(token: token, success: true, position: 0)
        XCTAssertFalse(gate.tick(token: token, position: 0.3, playing: false, uptime: 0.3))
        // 暂停 KVO 携带前一 rate > 0 的事实，仍能提交第一次 tick 前的实际收听。
        XCTAssertTrue(gate.tick(token: token, position: 0.3, playing: true, uptime: 0.3))
        XCTAssertEqual(gate.action(token: token, position: 0.3), 0.3)
    }
}
