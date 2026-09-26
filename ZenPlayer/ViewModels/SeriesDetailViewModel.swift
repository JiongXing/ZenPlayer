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
    private(set) var queueSnapshot: QueueSnapshot?
    var isLoading = false
    var errorMessage: String?

    private let apiService = APIService.shared

    /// 加载播放列表
    /// - Parameter url: 由二级类目数据中 `SeriesItem.url` 提供的完整请求地址
    func loadSpeechDetail(url: String, series: SeriesItem) async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await apiService.fetchSpeechDetail(url: url)
            speechDetail = data
            episodes = data.rows
            queueSnapshot = QueueSnapshot(seriesID: series.id, title: series.title, detailURL: series.url,
                                          serverURL: data.serverUrl, episodes: data.rows,
                                          isComplete: data.totalCount > 0 && data.rows.count == data.totalCount)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
