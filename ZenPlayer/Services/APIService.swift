//
//  APIService.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import Foundation

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
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userKey, forHTTPHeaderField: "userkey")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-Hans-CN;q=1, en-CN;q=0.9", forHTTPHeaderField: "Accept-Language")

        let data: Data
        do {
            let (responseData, _) = try await session.data(for: request)
            data = responseData
        } catch {
            throw APIError.networkError(error)
        }

        let response: APIResponse<T>
        do {
            response = try decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }

        guard response.code == 1 else {
            throw APIError.serverError(response.code, response.msg)
        }

        return response.data
    }
}
