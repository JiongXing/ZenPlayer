//
//  M3U8DownloadService.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import Foundation
import os.log

// MARK: - 错误类型

/// M3U8 下载相关错误
enum M3U8DownloadError: LocalizedError {
    case invalidURL(String)
    case networkError(Error)
    case emptyPlaylist
    case parsingFailed(String)
    case fileWriteError(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "无效的 m3u8 地址：\(url)"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .emptyPlaylist:
            return "播放列表为空，未找到可下载的分片"
        case .parsingFailed(let reason):
            return "m3u8 解析失败：\(reason)"
        case .fileWriteError(let error):
            return "文件写入失败：\(error.localizedDescription)"
        case .cancelled:
            return "下载已取消"
        }
    }
}

// MARK: - M3U8 下载服务

/// M3U8 (HLS) 视频下载服务
/// 负责解析 m3u8 播放列表、并发下载 .ts 分片、合并为单个文件
final class M3U8DownloadService: Sendable {

    private let session: URLSession
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZenPlayer", category: "M3U8Download")

    /// 最大并发下载分片数
    private let maxConcurrency = 5

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - 公共接口

    /// 下载 m3u8 视频并合并为单个 .ts 文件
    /// - Parameters:
    ///   - m3u8URLString: m3u8 播放列表地址
    ///   - destinationURL: 最终保存路径（由用户通过 NSSavePanel 选择）
    ///   - onProgress: 进度回调，参数为 0.0 ~ 1.0
    func download(
        m3u8URLString: String,
        to destinationURL: URL,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws {
        logger.info("🔽 开始下载 m3u8: \(m3u8URLString)")

        // 1. 解析 m3u8，获取所有 .ts 分片 URL
        let segmentURLs = try await parseM3U8(urlString: m3u8URLString)
        logger.info("📋 解析到 \(segmentURLs.count) 个分片")

        guard !segmentURLs.isEmpty else {
            throw M3U8DownloadError.emptyPlaylist
        }

        // 2. 创建临时工作目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZenPlayer_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 3. 并发下载所有分片
        let segmentFiles = try await downloadSegments(
            urls: segmentURLs,
            tempDir: tempDir,
            onProgress: onProgress
        )

        // 4. 检查取消状态
        try Task.checkCancellation()

        // 5. 合并分片为单个文件
        logger.info("🔗 正在合并 \(segmentFiles.count) 个分片...")
        try mergeSegments(segmentFiles, to: destinationURL)

        logger.info("✅ 下载完成: \(destinationURL.path)")
    }

    // MARK: - M3U8 解析

    /// 解析 m3u8 播放列表，返回所有 .ts 分片的绝对 URL
    private func parseM3U8(urlString: String) async throws -> [URL] {
        guard let url = URL(string: urlString) else {
            throw M3U8DownloadError.invalidURL(urlString)
        }

        let content = try await fetchText(url: url)

        // 检查是否为有效的 m3u8 文件
        guard content.contains("#EXTM3U") else {
            throw M3U8DownloadError.parsingFailed("不是有效的 m3u8 文件")
        }

        // 检查是否为 Master Playlist（多码率）
        if content.contains("#EXT-X-STREAM-INF") {
            logger.info("📂 检测到 Master Playlist，选择最高码率...")
            let bestVariantURL = try parseMasterPlaylist(content: content, baseURL: url)
            // 递归解析子播放列表
            return try await parseM3U8(urlString: bestVariantURL.absoluteString)
        }

        // Media Playlist：提取 .ts 分片 URL
        return parseMediaPlaylist(content: content, baseURL: url)
    }

    /// 解析 Master Playlist，返回最高码率的子播放列表 URL
    private func parseMasterPlaylist(content: String, baseURL: URL) throws -> URL {
        let lines = content.components(separatedBy: .newlines)
        var bestBandwidth = 0
        var bestURL: URL?
        var nextIsBest = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("#EXT-X-STREAM-INF") {
                // 提取 BANDWIDTH 值
                let bandwidth = extractBandwidth(from: trimmed)
                if bandwidth > bestBandwidth {
                    bestBandwidth = bandwidth
                    nextIsBest = true
                } else {
                    nextIsBest = false
                }
            } else if nextIsBest && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                bestURL = resolveURL(trimmed, relativeTo: baseURL)
                nextIsBest = false
            }
        }

        guard let url = bestURL else {
            throw M3U8DownloadError.parsingFailed("Master Playlist 中未找到有效的子播放列表")
        }

