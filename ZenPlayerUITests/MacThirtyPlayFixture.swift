import Foundation

/// AT-16 只准备媒体／目录，进度必须由三十次实际播放产生。
@MainActor
enum MacThirtyPlayFixture {
    static func run(root: URL, arguments: [String]) throws {
        precondition(MacLongHistoryFixture.isThirtyPlays)
        let progressRoot = root.appendingPathComponent("PlaybackProgress/v1")
        let beforeResume = root.appendingPathComponent("thirty-before-resume.json")
        if arguments.contains("--stage-verify-resume") {
            guard let index = arguments.firstIndex(of: "--stage-thirty-first-position"),
                  arguments.indices.contains(index + 1), let expected = Double(arguments[index + 1]),
                  expected.isFinite, expected >= 10, expected < 120 else {
                preconditionFailure("缺少真实 UI 观察的首集位置")
            }
            let loaded = try FileProgressPersistence(root: progressRoot).load()
            precondition(loaded.issues.isEmpty && loaded.records.count == 30)
            precondition(Set(loaded.records.map { $0.context.episode.id }) == Set(911001...911030))
            precondition(loaded.records.allSatisfy { $0.isValid && $0.state == .inProgress && $0.positionSeconds >= 2 && $0.lastListenedAt != nil })
            let first = loaded.records.first { $0.context.episode.id == 911001 }!
            precondition(abs(first.positionSeconds - expected) <= 1, "首集实际暂停位置未保留")
            let recent = PlaybackProgress.recent(loaded.records).map { $0.context.episode.id }
            let resumed = arguments.contains("--stage-thirty-resumed")
            precondition(recent == (resumed ? [911001] + Array((911022...911030).reversed()) : Array((911021...911030).reversed())))
            var bytes: [String: Data] = [:]
            for record in loaded.records {
                let name = FileProgressPersistence.digest(Data(record.id.utf8)) + ".json"
                bytes[name] = try Data(contentsOf: progressRoot.appendingPathComponent("records/" + name))
            }
            if resumed {
                let baseline = try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: beforeResume))
                let firstName = FileProgressPersistence.digest(Data(first.id.utf8)) + ".json"
                for (name, original) in baseline where name != firstName {
                    precondition(bytes[name] == original, "恢复首集不能改写其他二十九条进度")
                }
            } else {
                // 只读进度；另存本次真实播放的验证基线，不向进度仓库播种数据。
                precondition(!FileManager.default.fileExists(atPath: beforeResume.path))
                try JSONEncoder().encode(bytes).write(to: beforeResume, options: .atomic)
            }
            return
        }
        precondition(!FileManager.default.fileExists(atPath: root.path), "拒绝覆盖已有三十集样本")
        let media = root.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        let snapshot = MacLongHistoryFixture.catalogSnapshot
        precondition(snapshot.episodes.count == 30 && snapshot.isValid)
        let snapshots = root.appendingPathComponent("PlaybackQueue/v1")
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: snapshots.appendingPathComponent(snapshot.id + ".json"), options: .atomic)
        let downloads = URL.documentsDirectory.appendingPathComponent("ZenPlayerDownloads")
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let manifestURL = downloads.appendingPathComponent("download_manifest.json")
        var manifest: [String: Any] = ["version": 2, "records": [String: Any]()]
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
            precondition(manifest["version"] as? Int == 2)
        }
        var entries = manifest["records"] as! [String: Any]
        let wav = MacQueueFixture.silence(seconds: 120)
        for index in snapshot.episodes.indices {
            let episode = snapshot.episodes[index]
            let file = media.appendingPathComponent("\(episode.id).wav")
            try wav.write(to: file, options: .atomic)
            entries["\(episode.id)_mp3"] = ["episodeId": episode.id, "type": "mp3", "remoteURL": episode.mp3Url!,
                "destinationRelativePath": file.path, "status": "completed", "progress": 1,
                "playbackContext": try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot.context(at: index, preferred: .audio)!)),
                "completedAt": Date().timeIntervalSince1970, "updatedAt": Date().timeIntervalSince1970]
        }
        manifest["records"] = entries
        try JSONSerialization.data(withJSONObject: manifest).write(to: manifestURL, options: .atomic)
        let loaded = try FileProgressPersistence(root: progressRoot).load()
        precondition(loaded.records.isEmpty && loaded.issues.isEmpty, "必须从空进度仓库实际播放")
    }
}
