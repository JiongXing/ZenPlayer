//
//  DownloadManager.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UniformTypeIdentifiers
import os.log

// MARK: - 下载类型

/// 下载类型：音频 (mp3) 或视频 (mp4)
enum DownloadType: String, Codable {
    case mp3
    case mp4
}

// MARK: - 文件名清理

/// 将标题中的非法文件名字符替换为安全字符
private func sanitizedFileName(from title: String) -> String {
    let invalid = CharacterSet(charactersIn: "/:\\*?\"<>|")
    let cleaned = title
        .components(separatedBy: invalid)
        .joined(separator: "_")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let result = String(cleaned.prefix(100))
    return result.isEmpty ? "untitled" : result
}

// MARK: - 下载状态

/// 单集下载状态
enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)  // 0.0 ~ 1.0
    case paused(progress: Double)       // 0.0 ~ 1.0
    case completed
    case failed(String)

    /// 用于 Equatable 比较
    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.downloading(let a), .downloading(let b)):
            return a == b
        case (.paused(let a), .paused(let b)):
            return a == b
        case (.completed, .completed):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - iOS 下载委托

#if os(iOS)
private final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    var onProgress: ((Int, Int64, Int64) -> Void)?
    var onFinished: ((Int, URL) -> Void)?
    var onCompleted: ((Int, Error?) -> Void)?
    var onDidFinishEvents: (() -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress?(downloadTask.taskIdentifier, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // URLSession 提供的临时文件仅在回调期间有效，先转存到稳定临时路径再异步处理。
        let preservedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZenPlayerDownload_\(downloadTask.taskIdentifier)_\(UUID().uuidString).tmp")
        do {
            if FileManager.default.fileExists(atPath: preservedURL.path) {
                try FileManager.default.removeItem(at: preservedURL)
            }
            try FileManager.default.moveItem(at: location, to: preservedURL)
            onFinished?(downloadTask.taskIdentifier, preservedURL)
        } catch {
            onCompleted?(downloadTask.taskIdentifier, error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        onCompleted?(task.taskIdentifier, error)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        onDidFinishEvents?()
    }
}
#endif

// MARK: - 下载清单持久化

#if os(iOS)
private enum PersistedDownloadStatus: String, Codable {
    case downloading
    case paused
    case completed
    case failed
}

private struct DownloadRecord: Codable {
    var episodeId: Int
    var type: DownloadType
    var remoteURL: String
    var destinationRelativePath: String
    var status: PersistedDownloadStatus
    var progress: Double
    var resumeDataRelativePath: String?
    var updatedAt: TimeInterval
}

private struct DownloadManifest: Codable {
    var version: Int = 1
    var records: [String: DownloadRecord] = [:]
}
#endif

// MARK: - 下载管理器

/// 全局下载管理器，管理所有单集的下载任务与状态
@MainActor
@Observable
final class DownloadManager {

    /// 单例
    static let shared = DownloadManager()

#if os(iOS)
    /// iOS 后台下载 Session 标识，必须稳定不变，系统据此恢复任务。
    static let backgroundSessionIdentifier = "\(Bundle.main.bundleIdentifier ?? "ZenPlayer").download.background"
#endif

    // MARK: - 可观察状态

    /// 每个单集的下载状态（key: "\(episodeId)_mp3" 或 "\(episodeId)_mp4"）
    var downloadStates: [String: DownloadState] = [:]

    /// 已完成下载的本地文件 URL（key 同 downloadStates），用于 iOS 分享与播放
    var completedFileURLs: [String: URL] = [:]

    // MARK: - 私有属性

    /// macOS 兼容下载任务（iOS 使用 URLSessionDownloadTask）
    @ObservationIgnored
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    /// 直链下载服务（用于 macOS 回退路径）
    @ObservationIgnored
    private let directDownloadService = MP3DownloadService()

    @ObservationIgnored
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZenPlayer", category: "DownloadManager")

    /// 下载根目录：Documents/ZenPlayerDownloads/
    private var downloadsRootURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZenPlayerDownloads", isDirectory: true)
    }

    /// 清单文件路径
    private var manifestURL: URL {
        downloadsRootURL.appendingPathComponent("download_manifest.json", isDirectory: false)
    }

#if os(iOS)
    private struct ActiveDownloadTask {
        let task: URLSessionDownloadTask
        let episodeId: Int
        let type: DownloadType
        let remoteURLString: String
        let destinationURL: URL
        let usedResumeData: Bool
    }

    private enum CancellationIntent {
        case pause
        case cancel
    }

    @ObservationIgnored
    private let sessionDelegate = DownloadSessionDelegate()

    @ObservationIgnored
    private var downloadSession: URLSession!

    @ObservationIgnored
    private var backgroundSessionCompletionHandler: (() -> Void)?

    /// key -> 活跃下载任务
    private var activeDownloads: [String: ActiveDownloadTask] = [:]

    /// taskIdentifier -> key
    private var taskKeyMap: [Int: String] = [:]

    /// key -> 用户触发的取消意图（暂停/取消）
    private var cancelIntents: [String: CancellationIntent] = [:]

    /// key -> 持久化记录
    private var downloadRecords: [String: DownloadRecord] = [:]

    private var manifestSaveTask: Task<Void, Never>?
    private let manifestDebounceNanoseconds: UInt64 = 300_000_000

    private var resumeDataRootURL: URL {
        downloadsRootURL.appendingPathComponent("resumeData", isDirectory: true)
    }
#endif

    private init() {
#if os(iOS)
        downloadSession = makeDownloadSession()
        bindSessionCallbacks()
#endif
        restoreFromManifest()
#if os(iOS)
        reattachActiveSystemTasks()
#endif
    }

    // MARK: - 公共接口

    /// 生成下载状态的唯一 key
    /// - Parameters:
    ///   - episodeId: 单集 ID
    ///   - type: 下载类型（mp3 / mp4）
    static func downloadKey(episodeId: Int, type: DownloadType) -> String {
        "\(episodeId)_\(type.rawValue)"
    }

    /// 获取指定单集某种类型的下载状态
    func state(for episodeId: Int, type: DownloadType) -> DownloadState {
        let key = Self.downloadKey(episodeId: episodeId, type: type)
        return downloadStates[key] ?? .idle
    }

#if os(iOS)
    /// 将 AppDelegate 的后台 URLSession 完成回调交给下载管理器。
    func setBackgroundSessionCompletionHandler(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == Self.backgroundSessionIdentifier else { return }
        backgroundSessionCompletionHandler = completionHandler

        // 若当前没有活跃任务，立即回调，避免系统等待超时。
        if activeDownloads.isEmpty {
            finishBackgroundSessionEventsIfNeeded()
        }
    }
#endif

    /// 开始下载单集的音频或视频
    /// - Parameters:
    ///   - episode: 要下载的单集
    ///   - type: 下载类型（.mp3 音频 / .mp4 视频）
    ///   - serverUrl: 服务器根地址，用于拼接 mp4 的相对路径
    func startDownload(episode: EpisodeItem, type: DownloadType, serverUrl: String) {
        let key = Self.downloadKey(episodeId: episode.id, type: type)

        guard let remoteURLString = makeRemoteURLString(episode: episode, type: type, serverUrl: serverUrl) else {
            switch type {
            case .mp3:
                downloadStates[key] = .failed("该集没有可下载的音频地址")
            case .mp4:
                downloadStates[key] = .failed("该集没有可下载的视频地址")
            }
            return
        }

#if os(iOS)
        let destinationURL = makeIOSDestinationURL(episodeId: episode.id, title: episode.title, type: type)
        startIOSDownload(
            key: key,
            episodeId: episode.id,
            type: type,
            remoteURLString: remoteURLString,
            destinationURL: destinationURL,
            resumeData: nil,
            initialProgress: 0,
            persistedProgress: 0
        )
#else
        startMacDownload(
            key: key,
            episode: episode,
            type: type,
            remoteURLString: remoteURLString
        )
#endif
    }

    /// 暂停指定下载（iOS 真正断点续传；macOS 退化为取消）
    func pauseDownload(episodeId: Int, type: DownloadType) {
        let key = Self.downloadKey(episodeId: episodeId, type: type)
#if os(iOS)
        guard let active = activeDownloads[key] else { return }
        cancelIntents[key] = .pause
        active.task.cancel(byProducingResumeData: { [weak self] resumeData in
            Task { @MainActor [weak self] in
                self?.storePausedState(for: key, resumeData: resumeData)
            }
        })
#else
        cancelDownload(episodeId: episodeId, type: type)
#endif
    }

    /// 继续指定下载（仅 iOS）
    func resumeDownload(episodeId: Int, type: DownloadType) {
        let key = Self.downloadKey(episodeId: episodeId, type: type)
#if os(iOS)
        guard activeDownloads[key] == nil else { return }
        guard var record = downloadRecords[key] else { return }
        let destinationURL = absoluteURL(fromRelativePath: record.destinationRelativePath)

        var resumeData: Data?
        if let resumePath = record.resumeDataRelativePath {
            resumeData = loadResumeData(fromRelativePath: resumePath)
            if resumeData == nil {
                record.resumeDataRelativePath = nil
                record.progress = 0
                downloadRecords[key] = record
            }
        } else {
            record.progress = 0
            downloadRecords[key] = record
        }

        startIOSDownload(
            key: key,
            episodeId: record.episodeId,
            type: record.type,
            remoteURLString: record.remoteURL,
            destinationURL: destinationURL,
            resumeData: resumeData,
            initialProgress: record.progress,
            persistedProgress: record.progress
        )
#endif
    }

    /// 获取已完成下载的本地文件 URL（会自动清理失效记录）
    func completedFileURL(for episodeId: Int, type: DownloadType) -> URL? {
        let key = Self.downloadKey(episodeId: episodeId, type: type)
        guard let url = completedFileURLs[key] else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.warning("⚠️ 本地文件缺失，移除失效记录 key=\(key)")
#if os(iOS)
            removeRecordAndArtifacts(for: key, resetStateToIdle: true)
#else
            completedFileURLs.removeValue(forKey: key)
            downloadStates[key] = .idle
#endif
            return nil
        }
        return url
    }

    /// 取消指定单集某种类型的下载
    /// - Parameters:
    ///   - episodeId: 单集 ID
    ///   - type: 下载类型
    func cancelDownload(episodeId: Int, type: DownloadType) {
        let key = Self.downloadKey(episodeId: episodeId, type: type)
#if os(iOS)
        if let active = activeDownloads[key] {
            cancelIntents[key] = .cancel
            active.task.cancel()
            return
        }
        removeRecordAndArtifacts(for: key, resetStateToIdle: true)
#else
        downloadTasks[key]?.cancel()
        downloadTasks.removeValue(forKey: key)
        downloadStates[key] = .idle
        logger.info("🛑 取消下载 episodeId=\(episodeId) type=\(type.rawValue)")
#endif
    }

    // MARK: - 公共辅助

    /// 拼接远端下载 URL（mp4 支持 serverUrl + 相对路径）
    private func makeRemoteURLString(episode: EpisodeItem, type: DownloadType, serverUrl: String) -> String? {
        switch type {
        case .mp3:
            if let mp3URL = episode.mp3Url, !mp3URL.isEmpty {
                return mp3URL
            }
            // 兼容纯音频专辑：后端偶发将音频地址填在 mp4_url 字段。
            guard !episode.mp4Url.isEmpty else { return nil }
            if let url = URL(string: episode.mp4Url), url.scheme != nil {
                return episode.mp4Url
            }
            let base = serverUrl.hasSuffix("/") ? String(serverUrl.dropLast()) : serverUrl
            let path = episode.mp4Url.hasPrefix("/") ? episode.mp4Url : "/" + episode.mp4Url
            return base + path
        case .mp4:
            guard !episode.mp4Url.isEmpty else { return nil }
            if let url = URL(string: episode.mp4Url), url.scheme != nil {
                return episode.mp4Url
            }
            let base = serverUrl.hasSuffix("/") ? String(serverUrl.dropLast()) : serverUrl
            let path = episode.mp4Url.hasPrefix("/") ? episode.mp4Url : "/" + episode.mp4Url
            return base + path
        }
    }

#if os(iOS)
    // MARK: - iOS：URLSession 绑定

    private func makeDownloadSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: Self.backgroundSessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 1800
        return URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    }

    private func bindSessionCallbacks() {
        sessionDelegate.onProgress = { [weak self] taskIdentifier, totalBytesWritten, totalBytesExpectedToWrite in
            Task { @MainActor [weak self] in
                self?.handleDownloadProgress(
                    taskIdentifier: taskIdentifier,
                    totalBytesWritten: totalBytesWritten,
                    totalBytesExpectedToWrite: totalBytesExpectedToWrite
                )
            }
        }
        sessionDelegate.onFinished = { [weak self] taskIdentifier, location in
            Task { @MainActor [weak self] in
                self?.handleDidFinishDownloading(taskIdentifier: taskIdentifier, tempLocation: location)
            }
        }
        sessionDelegate.onCompleted = { [weak self] taskIdentifier, error in
            Task { @MainActor [weak self] in
                self?.handleDidComplete(taskIdentifier: taskIdentifier, error: error)
            }
        }
        sessionDelegate.onDidFinishEvents = { [weak self] in
            Task { @MainActor [weak self] in
                self?.finishBackgroundSessionEventsIfNeeded()
            }
        }
    }

    private func finishBackgroundSessionEventsIfNeeded() {
        guard let completion = backgroundSessionCompletionHandler else { return }
        backgroundSessionCompletionHandler = nil
        completion()
    }

    /// App 冷启动后重新挂接系统托管的后台下载任务。
    private func reattachActiveSystemTasks() {
        downloadSession.getAllTasks { [weak self] tasks in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var restoredCount = 0

                for task in tasks {
                    guard let downloadTask = task as? URLSessionDownloadTask else { continue }
                    guard let key = downloadTask.taskDescription else {
                        downloadTask.cancel()
                        continue
                    }
                    guard var record = self.downloadRecords[key] else {
                        downloadTask.cancel()
                        continue
                    }

                    let destinationURL = self.absoluteURL(fromRelativePath: record.destinationRelativePath)
                    let active = ActiveDownloadTask(
                        task: downloadTask,
                        episodeId: record.episodeId,
                        type: record.type,
                        remoteURLString: record.remoteURL,
                        destinationURL: destinationURL,
                        usedResumeData: false
                    )
                    self.activeDownloads[key] = active
                    self.taskKeyMap[downloadTask.taskIdentifier] = key

                    let clampedProgress = max(0, min(1, record.progress))
                    self.downloadStates[key] = .downloading(progress: clampedProgress)
                    record.status = .downloading
                    record.updatedAt = Date().timeIntervalSince1970
                    self.downloadRecords[key] = record
                    restoredCount += 1
                }

                if restoredCount > 0 {
                    self.scheduleManifestSave()
                    self.logger.info("📡 已重新挂接 \(restoredCount) 个后台下载任务")
                }
            }
        }
    }

    // MARK: - iOS：下载任务

    private func makeIOSDestinationURL(episodeId: Int, title: String, type: DownloadType) -> URL {
        let safeTitle = sanitizedFileName(from: title)
        let fileName = "\(episodeId)_\(safeTitle).\(type.rawValue)"
        let subDir = downloadsRootURL.appendingPathComponent(type.rawValue, isDirectory: true)
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        return subDir.appendingPathComponent(fileName)
    }

    private func startIOSDownload(
        key: String,
        episodeId: Int,
        type: DownloadType,
        remoteURLString: String,
        destinationURL: URL,
        resumeData: Data?,
        initialProgress: Double,
        persistedProgress: Double
    ) {
        guard activeDownloads[key] == nil else { return }
        guard let remoteURL = URL(string: remoteURLString) else {
            downloadStates[key] = .failed("无效的下载地址")
            return
        }

        let destinationRelativePath = relativePath(fromAbsoluteURL: destinationURL) ?? "\(type.rawValue)/\(destinationURL.lastPathComponent)"
        var record = downloadRecords[key] ?? DownloadRecord(
            episodeId: episodeId,
            type: type,
            remoteURL: remoteURLString,
            destinationRelativePath: destinationRelativePath,
            status: .downloading,
            progress: 0,
            resumeDataRelativePath: nil,
            updatedAt: Date().timeIntervalSince1970
        )
        record.episodeId = episodeId
        record.type = type
        record.remoteURL = remoteURLString
        record.destinationRelativePath = destinationRelativePath
        record.status = .downloading
        record.progress = max(0, min(1, persistedProgress))
        if resumeData == nil, let oldResumePath = record.resumeDataRelativePath {
            removeResumeDataFile(atRelativePath: oldResumePath)
            record.resumeDataRelativePath = nil
        }
        record.updatedAt = Date().timeIntervalSince1970
        downloadRecords[key] = record

        downloadStates[key] = .downloading(progress: max(0, min(1, initialProgress)))
        completedFileURLs.removeValue(forKey: key)
        scheduleManifestSave()

        let task: URLSessionDownloadTask
        if let resumeData {
            task = downloadSession.downloadTask(withResumeData: resumeData)
        } else {
            task = downloadSession.downloadTask(with: URLRequest(url: remoteURL))
        }
        task.taskDescription = key
        let active = ActiveDownloadTask(
            task: task,
            episodeId: episodeId,
            type: type,
            remoteURLString: remoteURLString,
            destinationURL: destinationURL,
            usedResumeData: resumeData != nil
        )
        activeDownloads[key] = active
        taskKeyMap[task.taskIdentifier] = key
        task.resume()
    }

    private func removeActiveDownload(for key: String) {
        guard let active = activeDownloads.removeValue(forKey: key) else { return }
        taskKeyMap.removeValue(forKey: active.task.taskIdentifier)
        if activeDownloads.isEmpty {
            finishBackgroundSessionEventsIfNeeded()
        }
    }

    private func handleDownloadProgress(
        taskIdentifier: Int,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let key = taskKeyMap[taskIdentifier] else { return }
        guard case .downloading = downloadStates[key] else { return }

        let candidateProgress: Double
        if totalBytesExpectedToWrite > 0 {
            candidateProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            candidateProgress = progressFromState(for: key, fallback: downloadRecords[key]?.progress ?? 0)
        }

        let clamped = max(0, min(1, candidateProgress))
        downloadStates[key] = .downloading(progress: clamped)

        if var record = downloadRecords[key], record.status != .completed {
            // 对 resume 场景使用 max，避免回调进度回退导致 UI 抖动。
            record.progress = max(record.progress, clamped)
            record.status = .downloading
            record.updatedAt = Date().timeIntervalSince1970
            downloadRecords[key] = record
            scheduleManifestSave()
        }
    }

    private func handleDidFinishDownloading(taskIdentifier: Int, tempLocation: URL) {
        guard let key = taskKeyMap[taskIdentifier], let active = activeDownloads[key] else { return }

        do {
            let parent = active.destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: active.destinationURL.path) {
                try FileManager.default.removeItem(at: active.destinationURL)
            }
            try FileManager.default.moveItem(at: tempLocation, to: active.destinationURL)

            removeActiveDownload(for: key)
            cancelIntents.removeValue(forKey: key)

            completedFileURLs[key] = active.destinationURL
            downloadStates[key] = .completed

            var record = downloadRecords[key] ?? DownloadRecord(
                episodeId: active.episodeId,
                type: active.type,
                remoteURL: active.remoteURLString,
                destinationRelativePath: relativePath(fromAbsoluteURL: active.destinationURL) ?? "\(active.type.rawValue)/\(active.destinationURL.lastPathComponent)",
                status: .completed,
                progress: 1,
                resumeDataRelativePath: nil,
                updatedAt: Date().timeIntervalSince1970
            )
            if let oldResumePath = record.resumeDataRelativePath {
                removeResumeDataFile(atRelativePath: oldResumePath)
            }
            record.status = .completed
            record.progress = 1
            record.resumeDataRelativePath = nil
            record.updatedAt = Date().timeIntervalSince1970
            downloadRecords[key] = record
            scheduleManifestSave()

            logger.info("✅ 下载完成 key=\(key)")
        } catch {
            removeActiveDownload(for: key)
            cancelIntents.removeValue(forKey: key)
            downloadStates[key] = .failed(error.localizedDescription)
            try? FileManager.default.removeItem(at: tempLocation)
            if var record = downloadRecords[key] {
                record.status = .failed
                record.updatedAt = Date().timeIntervalSince1970
                downloadRecords[key] = record
                scheduleManifestSave()
            }
            logger.error("❌ 移动下载文件失败 key=\(key) - \(error.localizedDescription)")
        }
    }

    private func handleDidComplete(taskIdentifier: Int, error: Error?) {
        guard let key = taskKeyMap[taskIdentifier], let active = activeDownloads[key] else { return }
        guard let nsError = error as NSError? else {
            // 正常完成场景由 didFinishDownloadingTo 处理
            return
        }

        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            let intent = cancelIntents.removeValue(forKey: key)
            removeActiveDownload(for: key)

            switch intent {
            case .pause:
                if case .paused = downloadStates[key] { return }
                let progress = progressFromState(for: key, fallback: downloadRecords[key]?.progress ?? 0)
                downloadStates[key] = .paused(progress: progress)
                if var record = downloadRecords[key] {
                    record.status = .paused
                    record.progress = progress
                    record.updatedAt = Date().timeIntervalSince1970
                    downloadRecords[key] = record
                    scheduleManifestSave()
                }
            case .cancel:
                removeRecordAndArtifacts(for: key, resetStateToIdle: true)
            case .none:
                downloadStates[key] = .idle
            }
            return
        }

        // resumeData 无效时自动降级为全量重下
        if active.usedResumeData, shouldFallbackToFreshDownload(error: nsError) {
            removeActiveDownload(for: key)
            cancelIntents.removeValue(forKey: key)
            logger.warning("⚠️ resumeData 无效，降级全量重下 key=\(key)")

            guard var record = downloadRecords[key] else {
                downloadStates[key] = .failed("恢复下载失败，请重试")
                return
            }
            if let resumePath = record.resumeDataRelativePath {
                removeResumeDataFile(atRelativePath: resumePath)
            }
            record.resumeDataRelativePath = nil
            record.progress = 0
            record.status = .paused
            record.updatedAt = Date().timeIntervalSince1970
            downloadRecords[key] = record
            scheduleManifestSave()

            let destinationURL = absoluteURL(fromRelativePath: record.destinationRelativePath)
            startIOSDownload(
                key: key,
                episodeId: record.episodeId,
                type: record.type,
                remoteURLString: record.remoteURL,
                destinationURL: destinationURL,
                resumeData: nil,
                initialProgress: 0,
                persistedProgress: 0
            )
            return
        }

        removeActiveDownload(for: key)
        cancelIntents.removeValue(forKey: key)
        downloadStates[key] = .failed(nsError.localizedDescription)
        if var record = downloadRecords[key] {
            record.status = .failed
            record.updatedAt = Date().timeIntervalSince1970
            downloadRecords[key] = record
            scheduleManifestSave()
        }
        logger.error("❌ 下载失败 key=\(key) - \(nsError.localizedDescription)")
    }

    private func shouldFallbackToFreshDownload(error: NSError) -> Bool {
        if error.domain == NSURLErrorDomain, error.code == URLError.Code.cannotDecodeRawData.rawValue {
            return true
        }
        return error.localizedDescription.localizedCaseInsensitiveContains("resume")
    }

    private func storePausedState(for key: String, resumeData: Data?) {
        guard var record = downloadRecords[key] else { return }
        if let resumeData, let resumePath = persistResumeData(resumeData, for: key) {
            if let oldPath = record.resumeDataRelativePath, oldPath != resumePath {
                removeResumeDataFile(atRelativePath: oldPath)
            }
            record.resumeDataRelativePath = resumePath
        } else {
            record.resumeDataRelativePath = nil
        }
        let progress = progressFromState(for: key, fallback: record.progress)
        record.progress = progress
        record.status = .paused
        record.updatedAt = Date().timeIntervalSince1970
        downloadRecords[key] = record
        downloadStates[key] = .paused(progress: progress)
        scheduleManifestSave()
    }

    // MARK: - iOS：持久化

    private func relativePath(fromAbsoluteURL url: URL) -> String? {
        let base = downloadsRootURL.path + "/"
        let full = url.path
        guard full.hasPrefix(base) else { return nil }
        let relative = String(full.dropFirst(base.count))
        return relative.isEmpty ? nil : relative
    }

    private func absoluteURL(fromRelativePath relativePath: String) -> URL {
        downloadsRootURL.appendingPathComponent(relativePath)
    }

    private func persistResumeData(_ resumeData: Data, for key: String) -> String? {
        do {
            try FileManager.default.createDirectory(at: resumeDataRootURL, withIntermediateDirectories: true)
            let url = resumeDataRootURL.appendingPathComponent("\(key).resume", isDirectory: false)
            try resumeData.write(to: url, options: .atomic)
            return relativePath(fromAbsoluteURL: url)
        } catch {
            logger.error("❌ 保存 resumeData 失败 key=\(key) - \(error.localizedDescription)")
            return nil
        }
    }

    private func loadResumeData(fromRelativePath relativePath: String) -> Data? {
        let url = absoluteURL(fromRelativePath: relativePath)
        return try? Data(contentsOf: url)
    }

    private func removeResumeDataFile(atRelativePath relativePath: String) {
        let url = absoluteURL(fromRelativePath: relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func removeRecordAndArtifacts(for key: String, resetStateToIdle: Bool) {
        if let record = downloadRecords.removeValue(forKey: key), let resumePath = record.resumeDataRelativePath {
            removeResumeDataFile(atRelativePath: resumePath)
        }
        completedFileURLs.removeValue(forKey: key)
        if resetStateToIdle {
            downloadStates[key] = .idle
        }
        scheduleManifestSave()
    }

    private func progressFromState(for key: String, fallback: Double) -> Double {
        switch downloadStates[key] {
        case .downloading(let p):
            return p
        case .paused(let p):
            return p
        default:
            return fallback
        }
    }

    private func scheduleManifestSave() {
        manifestSaveTask?.cancel()
        manifestSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.manifestDebounceNanoseconds ?? 300_000_000)
            guard !Task.isCancelled else { return }
            self?.saveManifestNow()
        }
    }

    private func saveManifestNow() {
        do {
            try FileManager.default.createDirectory(at: downloadsRootURL, withIntermediateDirectories: true)
            let manifest = DownloadManifest(version: 1, records: downloadRecords)
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: manifestURL, options: .atomic)
        } catch {
            logger.error("❌ 保存下载清单失败: \(error.localizedDescription)")
        }
    }

    private func restoreFromManifest() {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return }
        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(DownloadManifest.self, from: data)
            var needsRewrite = false

            for (key, var record) in manifest.records {
                let destinationURL = absoluteURL(fromRelativePath: record.destinationRelativePath)

                switch record.status {
                case .completed:
                    guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                        needsRewrite = true
                        continue
                    }
                    completedFileURLs[key] = destinationURL
                    downloadStates[key] = .completed
                    downloadRecords[key] = record

                case .downloading, .paused:
                    if record.status == .downloading {
                        record.status = .paused
                        needsRewrite = true
                    }
                    if let resumePath = record.resumeDataRelativePath {
                        let resumeURL = absoluteURL(fromRelativePath: resumePath)
                        if !FileManager.default.fileExists(atPath: resumeURL.path) {
                            record.resumeDataRelativePath = nil
                            record.progress = 0
                            needsRewrite = true
                        }
                    }
                    record.progress = max(0, min(1, record.progress))
                    record.updatedAt = Date().timeIntervalSince1970
                    downloadRecords[key] = record
                    downloadStates[key] = .paused(progress: record.progress)

                case .failed:
                    record.progress = max(0, min(1, record.progress))
                    record.updatedAt = Date().timeIntervalSince1970
                    downloadRecords[key] = record
                    downloadStates[key] = .failed("上次下载失败，点击重试")
                }
            }

            if needsRewrite {
                saveManifestNow()
            }
            logger.info("📂 已恢复 \(self.downloadRecords.count) 条下载记录")
        } catch {
            logger.error("❌ 恢复下载清单失败: \(error.localizedDescription)")
        }
    }
