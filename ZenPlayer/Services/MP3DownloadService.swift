//
//  MP3DownloadService.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/12.
//

import Foundation
import os.log

// MARK: - 错误类型

/// MP3 下载相关错误
enum MP3DownloadError: LocalizedError {
    case invalidURL(String)
    case networkError(Error)
    case fileWriteError(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "无效的下载地址：\(url)"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .fileWriteError(let error):
            return "文件写入失败：\(error.localizedDescription)"
        case .cancelled:
            return "下载已取消"
        }
    }
}

// MARK: - MP3 下载服务

/// MP3 直链文件下载服务
/// 使用 URLSession 的 bytes 流式下载，支持实时进度回调
final class MP3DownloadService: Sendable {

    private let session: URLSession
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZenPlayer", category: "MP3Download")

    /// 进度回调的最小间隔字节数（每 64KB 回调一次，避免过于频繁）
    private let progressReportInterval: Int64 = 64 * 1024

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600  // MP3 文件可能较大，给予充足超时
        self.session = URLSession(configuration: config)
    }

    // MARK: - 公共接口

    /// 下载 MP3 文件到指定路径
    /// - Parameters:
    ///   - urlString: MP3 文件的完整 URL
    ///   - destinationURL: 最终保存路径（由用户通过 NSSavePanel 选择）
    ///   - onProgress: 进度回调，参数为 0.0 ~ 1.0
    func download(
        urlString: String,
        to destinationURL: URL,
        onProgress: @Sendable @escaping (Double) -> Void
    ) async throws {
        logger.info("🔽 开始下载 MP3: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw MP3DownloadError.invalidURL(urlString)
        }

        let request = URLRequest(url: url)

        // 使用 bytes(for:) 流式下载，以便实时报告进度
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw MP3DownloadError.networkError(error)
        }

        // 校验 HTTP 状态码
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MP3DownloadError.networkError(
                URLError(.badServerResponse, userInfo: [NSURLErrorFailingURLErrorKey: url])
            )
        }

        // 从响应头获取文件总大小，用于计算进度
        let expectedLength = httpResponse.expectedContentLength  // -1 表示未知

        // 如果目标文件已存在则删除
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        // 创建目标文件并打开写入句柄
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: destinationURL) else {
            throw MP3DownloadError.fileWriteError(
                NSError(domain: "MP3Download", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "无法创建输出文件"])
            )
        }

        defer { try? fileHandle.close() }

        // 流式读取并写入文件
        var receivedBytes: Int64 = 0
        var lastReportedBytes: Int64 = 0
        // 使用缓冲区减少磁盘写入次数
        let bufferSize = 256 * 1024  // 256KB
        var buffer = Data()
        buffer.reserveCapacity(bufferSize)

        do {
            for try await byte in bytes {
                // 检查取消状态
                try Task.checkCancellation()

                buffer.append(byte)
                receivedBytes += 1

                // 缓冲区满时写入磁盘
                if buffer.count >= bufferSize {
                    fileHandle.write(buffer)
                    buffer.removeAll(keepingCapacity: true)
                }

                // 按间隔报告进度
                if expectedLength > 0, receivedBytes - lastReportedBytes >= progressReportInterval {
                    lastReportedBytes = receivedBytes
                    let progress = Double(receivedBytes) / Double(expectedLength)
                    onProgress(min(progress, 1.0))
                }
            }

            // 写入剩余的缓冲数据
            if !buffer.isEmpty {
                fileHandle.write(buffer)
            }
        } catch is CancellationError {
            // 清理不完整文件由调用方（DownloadManager）处理
            throw MP3DownloadError.cancelled
        } catch {
            throw MP3DownloadError.networkError(error)
        }

        // 最终进度设为 100%
        onProgress(1.0)

        logger.info("✅ MP3 下载完成: \(destinationURL.path)，共 \(receivedBytes) 字节")
    }
}
