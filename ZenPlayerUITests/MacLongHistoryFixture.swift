import Foundation

/// 真实列表／下载入口的长历史样本；存储根来自 MacResumeFixture 的独占 UUID 目录。
nonisolated enum MacLongHistoryFixture {
    private static var server: String { isThirtyPlays ? "https://mac-thirty-plays-validation.invalid/" : "https://mac-long-history-validation.invalid/" }
    static var categoryURL: String { server + "category" }
    static var detailURL: String { server + "series" }
    private static let oldID = 910012
    private static var count: Int { isThirtyPlays ? 30 : 21 }
    private static var seriesID: Int { isThirtyPlays ? 911000 : 910000 }
    private static var seriesTitle: String { isThirtyPlays ? "Mac 三十集系列" : "Mac 長期保留系列" }
    private static var categoryTitle: String { isThirtyPlays ? "Mac 三十集分類" : "Mac 長歷史分類" }

    private static var scenario: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--stage-resume-case"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
    static var isThirtyPlays: Bool { scenario == "thirty-plays" }
    static var isEnabled: Bool { scenario == "long-history" || isThirtyPlays }
    static var catalogEpisodes: [EpisodeItem] { (1...count).map { episode($0) } }
    static var catalogSnapshot: QueueSnapshot {
        QueueSnapshot(seriesID: seriesID, title: seriesTitle, detailURL: detailURL,
                      serverURL: server, episodes: catalogEpisodes, isComplete: true)
    }

    private static func episode(_ number: Int, recent: Bool = false) -> EpisodeItem {
        EpisodeItem(id: (recent ? 910100 : seriesID) + number, num: recent ? "RECENT" : "LONG-HISTORY",
                    title: recent ? "Mac 新近歷史-\(number)" : (isThirtyPlays ? "Mac 三十集-\(number)" : "Mac 長期保留-\(number)"), episode: String(number),
                    mp4Url: "", vodUrl: "", mp3Url: server + "\(recent ? "recent-" : "")\(number).wav",
                    coverUrl: "", textUrl: "", filesize: 1_920_044, duration: 120_000)
    }

    static func responseData(for url: String) throws -> Data {
        let data: [String: Any]
        if url == categoryURL {
            let series = SeriesItem(id: seriesID, title: seriesTitle, cateId: String(seriesID), num: "LONG-HISTORY",
                                    date: "2026-01-01", author: "", address: "", total: count, finish: 1, type: "mp3",
                                    typeName: "音頻", coverUrl: "", url: detailURL, pageUrl: "")
            data = ["serverUrl": server, "updateTime": 0, "total": 1,
                    "rows": try JSONSerialization.jsonObject(with: JSONEncoder().encode([series]))]
        } else if url == detailURL {
            data = ["serverUrl": server, "updateTime": 0, "series": "全\(count)集", "totalCount": count,
                    "speechTitle": seriesTitle, "speechAuthor": "", "speechAddress": "",
                    "speechDate": "", "speechDesc": isThirtyPlays ? "從零實際播放三十集" : "超出最近十條的舊系列",
                    "cateCoverUrl": "", "cateId": String(seriesID),
                    "albumNum": "LONG-HISTORY", "pathTitle": seriesTitle, "type": "mp3",
                    "rows": try JSONSerialization.jsonObject(with: JSONEncoder().encode(catalogEpisodes))]
        } else {
            let category = CategoryItem(title: categoryTitle, cateId: seriesID, url: categoryURL, coverUrl: "", desc: categoryTitle)
            data = ["serverUrl": server, "updateTime": 0, "total": 1, "title": "Mac 長歷史驗證", "subtitle": "",
                    "rows": try JSONSerialization.jsonObject(with: JSONEncoder().encode([category]))]
        }
        return try JSONSerialization.data(withJSONObject: ["code": 1, "msg": "ok", "data": data])
    }

    @MainActor
    static func run(root: URL, arguments: [String]) throws {
        let progressRoot = root.appendingPathComponent("PlaybackProgress/v1")
        let baselineURL = root.appendingPathComponent("long-history-baseline.json")
        let oldName = FileProgressPersistence.digest(Data("\(oldID)|\(server)".utf8)) + ".json"
        if arguments.contains("--stage-verify-resume") {
            let baseline = try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: baselineURL))
            let played = arguments.contains("--stage-verify-long-history-played")
            for (name, bytes) in baseline {
                let actual = try Data(contentsOf: progressRoot.appendingPathComponent("records/" + name))
                if played && name == oldName {
                    let original = try JSONDecoder().decode(PlaybackProgress.self, from: bytes)
                    let saved = try JSONDecoder().decode(PlaybackProgress.self, from: actual)
                    precondition(saved.id == original.id && saved.isValid && saved.state == .inProgress)
                    precondition(saved.positionSeconds >= 44 && saved.revision > original.revision)
                    precondition(saved.lastListenedAt! > original.lastListenedAt!)
                } else {
                    precondition(actual == bytes, "浏览不应写进度，续听也不能改其他单集")
                }
            }
            let loaded = try FileProgressPersistence(root: progressRoot).load()
            precondition(loaded.records.count == 14 && loaded.issues.isEmpty)
            let recent = PlaybackProgress.recent(loaded.records)
            precondition(recent.count == 10)
            precondition(recent.contains { $0.context.episode.id == oldID } == played)
            return // 只读核验：播放后只有旧目标允许更新，其他 13 条字节不变。
        }
        precondition(!FileManager.default.fileExists(atPath: root.path), "拒绝覆盖长历史样本")
        let records = progressRoot.appendingPathComponent("records")
        try FileManager.default.createDirectory(at: records, withIntermediateDirectories: true)
        let snapshot = QueueSnapshot(seriesID: 910000, title: "Mac 長期保留系列", detailURL: detailURL,
                                     serverURL: server, episodes: (1...21).map { episode($0) }, isComplete: true)
        let snapshots = root.appendingPathComponent("PlaybackQueue/v1")
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: snapshots.appendingPathComponent(snapshot.id + ".json"), options: .atomic)
        var baseline: [String: Data] = [:]
        func save(_ context: PlaybackContext, position: Double, offset: Double, completed: Bool = false) throws {
            let date = Date(timeIntervalSince1970: 1_700_000_000 + offset)
            var record = PlaybackProgress(context: context, now: date)
            record.update(position: position, mediaDuration: 120, event: .advance, now: date)
            if completed { record.update(position: position, mediaDuration: 120, event: .ended, now: date) }
            let bytes = try JSONEncoder().encode(record)
            let name = FileProgressPersistence.digest(Data(record.id.utf8)) + ".json"
            try bytes.write(to: records.appendingPathComponent(name), options: .atomic)
            baseline[name] = bytes
        }
        try save(snapshot.context(at: 11, preferred: .audio)!, position: 42, offset: 0)
        try save(snapshot.context(at: 17, preferred: .audio)!, position: 120, offset: -60, completed: true)
        for number in 1...12 {
            try save(PlaybackContext(episode: episode(number, recent: true), serverUrl: server, preferredMediaType: .audio),
                     position: 7, offset: Double(number * 60))
        }
        try JSONEncoder().encode(baseline).write(to: baselineURL, options: .atomic)
        // 仅合并此夹具拥有的下载键；保留同一验证容器中的其他下载。
        let media = root.appendingPathComponent("old-12.wav")
        try MacQueueFixture.silence(seconds: 120).write(to: media, options: .atomic)
        let downloads = URL.documentsDirectory.appendingPathComponent("ZenPlayerDownloads")
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let manifestURL = downloads.appendingPathComponent("download_manifest.json")
        var manifest: [String: Any] = ["version": 2, "records": [String: Any]()]
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
            precondition(manifest["version"] as? Int == 2)
        }
        var entries = manifest["records"] as! [String: Any]
        entries["\(oldID)_mp3"] = ["episodeId": oldID, "type": "mp3", "remoteURL": episode(12).mp3Url!,
            "destinationRelativePath": media.path, "status": "completed", "progress": 1,
            "playbackContext": try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot.context(at: 11, preferred: .audio)!)),
            "completedAt": Date().timeIntervalSince1970, "updatedAt": Date().timeIntervalSince1970]
        manifest["records"] = entries
        try JSONSerialization.data(withJSONObject: manifest).write(to: manifestURL, options: .atomic)
        let loaded = try FileProgressPersistence(root: progressRoot).load()
        precondition(loaded.records.count == 14 && loaded.issues.isEmpty)
        precondition(PlaybackProgress.recent(loaded.records).allSatisfy { $0.context.episode.id >= 910100 })
    }
}
