import Foundation

/// 仅由 Mac 验证脚本注入共享仓库根路径；每次用例独占目录，不清空既有验证数据。
@MainActor
enum MacResumeFixture {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    private static var scenario: String? {
        guard let index = arguments.firstIndex(of: "--stage-resume-case") else { return nil }
        precondition(arguments.indices.contains(index + 1))
        let value = arguments[index + 1]
        precondition(["empty", "next", "blocked", "fallback"].contains(value))
        return value
    }

    private static var root: URL? {
        guard scenario != nil else { return nil }
        let bundle = "com.jxing.ZenPlayer.MacStageValidation"
        precondition(Bundle.main.bundleIdentifier == bundle)
        precondition(NSHomeDirectory().contains("/Library/Containers/\(bundle)/Data"))
        guard let index = arguments.firstIndex(of: "--stage-resume-run"),
              arguments.indices.contains(index + 1), let id = UUID(uuidString: arguments[index + 1]) else {
            preconditionFailure("候选测试缺少独占目录 UUID")
        }
        return URL.applicationSupportDirectory.appendingPathComponent("StageValidation/resume-\(id.uuidString)")
    }

    static func storageRoot(_ component: String) -> URL {
        (root ?? URL.applicationSupportDirectory).appendingPathComponent(component)
    }

    static func legacySource() -> Data? {
        scenario == nil ? UserDefaults.standard.data(forKey: "recentPlayback.records") : nil
    }

    static func run() throws {
        guard let scenario, let root else { preconditionFailure("缺少候选场景") }
        let baselineURL = root.appendingPathComponent("baseline.json")
        if arguments.contains("--stage-verify-resume") {
            let baseline = try JSONDecoder().decode([String: Data].self, from: Data(contentsOf: baselineURL))
            for (path, bytes) in baseline {
                let actual = try Data(contentsOf: root.appendingPathComponent(path))
                precondition(actual == bytes,
                             "仅浏览首页不应改变候选的进度或快照")
            }
            let records = try FileProgressPersistence(root: storageRoot("PlaybackProgress/v1")).load()
            let expectedCount = scenario == "empty" ? 0 : (scenario == "fallback" ? 3 : 2)
            precondition(records.records.count == expectedCount && records.issues.isEmpty)
            return // 冷启动只读核对，不重新播种。
        }
        precondition(!FileManager.default.fileExists(atPath: root.path), "拒绝覆盖既有候选样本")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var baseline: [String: Data] = [:]
        func save<T: Encodable>(_ object: T, at path: String) throws {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let bytes = try JSONEncoder().encode(object)
            try bytes.write(to: url, options: .atomic)
            baseline[path] = bytes
        }
        if scenario != "empty" {
            let server = "https://mac-resume-validation.invalid/"
            func episode(_ number: Int, title: String? = nil, duration: Int = 120_000) -> EpisodeItem {
                EpisodeItem(id: 909000 + number, num: "MAC-RESUME-\(number)",
                            title: title ?? "Mac 候選驗證-\(number)", episode: String(number),
                            mp4Url: "", vodUrl: "", mp3Url: server + "\(number).wav", coverUrl: "", textUrl: "",
                            filesize: 0, duration: duration)
            }
            let snapshot = QueueSnapshot(seriesID: 909000, title: "Mac 候選驗證系列", detailURL: server + "series",
                                         serverURL: server, episodes: (1...3).map { episode($0) }, isComplete: true)
            precondition(snapshot.isValid)
            try save(snapshot, at: "PlaybackQueue/v1/\(snapshot.id).json")
            for index in 0...1 {
                let date = Date(timeIntervalSince1970: 1_700_000_000 - Double(index * 60))
                var progress = PlaybackProgress(context: snapshot.context(at: index, preferred: .audio)!, now: date)
                let completed = index == 0 || scenario != "next"
                progress.update(position: completed ? 120 : 7, mediaDuration: 120,
                                event: .advance, now: date)
                if completed { progress.update(position: 120, mediaDuration: 120, event: .ended, now: date) }
                precondition(progress.lastListenedAt == date && progress.isValid)
                try save(progress, at: "PlaybackProgress/v1/records/\(FileProgressPersistence.digest(Data(progress.id.utf8))).json")
            }
            if scenario == "fallback" {
                let date = Date(timeIntervalSince1970: 1_699_999_800)
                let context = PlaybackContext(episode: episode(4, title: "Mac 其他未完成驗證", duration: 0),
                                              serverUrl: server, preferredMediaType: .audio)
                var progress = PlaybackProgress(context: context, now: date)
                progress.update(position: 42, mediaDuration: nil, event: .advance, now: date)
                precondition(progress.durationSeconds == nil)
                try save(progress, at: "PlaybackProgress/v1/records/\(FileProgressPersistence.digest(Data(progress.id.utf8))).json")
            }
        }
        try JSONEncoder().encode(baseline).write(to: baselineURL, options: .atomic)
    }
}
