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
    private let baseURL = "https://api.jingzong.net/jiangyan/v3/hz_video"
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
        let urlString = "\(baseURL)/category1?client=ios&v=3"
        return try await request(urlString: urlString)
    }

    // MARK: - 二级类目

    /// 获取二级类目列表
    /// - Parameter cateId: 一级类目 ID
    func fetchSeries(cateId: Int) async throws -> SeriesData {
        let urlString = "\(baseURL)/category2?cate_id=\(cateId)&client=ios&v=3"
        return try await request(urlString: urlString)
    }

    // MARK: - 播放列表

    /// 获取讲集详情与播放列表
    /// - Parameters:
    ///   - num: 专辑编号，如 "13-009"
    ///   - type: 媒体类型，"mp4" 或 "mp3"
    func fetchSpeechDetail(num: String, type: String) async throws -> SpeechDetailData {
        let urlString = "\(baseURL)/infolist?client=ios&num=\(num)&type=\(type)&v=3"
        return try await request(urlString: urlString)
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
