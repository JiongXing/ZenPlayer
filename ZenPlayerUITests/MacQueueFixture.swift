import Foundation

/// 仅复制到独立 Mac 验证 App，播种磁盘输入；不替换队列、AVPlayer 或界面实现。
@MainActor
enum MacQueueFixture {
    private static let server = "https://mac-queue-validation.invalid/"
    private static let snapshotID = "70C79620-F65D-4FC7-A41A-B76FC0B14125"
    private static let episodeIDs = [900101, 900102, 900105]

    static func run(arguments: [String]) throws {
        let bundle = "com.jxing.ZenPlayer.MacStageValidation"
        precondition(Bundle.main.bundleIdentifier == bundle)
        precondition(NSHomeDirectory().contains("/Library/Containers/\(bundle)/Data"))
        let support = URL.applicationSupportDirectory
        let records = support.appendingPathComponent("PlaybackProgress/v1/records")
        let snapshots = support.appendingPathComponent("PlaybackQueue/v1")
        let snapshotURL = snapshots.appendingPathComponent(snapshotID + ".json")
        let verifyOff = arguments.contains("--stage-verify-queue-off")
        if arguments.contains("--stage-verify-queue") || verifyOff {
            let saved = try episodeIDs.map { id in
                try JSONDecoder().decode(PlaybackProgress.self, from: Data(contentsOf: recordURL(id, in: records)))
            }
            precondition(saved[0].state == .completed, "首集自然结束状态丢失")
            precondition(saved[1].state == .inProgress && saved[1].positionSeconds >= 7, "切集覆盖第二集旧进度")
            precondition(saved[2].state == (verifyOff ? .notStarted : .completed), "末集状态与实际播放路径不符")
            let snapshot = try JSONDecoder().decode(QueueSnapshot.self, from: Data(contentsOf: snapshotURL))
            precondition(snapshot.isValid && snapshot.episodes.map(\.episode) == ["1", "2", "5"])
            precondition(saved.allSatisfy { $0.context.series?.snapshotID == snapshotID })
            precondition(UserDefaults.standard.object(forKey: "playback.autoAdvance") as? Bool == false,
                         "连播关闭偏好未保留")
            return // 只读验证，不能在冷启动检查时重新播种。
        }
        precondition(arguments.contains("--stage-seed-queue"))
        let mediaDirectory = support.appendingPathComponent("StageValidation/queue")
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        let numbers = [1, 2, 5]
        let durations = [10, 120, 15]
        let episodes = zip(numbers, durations).enumerated().map { index, item in
            EpisodeItem(id: episodeIDs[index], num: "MAC-QUEUE", title: "Mac 連播驗證-\(item.0)",
                        episode: String(item.0), mp4Url: "", vodUrl: "", mp3Url: server + "\(item.0).wav",
                        coverUrl: "", textUrl: "", filesize: item.1 * 16_000 + 44, duration: item.1 * 1_000)
        }
        // 固定且只归此样本所有的版本，避免每次回归积累新快照。
        let snapshotObject: [String: Any] = [
            "schemaVersion": 1, "id": snapshotID, "seriesID": 900100, "title": "Mac 連播驗證系列",
            "detailURL": server + "series", "serverURL": server, "isComplete": true,
            "createdAt": 0, "episodes": try JSONSerialization.jsonObject(with: JSONEncoder().encode(episodes))
        ]
        let snapshot = try JSONDecoder().decode(QueueSnapshot.self, from: JSONSerialization.data(withJSONObject: snapshotObject))
        precondition(snapshot.isValid)
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: snapshotURL, options: .atomic)
        try FileManager.default.createDirectory(at: records, withIntermediateDirectories: true)
        let downloads = URL.documentsDirectory.appendingPathComponent("ZenPlayerDownloads")
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let manifestURL = downloads.appendingPathComponent("download_manifest.json")
        var manifest: [String: Any] = ["version": 2, "records": [String: Any]()]
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
            precondition(manifest["version"] as? Int == 2)
        }
        var downloadsByKey = manifest["records"] as! [String: Any]
        let now = Date()
        for index in episodes.indices {
            let episode = episodes[index]
            let context = snapshot.context(at: index, preferred: .audio)!
            let date = now.addingTimeInterval(index == 0 ? 0 : -100)
            var progress = PlaybackProgress(context: context, now: date)
            if index < 2 {
                progress.update(position: index == 0 ? 1 : 7, mediaDuration: Double(durations[index]),
                                event: .advance, now: date)
            }
            try JSONEncoder().encode(progress).write(to: recordURL(episode.id, in: records), options: .atomic)
            let media = mediaDirectory.appendingPathComponent("\(episode.episode).wav")
            try silence(seconds: durations[index]).write(to: media, options: .atomic)
            downloadsByKey["\(episode.id)_mp3"] = [
                "episodeId": episode.id, "type": "mp3", "remoteURL": episode.mp3Url!,
                "destinationRelativePath": media.path,
                "playbackContext": try JSONSerialization.jsonObject(with: JSONEncoder().encode(context)),
                "status": "completed", "progress": 1, "completedAt": now.timeIntervalSince1970,
                "updatedAt": now.timeIntervalSince1970
            ]
        }
        manifest["records"] = downloadsByKey
        try JSONSerialization.data(withJSONObject: manifest).write(to: manifestURL, options: .atomic)
        // 仅清本验证 App 的单个偏好，让首次播放使用产品默认值 true。
        UserDefaults.standard.removeObject(forKey: "playback.autoAdvance")
        if arguments.contains("--stage-auto-off") {
            UserDefaults.standard.set(false, forKey: "playback.autoAdvance")
        }
    }

    private static func recordURL(_ id: Int, in directory: URL) -> URL {
        directory.appendingPathComponent(FileProgressPersistence.digest(Data("\(id)|\(server)".utf8)) + ".json")
    }

    private static func silence(seconds: Int) -> Data {
        let byteCount = seconds * 16_000
        var data = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ number: T) {
            var value = number.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        append(UInt32(byteCount + 36))
        data.append(Data("WAVEfmt ".utf8))
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(8_000)); append(UInt32(16_000)); append(UInt16(2)); append(UInt16(16))
        data.append(Data("data".utf8)); append(UInt32(byteCount))
        data.append(Data(count: byteCount))
        return data
    }
}
