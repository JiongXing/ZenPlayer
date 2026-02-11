//
//  SeriesDetailViewModel.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

/// 讲集详情 ViewModel，负责加载播放列表数据
@MainActor
@Observable
final class SeriesDetailViewModel {
    var speechDetail: SpeechDetailData?
    var episodes: [EpisodeItem] = []
    var isLoading = false
    var errorMessage: String?

    private let apiService = APIService.shared

    /// 加载播放列表
    /// - Parameter url: 由二级类目数据中 `SeriesItem.url` 提供的完整请求地址
    func loadSpeechDetail(url: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await apiService.fetchSpeechDetail(url: url)
            speechDetail = data
            episodes = data.rows
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