        logger.info("🎯 选择码率: \(bestBandwidth) bps -> \(url.absoluteString)")
        return url
    }

    /// 解析 Media Playlist，提取所有 .ts 分片 URL
    private func parseMediaPlaylist(content: String, baseURL: URL) -> [URL] {
        let lines = content.components(separatedBy: .newlines)
        var segmentURLs: [URL] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 跳过空行和注释行
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            // 非注释行即为分片路径
            if let url = resolveURL(trimmed, relativeTo: baseURL) {
                segmentURLs.append(url)
            }
        }

        return segmentURLs
    }

    // MARK: - 分片下载

    /// 并发下载所有 .ts 分片到临时目录
    /// - Returns: 按顺序排列的本地分片文件 URL
    private func downloadSegments(
        urls: [URL],
        tempDir: URL,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        let totalCount = urls.count
        // 使用 actor 安全地追踪进度和结果
        let tracker = DownloadTracker(totalCount: totalCount, onProgress: onProgress)

        // 预先为每个分片分配本地文件路径（保持顺序）
        let localFiles = urls.enumerated().map { index, _ in
            tempDir.appendingPathComponent(String(format: "segment_%05d.ts", index))
        }

        // 使用 TaskGroup 并发下载，通过信号量控制并发数
        try await withThrowingTaskGroup(of: Void.self) { group in
            // 信号量模拟：按批次提交任务
            for batch in stride(from: 0, to: urls.count, by: maxConcurrency) {
                let end = min(batch + maxConcurrency, urls.count)

                for i in batch..<end {
                    group.addTask {
                        try Task.checkCancellation()
                        try await self.downloadSegment(from: urls[i], to: localFiles[i])
                        await tracker.markCompleted()
                    }
                }

                // 等待当前批次全部完成
                try await group.waitForAll()
            }
        }

        return localFiles
    }

    /// 下载单个 .ts 分片到本地文件
    private func downloadSegment(from remoteURL: URL, to localURL: URL) async throws {
        let (tempFileURL, response) = try await session.download(for: URLRequest(url: remoteURL))

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw M3U8DownloadError.networkError(
                URLError(.badServerResponse, userInfo: [NSURLErrorFailingURLErrorKey: remoteURL])
            )
        }

        // 移动到目标路径
        do {
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.removeItem(at: localURL)
            }
            try FileManager.default.moveItem(at: tempFileURL, to: localURL)
        } catch {
            throw M3U8DownloadError.fileWriteError(error)
        }
    }

    // MARK: - 合并分片

    /// 将多个 .ts 分片文件按顺序合并为一个文件
    private func mergeSegments(_ segmentFiles: [URL], to destinationURL: URL) throws {
        // 如果目标文件已存在则删除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        // 创建目标文件
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)

        guard let fileHandle = try? FileHandle(forWritingTo: destinationURL) else {
            throw M3U8DownloadError.fileWriteError(
                NSError(domain: "M3U8Download", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "无法创建输出文件"])
            )
        }

        defer { try? fileHandle.close() }

        // 逐个追加分片数据
        for segmentURL in segmentFiles {
            let data = try Data(contentsOf: segmentURL)
            fileHandle.write(data)
        }
    }

    // MARK: - 辅助方法

    /// 下载文本内容
    private func fetchText(url: URL) async throws -> String {
        let (data, response) = try await session.data(for: URLRequest(url: url))

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw M3U8DownloadError.networkError(
                URLError(.badServerResponse, userInfo: [NSURLErrorFailingURLErrorKey: url])
            )
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw M3U8DownloadError.parsingFailed("m3u8 内容不是有效的 UTF-8 文本")
        }

        return text
    }

    /// 从 #EXT-X-STREAM-INF 行提取 BANDWIDTH 值
    private func extractBandwidth(from line: String) -> Int {
        // 匹配 BANDWIDTH=数字
        guard let range = line.range(of: "BANDWIDTH=\\d+", options: .regularExpression) else {
            return 0
        }
        let value = line[range].replacingOccurrences(of: "BANDWIDTH=", with: "")
        return Int(value) ?? 0
    }

    /// 将可能的相对路径解析为绝对 URL
    private func resolveURL(_ path: String, relativeTo baseURL: URL) -> URL? {
        // 已经是绝对 URL
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        // 相对路径：基于 m3u8 文件所在目录拼接
        let baseDir = baseURL.deletingLastPathComponent()
        return baseDir.appendingPathComponent(path)
    }
}

// MARK: - 下载进度追踪 Actor

/// 线程安全的下载进度追踪器
private actor DownloadTracker {
    private let totalCount: Int
    private var completedCount = 0
    private let onProgress: @Sendable (Double) -> Void

    init(totalCount: Int, onProgress: @Sendable @escaping (Double) -> Void) {
        self.totalCount = totalCount
        self.onProgress = onProgress
    }

    /// 标记一个分片已完成，更新进度
    func markCompleted() {
        completedCount += 1
        let progress = Double(completedCount) / Double(totalCount)
        onProgress(progress)
    }
}
