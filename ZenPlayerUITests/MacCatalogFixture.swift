import Foundation

/// 历史定位使用确定的 21 集目录和两条进度；只写独立验证容器的专属键。
nonisolated enum MacCatalogFixture {
    private static let server = "https://mac-catalog-validation.invalid/"
    static let detailURL = server + "series"
    private static let snapshotID = "8B1F35A0-DBA6-4465-9970-0B562ED97DAD"
    private static var edgeCases: Bool { ProcessInfo.processInfo.arguments.contains("--stage-catalog-edge-cases") }

    private static var episodes: [EpisodeItem] {
        (1...21).map { number in
            let episodeNumber = edgeCases ? (number == 1 ? 0 : (number == 18 ? 12 : number)) : number
            return EpisodeItem(id: 900200 + number, num: "MAC-CATALOG", title: "Mac 定位驗證-\(number)",
                               episode: String(episodeNumber), mp4Url: "", vodUrl: "", mp3Url: server + "\(number).wav",
                               coverUrl: "", textUrl: "", filesize: 0, duration: 120_000)
        }
    }

    static func responseData() throws -> Data {
        let detail: [String: Any] = [
            "serverUrl": server, "updateTime": 0, "series": edgeCases ? "全24集" : "全21集",
            "totalCount": edgeCases ? 24 : 21,
            "speechTitle": "Mac 歷史定位驗證系列", "speechAuthor": "", "speechAddress": "",
            "speechDate": "", "speechDesc": "隔離目錄樣本", "cateCoverUrl": "", "cateId": "900200",
            "albumNum": "MAC-CATALOG", "pathTitle": "Mac 歷史定位驗證系列", "type": "mp3",
            "rows": try JSONSerialization.jsonObject(with: JSONEncoder().encode(episodes))
        ]
        return try JSONSerialization.data(withJSONObject: ["code": 1, "msg": "ok", "data": detail])
    }

    @MainActor
    static func run(arguments: [String]) throws {
        let bundle = "com.jxing.ZenPlayer.MacStageValidation"
        precondition(Bundle.main.bundleIdentifier == bundle)
        precondition(NSHomeDirectory().contains("/Library/Containers/\(bundle)/Data"))
        let support = URL.applicationSupportDirectory
        let records = support.appendingPathComponent("PlaybackProgress/v1/records")
        let baseline = support.appendingPathComponent("StageValidation/catalog-progress-baseline.json")
        if arguments.contains("--stage-verify-catalog") {
            let expected = try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: baseline))
            precondition(expected.count == 2)
            for (name, bytes) in expected {
                let actual = try Data(contentsOf: records.appendingPathComponent(name))
                precondition(actual == bytes, "仅浏览／定位不应修改进度文件")
            }
            return // 冷启动核对原始字节，不重新播种。
        }
        precondition(arguments.contains("--stage-seed-catalog"))
        let snapshotObject: [String: Any] = [
            "schemaVersion": 1, "id": snapshotID, "seriesID": 900200, "title": "Mac 歷史定位驗證系列",
            "detailURL": detailURL, "serverURL": server, "isComplete": !edgeCases, "createdAt": 0,
            "episodes": try JSONSerialization.jsonObject(with: JSONEncoder().encode(episodes))
        ]
        let snapshot = try JSONDecoder().decode(QueueSnapshot.self, from: JSONSerialization.data(withJSONObject: snapshotObject))
        precondition(snapshot.isValid)
        let snapshots = support.appendingPathComponent("PlaybackQueue/v1")
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: snapshots.appendingPathComponent(snapshotID + ".json"), options: .atomic)
        try FileManager.default.createDirectory(at: records, withIntermediateDirectories: true)
        var expected: [String: Data] = [:]
        let now = Date()
        for number in [12, 18] {
            let date = now.addingTimeInterval(number == 12 ? 0 : -60)
            var progress = PlaybackProgress(context: snapshot.context(at: number - 1, preferred: .audio)!, now: date)
            progress.update(position: number == 12 ? 42 : 120, mediaDuration: 120, event: .advance, now: date)
            if number == 18 { progress.update(position: 120, mediaDuration: 120, event: .ended, now: date) }
            let bytes = try JSONEncoder().encode(progress)
            let name = FileProgressPersistence.digest(Data(progress.legacyKey.utf8)) + ".json"
            try bytes.write(to: records.appendingPathComponent(name), options: .atomic)
            expected[name] = bytes
        }
        try FileManager.default.createDirectory(at: baseline.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(expected).write(to: baseline, options: .atomic)
    }
}
