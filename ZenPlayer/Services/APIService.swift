//
//  APIService.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import Foundation
import os.log

/// API 错误类型
enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        case .decodingError(let error):
            return "数据解析错误：\(error.localizedDescription)"
        case .serverError(let code, let msg):
            return "服务器错误(\(code))：\(msg)"
        }
    }
}

/// 网络请求服务
final class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZenPlayer", category: "API")
    private let categoryURL = "https://api.jingzong.net/jiangyan/v3/hz_video/category1?client=ios&v=3"
    private let userKey = "52A63248312E107776792D30235C85B0"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - 一级类目

    /// 获取一级类目列表
    func fetchCategories() async throws -> CategoryData {
        return try await request(urlString: categoryURL)
    }

    // MARK: - 二级类目

    /// 获取二级类目列表
    /// - Parameter url: 由一级类目数据中 `CategoryItem.url` 提供的完整请求地址
    func fetchSeries(url: String) async throws -> SeriesData {
        return try await request(urlString: url)
    }

    // MARK: - 播放列表

    /// 获取讲集详情与播放列表
    /// - Parameter url: 由二级类目数据中 `SeriesItem.url` 提供的完整请求地址
    func fetchSpeechDetail(url: String) async throws -> SpeechDetailData {
        return try await request(urlString: url)
    }

    // MARK: - 通用请求

    private func request<T: Codable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            logger.error("❌ 无效 URL: \(urlString)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userKey, forHTTPHeaderField: "userkey")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-Hans-CN;q=1, en-CN;q=0.9", forHTTPHeaderField: "Accept-Language")

        logger.info("➡️ GET \(urlString)")
        let startTime = CFAbsoluteTimeGetCurrent()

        let data: Data
        let httpResponse: URLResponse
        do {
            let (responseData, response) = try await session.data(for: request)
            data = responseData
            httpResponse = response
        } catch {
            let elapsed = String(format: "%.0fms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            logger.error("❌ 网络错误 [\(elapsed)]: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }

        let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? -1
        let elapsed = String(format: "%.0fms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        logger.info("⬅️ \(statusCode) [\(elapsed)] \(data.count) bytes <- \(urlString)")

        let response: APIResponse<T>
        do {
            response = try decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            logger.error("❌ 解析失败: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }

        guard response.code == 1 else {
            logger.warning("⚠️ 业务错误 code=\(response.code) msg=\(response.msg)")
            throw APIError.serverError(response.code, response.msg)
        }

        return response.data
    }
}
