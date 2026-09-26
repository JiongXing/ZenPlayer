import XCTest
import AVFoundation

/// 验证平台的实际 AVPlayer 信号；不代表 AVKit 原生控件操作或后台验收。
final class AVPlayerProgressSignalTests: XCTestCase {
    @MainActor
    func testLocalPlayerSeekJumpPauseAndNaturalEndSignals() async throws {
        let env = try ProgressTestEnvironment()
        let url = env.directory.appendingPathComponent("silence.wav")
        try makeWave().write(to: url)
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        let ready = expectation(description: "item ready")
        let status = item.observe(\.status, options: [.initial, .new]) { item, _ in
            if item.status == .readyToPlay { ready.fulfill() }
        }
        await fulfillment(of: [ready], timeout: 10)
        withExtendedLifetime(status) {}
        XCTAssertEqual(item.status, .readyToPlay)
        let jump = expectation(description: "time jumped")
        let jumpObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemTimeJumped, object: item, queue: .main) { _ in jump.fulfill() }
        let success = await player.seek(to: CMTime(seconds: 1, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        XCTAssertTrue(success)
        await fulfillment(of: [jump], timeout: 3)
        NotificationCenter.default.removeObserver(jumpObserver)
        XCTAssertEqual(player.currentTime().seconds, 1, accuracy: 0.05)
        XCTAssertEqual(player.rate, 0)
        let pause = expectation(description: "pause rate change")
        let rate = player.observe(\.rate, options: [.old, .new]) { _, change in
            if change.oldValue != 0, change.newValue == 0 { pause.fulfill() }
        }
        player.play()
        player.pause()
        await fulfillment(of: [pause], timeout: 3)
        withExtendedLifetime(rate) {}
        rate.invalidate()
        let ended = expectation(description: "natural end")
        let endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in ended.fulfill() }
        defer { NotificationCenter.default.removeObserver(endObserver); player.pause() }
        _ = await player.seek(to: CMTime(seconds: 3.8, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
        await fulfillment(of: [ended], timeout: 5)
    }

    nonisolated private func makeWave() -> Data {
        let sampleCount: UInt32 = 8_000 * 4
        var data = Data()
        func text(_ string: String) { data.append(contentsOf: string.utf8) }
        func word<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        text("RIFF"); word(UInt32(36) + sampleCount * 2); text("WAVEfmt ")
        word(UInt32(16)); word(UInt16(1)); word(UInt16(1)); word(UInt32(8_000))
        word(UInt32(16_000)); word(UInt16(2)); word(UInt16(16)); text("data"); word(sampleCount * 2)
        data.append(Data(count: Int(sampleCount * 2)))
        return data
    }
}