#else
    // MARK: - macOS：兼容旧下载实现

    private func restoreFromManifest() {
        // macOS 暂不实现持久化下载恢复（本次迭代 iOS first）
    }

    private func startMacDownload(
        key: String,
        episode: EpisodeItem,
        type: DownloadType,
        remoteURLString: String
    ) {
        let panel = NSSavePanel()
        panel.title = "选择保存位置"
        panel.message = "将「\(episode.title)」保存到："

        let safeTitle = sanitizedFileName(from: episode.title)
        switch type {
        case .mp3:
            panel.nameFieldStringValue = "\(episode.id)_\(safeTitle).mp3"
            panel.allowedContentTypes = [.mp3]
        case .mp4:
            panel.nameFieldStringValue = "\(episode.id)_\(safeTitle).mp4"
            panel.allowedContentTypes = [.mpeg4Movie]
        }

        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let response = panel.runModal()
        guard response == .OK, let saveURL = panel.url else {
            logger.info("用户取消了保存面板")
            return
        }

        downloadStates[key] = .downloading(progress: 0)
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let progressHandler: @Sendable (Double) -> Void = { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self,
                              case .downloading = self.downloadStates[key] else { return }
                        self.downloadStates[key] = .downloading(progress: progress)
                    }
                }
                try await self.directDownloadService.download(
                    urlString: remoteURLString,
                    to: saveURL,
                    onProgress: progressHandler
                )
                self.downloadStates[key] = .completed
                self.completedFileURLs[key] = saveURL
                self.downloadTasks.removeValue(forKey: key)
            } catch is CancellationError {
                self.downloadStates[key] = .idle
                self.downloadTasks.removeValue(forKey: key)
                try? FileManager.default.removeItem(at: saveURL)
            } catch {
                self.downloadStates[key] = .failed(error.localizedDescription)
                self.downloadTasks.removeValue(forKey: key)
                try? FileManager.default.removeItem(at: saveURL)
            }
        }
        downloadTasks[key] = task
    }
#endif
}
