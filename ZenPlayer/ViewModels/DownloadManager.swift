//
//  DownloadManager.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

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
enum DownloadType: String {
    case mp3
    case mp4
}

// MARK: - 下载状态

/// 单集下载状态
enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)  // 0.0 ~ 1.0
    case completed
    case failed(String)

    /// 用于 Equatable 比较
    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.downloading(let a), .downloading(let b)):
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

// MARK: - 下载管理器

/// 全局下载管理器，管理所有单集的下载任务与状态
@MainActor
@Observable
final class DownloadManager {

    /// 单例
    static let shared = DownloadManager()

    // MARK: - 可观察状态

    /// 每个单集的下载状态（key: "\(episodeId)_mp3" 或 "\(episodeId)_mp4"）
    var downloadStates: [String: DownloadState] = [:]

    /// 已完成下载的本地文件 URL（key 同 downloadStates），用于 iOS 分享
    var completedFileURLs: [String: URL] = [:]

    // MARK: - 私有属性

    /// 正在执行的下载任务（key 同 downloadStates）
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    /// 直链下载服务（用于 mp3 和 mp4）
    private let directDownloadService = MP3DownloadService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZenPlayer", category: "DownloadManager")

    private init() {}

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

    /// 开始下载单集的音频或视频
    /// 弹出 NSSavePanel 让用户选择保存位置，确认后开始下载
    /// - Parameters:
    ///   - episode: 要下载的单集
    ///   - type: 下载类型（.mp3 音频 / .mp4 视频）
    ///   - serverUrl: 服务器根地址，用于拼接 mp4 的相对路径
    func startDownload(episode: EpisodeItem, type: DownloadType, serverUrl: String) {
        let key = Self.downloadKey(episodeId: episode.id, type: type)

        // 构建完整下载 URL
        let downloadUrlString: String
        switch type {
        case .mp3:
            guard let mp3Url = episode.mp3Url, !mp3Url.isEmpty else {
                downloadStates[key] = .failed("该集没有可下载的音频地址")
                return
            }
            downloadUrlString = mp3Url
        case .mp4:
            guard !episode.mp4Url.isEmpty else {
                downloadStates[key] = .failed("该集没有可下载的视频地址")
                return
            }
            // mp4Url 是相对路径，需要拼接 serverUrl
            downloadUrlString = serverUrl + episode.mp4Url
        }

        // 获取保存路径
        let saveURL: URL
#if os(macOS)
        // macOS：弹出保存面板让用户选择路径
        let panel = NSSavePanel()
        panel.title = "选择保存位置"
        panel.message = "将「\(episode.title)」保存到："

        switch type {
        case .mp3:
            panel.nameFieldStringValue = "\(episode.title).mp3"
            panel.allowedContentTypes = [.mp3]
        case .mp4:
            panel.nameFieldStringValue = "\(episode.title).mp4"
            panel.allowedContentTypes = [.mpeg4Movie]
        }

        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let response = panel.runModal()

        guard response == .OK, let panelURL = panel.url else {
            logger.info("用户取消了保存面板")
            return
        }
        saveURL = panelURL
#else
        // iOS：保存到 Documents 目录（在「文件」App 中可见）
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "\(episode.title).\(type.rawValue)"
        saveURL = documentsDir.appendingPathComponent(fileName)
#endif

        logger.info("📂 保存路径: \(saveURL.path)  类型: \(type.rawValue)")

        // 更新状态为下载中
        downloadStates[key] = .downloading(progress: 0)

        // 创建下载任务
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                // 进度回调闭包
                // 注意：仅在当前仍处于 .downloading 状态时才更新进度，
                // 避免迟到的进度回调覆盖已完成/已失败的终态（竞态条件）
                let progressHandler: @Sendable (Double) -> Void = { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self,
                              case .downloading = self.downloadStates[key] else { return }
                        self.downloadStates[key] = .downloading(progress: progress)
                    }
                }

                // mp3 和 mp4 均使用直链下载服务
                try await self.directDownloadService.download(
                    urlString: downloadUrlString,
                    to: saveURL,
                    onProgress: progressHandler
                )

                // 下载完成
                self.downloadStates[key] = .completed
                self.completedFileURLs[key] = saveURL
                self.downloadTasks.removeValue(forKey: key)
                self.logger.info("✅ 下载完成: \(episode.title) (\(type.rawValue))")

            } catch is CancellationError {
                self.downloadStates[key] = .idle
                self.downloadTasks.removeValue(forKey: key)
                // 尝试清理不完整的文件
                try? FileManager.default.removeItem(at: saveURL)
                self.logger.info("🛑 下载已取消: \(episode.title) (\(type.rawValue))")

            } catch {
                self.downloadStates[key] = .failed(error.localizedDescription)
                self.downloadTasks.removeValue(forKey: key)
                // 清理不完整的文件
                try? FileManager.default.removeItem(at: saveURL)
                self.logger.error("❌ 下载失败: \(episode.title) (\(type.rawValue)) - \(error.localizedDescription)")
            }
        }

        downloadTasks[key] = task
    }

    /// 获取已完成下载的本地文件 URL
    func completedFileURL(for episodeId: Int, type: DownloadType) -> URL? {
        let key = Self.downloadKey(episodeId: episodeId, type: type)
        return completedFileURLs[key]
    }

    /// 取消指定单集某种类型的下载
    /// - Parameters:
    ///   - episodeId: 单集 ID
    ///   - type: 下载类型
    func cancelDownload(episodeId: Int, type: DownloadType) {
        let key = Self.downloadKey(episodeId: episodeId, type: type)
        downloadTasks[key]?.cancel()
        downloadTasks.removeValue(forKey: key)
        downloadStates[key] = .idle
        logger.info("🛑 取消下载 episodeId=\(episodeId) type=\(type.rawValue)")
    }
}
