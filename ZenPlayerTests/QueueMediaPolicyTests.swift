import XCTest

final class QueueMediaPolicyTests: XCTestCase {
    func testKeepsPreferredAndFallsBackToOnlySupportedType() {
        XCTAssertEqual(QueueMediaPolicy.select(preferred: .video, supported: [.audio, .video], local: [], offline: false), .video)
        XCTAssertEqual(QueueMediaPolicy.select(preferred: .video, supported: [.audio], local: [], offline: false), .audio)
        XCTAssertNil(QueueMediaPolicy.select(preferred: .video, supported: [], local: [], offline: false))
    }

    func testOfflineUsesDownloadedAlternateOrFailsWithoutSkipping() {
        XCTAssertEqual(QueueMediaPolicy.select(preferred: .video, supported: [.audio, .video], local: [.audio], offline: true), .audio)
        XCTAssertEqual(QueueMediaPolicy.select(preferred: .video, supported: [.audio, .video], local: [.audio, .video], offline: true), .video)
        XCTAssertNil(QueueMediaPolicy.select(preferred: .audio, supported: [.audio, .video], local: [], offline: true))
        XCTAssertEqual(QueueMediaPolicy.select(preferred: nil, supported: [.video], local: [.video], offline: true), .video)
    }
}
