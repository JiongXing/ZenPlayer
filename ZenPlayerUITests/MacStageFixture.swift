import Foundation

/// 仅由验证脚本复制到临时 App；不编入生产 target。
@MainActor
enum MacStageFixture {
    static func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--stage-seed") else { return }
        let bundle = "com.jxing.ZenPlayer.MacStageValidation"
        precondition(Bundle.main.bundleIdentifier == bundle)
        precondition(NSHomeDirectory().contains("/Library/Containers/\(bundle)/Data"))
        do {
            let support = URL.applicationSupportDirectory
            let directory = support.appendingPathComponent("StageValidation")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let media = directory.appendingPathComponent("silent.wav")
            var wav = Data("RIFF".utf8)
            func append<T: FixedWidthInteger>(_ number: T) {
                var value = number.littleEndian
                withUnsafeBytes(of: &value) { wav.append(contentsOf: $0) }
            }
            append(UInt32(2_880_036))
            wav.append(Data("WAVEfmt ".utf8))
            append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
            append(UInt32(8_000)); append(UInt32(16_000))
            append(UInt16(2)); append(UInt16(16))
            wav.append(Data("data".utf8)); append(UInt32(2_880_000))
            wav.append(Data(count: 2_880_000))
            try wav.write(to: media, options: .atomic)

            let context: [String: Any] = [
                "episode": ["id": 900002, "num": "MAC-UI-001", "title": "Mac 靜音生命週期驗證", "episode": "1",
                            "mp4Url": "", "vodUrl": "", "mp3Url": media.absoluteString,
                            "coverUrl": "", "textUrl": "", "filesize": wav.count, "duration": 180_000],
                "serverUrl": "https://mac-stage-validation.invalid/", "preferredMediaType": "audio"
            ]
            let key = "900002|https://mac-stage-validation.invalid/"
            let now = Date().timeIntervalSinceReferenceDate
            let record: [String: Any] = [
                "schemaVersion": 1, "legacyKey": key, "context": context, "positionSeconds": 30,
                "durationSeconds": 180, "state": "inProgress", "lastListenedAt": now,
                "updatedAt": now, "revision": 1, "origin": "mac-ui-validation"
            ]
            let records = support.appendingPathComponent("PlaybackProgress/v1/records")
            try FileManager.default.createDirectory(at: records, withIntermediateDirectories: true)
            let name = FileProgressPersistence.digest(Data(key.utf8)) + ".json"
            try JSONSerialization.data(withJSONObject: record).write(to: records.appendingPathComponent(name), options: .atomic)
        } catch {
            preconditionFailure("隔离 Mac 样本准备失败：\(error)")
        }
    }
}
