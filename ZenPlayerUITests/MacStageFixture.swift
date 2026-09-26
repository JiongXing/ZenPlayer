import Foundation
import AppKit

/// 仅由验证脚本复制到临时 App；不编入生产 target。
@MainActor
enum MacStageFixture {
    private static var windowObserver: NSObjectProtocol?

    static func seedIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        let shouldSeed = arguments.contains("--stage-seed")
        let shouldVerifyDeletion = arguments.contains("--stage-verify-deleted")
        let queueMode = arguments.contains("--stage-seed-queue") || arguments.contains("--stage-verify-queue")
            || arguments.contains("--stage-verify-queue-off")
        let catalogMode = arguments.contains("--stage-seed-catalog") || arguments.contains("--stage-verify-catalog")
        guard shouldSeed || shouldVerifyDeletion || queueMode || catalogMode else { return }
        let bundle = "com.jxing.ZenPlayer.MacStageValidation"
        precondition(Bundle.main.bundleIdentifier == bundle)
        precondition(NSHomeDirectory().contains("/Library/Containers/\(bundle)/Data"))
        if arguments.contains("--stage-primary-window") {
            // 只调整验证 App 的首个窗口；负坐标外接屏会令本机 XCTest 输入失效。
            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main
            ) { notification in
                MainActor.assumeIsolated {
                    guard let window = notification.object as? NSWindow,
                          let screen = NSScreen.screens.first else { return }
                    if let observer = windowObserver {
                        NotificationCenter.default.removeObserver(observer)
                        windowObserver = nil
                    }
                    let visible = screen.visibleFrame
                    let size = NSSize(width: min(window.frame.width, visible.width),
                                      height: min(window.frame.height, visible.height))
                    window.setFrame(NSRect(x: visible.minX, y: visible.maxY - size.height,
                                           width: size.width, height: size.height), display: true)
                    if arguments.contains("--stage-native-input-probe") {
                        MacNativeInputProbe.present(relativeTo: window)
                    }
                }
            }
        }
        do {
            if catalogMode {
                try MacCatalogFixture.run(arguments: arguments)
                return
            }
            if queueMode {
                try MacQueueFixture.run(arguments: arguments)
                return
            }
            let support = URL.applicationSupportDirectory
            let directory = support.appendingPathComponent("StageValidation")
            let media = directory.appendingPathComponent("silent.wav")
            let key = "900002|https://mac-stage-validation.invalid/"
            let records = support.appendingPathComponent("PlaybackProgress/v1/records")
            let name = FileProgressPersistence.digest(Data(key.utf8)) + ".json"
            if shouldVerifyDeletion {
                precondition(!FileManager.default.fileExists(atPath: media.path), "删除下载后样本文件仍存在")
                let data = try Data(contentsOf: records.appendingPathComponent(name))
                let saved = try JSONDecoder().decode(PlaybackProgress.self, from: data)
                precondition(saved.positionSeconds >= 30, "删除下载后进度丢失")
                return
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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

            let remoteURL = "https://mac-stage-validation.invalid/silent.wav"
            let context: [String: Any] = [
                "episode": ["id": 900002, "num": "MAC-UI-001", "title": "Mac 靜音生命週期驗證", "episode": "1",
                            "mp4Url": "", "vodUrl": "", "mp3Url": remoteURL,
                            "coverUrl": "", "textUrl": "", "filesize": wav.count, "duration": 180_000],
                "serverUrl": "https://mac-stage-validation.invalid/", "preferredMediaType": "audio"
            ]
            let now = Date().timeIntervalSinceReferenceDate
            let record: [String: Any] = [
                "schemaVersion": 1, "legacyKey": key, "context": context, "positionSeconds": 30,
                "durationSeconds": 180, "state": "inProgress", "lastListenedAt": now,
                "updatedAt": now, "revision": 1, "origin": "mac-ui-validation"
            ]
            try FileManager.default.createDirectory(at: records, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: record).write(to: records.appendingPathComponent(name), options: .atomic)

            let downloads = URL.documentsDirectory.appendingPathComponent("ZenPlayerDownloads")
            try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
            let manifestURL = downloads.appendingPathComponent("download_manifest.json")
            var manifest: [String: Any] = ["version": 2, "records": [String: Any]()]
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
                precondition(manifest["version"] as? Int == 2)
            }
            var downloadsByKey = manifest["records"] as! [String: Any]
            downloadsByKey["900002_mp3"] = [
                "episodeId": 900002, "type": "mp3", "remoteURL": remoteURL,
                "destinationRelativePath": media.path, "playbackContext": context,
                "status": "completed", "progress": 1,
                "completedAt": Date().timeIntervalSince1970, "updatedAt": Date().timeIntervalSince1970
            ]
            manifest["records"] = downloadsByKey
            try JSONSerialization.data(withJSONObject: manifest).write(to: manifestURL, options: .atomic)
        } catch {
            preconditionFailure("隔离 Mac 样本准备失败：\(error)")
        }
    }
}
