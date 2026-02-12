//
//  DownloadManager.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import os.log

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

    /// 每个单集的下载状态（key: episode.id）
    var downloadStates: [Int: DownloadState] = [:]

    // MARK: - 私有属性

    /// 正在执行的下载任务（key: episode.id）
    private var downloadTasks: [Int: Task<Void, Never>] = [:]

    /// 下载服务
    private let downloadService = M3U8DownloadService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZenPlayer", category: "DownloadManager")

    private init() {}

    // MARK: - 公共接口

    /// 获取指定单集的下载状态
    func state(for episodeId: Int) -> DownloadState {
        downloadStates[episodeId] ?? .idle
    }

    /// 开始下载单集视频
    /// 弹出 NSSavePanel 让用户选择保存位置，确认后开始下载
    /// - Parameter episode: 要下载的单集
    func startDownload(episode: EpisodeItem) {
        let vodUrl = episode.vodUrl

        guard !vodUrl.isEmpty else {
            downloadStates[episode.id] = .failed("该集没有可下载的视频地址")
            return
        }

        // 弹出保存面板
        let panel = NSSavePanel()
        panel.title = "选择保存位置"
        panel.message = "将「\(episode.title)」保存到："
        panel.nameFieldStringValue = "\(episode.title).ts"
        panel.allowedContentTypes = [.mpeg2TransportStream]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let response = panel.runModal()

        guard response == .OK, let saveURL = panel.url else {
            logger.info("用户取消了保存面板")
            return
        }

        logger.info("📂 保存路径: \(saveURL.path)")

        // 更新状态为下载中
        downloadStates[episode.id] = .downloading(progress: 0)

        // 创建下载任务
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try await self.downloadService.download(
                    m3u8URLString: vodUrl,
                    to: saveURL,
                    onProgress: { [weak self] progress in
                        Task { @MainActor [weak self] in
                            self?.downloadStates[episode.id] = .downloading(progress: progress)
                        }
                    }
                )

                // 下载完成
                self.downloadStates[episode.id] = .completed
                self.downloadTasks.removeValue(forKey: episode.id)
                self.logger.info("✅ 下载完成: \(episode.title)")

            } catch is CancellationError {
                self.downloadStates[episode.id] = .idle
                self.downloadTasks.removeValue(forKey: episode.id)
                // 尝试清理不完整的文件
                try? FileManager.default.removeItem(at: saveURL)
                self.logger.info("🛑 下载已取消: \(episode.title)")

            } catch {
                self.downloadStates[episode.id] = .failed(error.localizedDescription)
                self.downloadTasks.removeValue(forKey: episode.id)
                // 清理不完整的文件
                try? FileManager.default.removeItem(at: saveURL)
                self.logger.error("❌ 下载失败: \(episode.title) - \(error.localizedDescription)")
            }
        }

        downloadTasks[episode.id] = task
    }

    /// 取消指定单集的下载
    /// - Parameter episodeId: 单集 ID
    func cancelDownload(episodeId: Int) {
        downloadTasks[episodeId]?.cancel()
        downloadTasks.removeValue(forKey: episodeId)
        downloadStates[episodeId] = .idle
        logger.info("🛑 取消下载 episodeId=\(episodeId)")
    }
}
