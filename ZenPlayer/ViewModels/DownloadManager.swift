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

    /// M3U8 (HLS) 下载服务
    private let m3u8DownloadService = M3U8DownloadService()

    /// MP3 直链下载服务
    private let mp3DownloadService = MP3DownloadService()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZenPlayer", category: "DownloadManager")

    private init() {}

    // MARK: - 公共接口

    /// 获取指定单集的下载状态
    func state(for episodeId: Int) -> DownloadState {
        downloadStates[episodeId] ?? .idle
    }

    /// 开始下载单集（自动识别 MP3 直链或 M3U8 视频）
    /// 弹出 NSSavePanel 让用户选择保存位置，确认后开始下载
    /// - Parameter episode: 要下载的单集
    func startDownload(episode: EpisodeItem) {
        let vodUrl = episode.vodUrl

        guard !vodUrl.isEmpty else {
            downloadStates[episode.id] = .failed("该集没有可下载的地址")
            return
        }

        // 根据 URL 后缀判断下载类型
        let isMP3 = vodUrl.lowercased().hasSuffix(".mp3")

        // 弹出保存面板（根据格式设置文件名和类型）
        let panel = NSSavePanel()
        panel.title = "选择保存位置"
        panel.message = "将「\(episode.title)」保存到："
        panel.nameFieldStringValue = isMP3 ? "\(episode.title).mp3" : "\(episode.title).ts"
        panel.allowedContentTypes = isMP3 ? [.mp3] : [.mpeg2TransportStream]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let response = panel.runModal()

        guard response == .OK, let saveURL = panel.url else {
            logger.info("用户取消了保存面板")
            return
        }

        logger.info("📂 保存路径: \(saveURL.path)  类型: \(isMP3 ? "MP3" : "M3U8")")

        // 更新状态为下载中
        downloadStates[episode.id] = .downloading(progress: 0)

        // 创建下载任务
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                // 进度回调闭包（共用）
                // 注意：仅在当前仍处于 .downloading 状态时才更新进度，
                // 避免迟到的进度回调覆盖已完成/已失败的终态（竞态条件）
                let progressHandler: @Sendable (Double) -> Void = { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self,
                              case .downloading = self.downloadStates[episode.id] else { return }
                        self.downloadStates[episode.id] = .downloading(progress: progress)
                    }
                }

                // 根据类型分派到对应的下载服务
                if isMP3 {
                    try await self.mp3DownloadService.download(
                        urlString: vodUrl,
                        to: saveURL,
                        onProgress: progressHandler
                    )
                } else {
                    try await self.m3u8DownloadService.download(
                        m3u8URLString: vodUrl,
                        to: saveURL,
                        onProgress: progressHandler
                    )
                }

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
