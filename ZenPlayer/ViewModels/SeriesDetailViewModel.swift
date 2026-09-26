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
    private(set) var episodes: [EpisodeItem] = []
    private(set) var visibleEpisodes: [EpisodeItem] = []
    var searchQuery = "" { didSet { applySearch() } }
    var jumpInput = ""
    private(set) var jumpCandidates: [EpisodeItem] = []
    private(set) var jumpError: L10nKey?
    private(set) var location: EpisodeLocation?
    var isSearchLimited: Bool { queueSnapshot?.isComplete != true }
    private var searchIndex = CatalogSearchIndex()
    private var loadRequest = UUID()
    private var episodesByID: [Int: EpisodeItem] = [:]
    private(set) var queueSnapshot: QueueSnapshot?
    var isLoading = false
    var errorMessage: String?

    private let loader: (String) async throws -> SpeechDetailData

    init(loader: @escaping (String) async throws -> SpeechDetailData = { try await APIService.shared.fetchSpeechDetail(url: $0) }) {
        self.loader = loader
    }

    func submitJump() {
        jumpCandidates = []
        jumpError = nil
        guard let number = EpisodeNumberParser.parse(jumpInput) else { jumpError = .catalogJumpInvalid; return }
        let matches = EpisodeNumberParser.matches(number, episodes: episodes)
        if matches.isEmpty { jumpError = .catalogJumpNotFound }
        else if matches.count == 1 { locateEpisode(id: matches[0].id) }
        else { jumpCandidates = matches }
    }

    func locateEpisode(id: Int) {
        guard episodesByID[id] != nil else { jumpError = .catalogJumpNotFound; return }
        searchQuery = ""
        jumpCandidates = []
        jumpError = nil
        location = EpisodeLocation(episodeID: id)
    }

    private func applySearch() {
        visibleEpisodes = searchIndex.matchingIDs(query: searchQuery).compactMap { episodesByID[$0] }
    }

    /// 加载播放列表
    /// - Parameter url: 由二级类目数据中 `SeriesItem.url` 提供的完整请求地址
    func loadSpeechDetail(url: String, series: SeriesDestination) async {
        let request = UUID()
        loadRequest = request
        isLoading = true
        defer { if loadRequest == request { isLoading = false } }
        errorMessage = nil

        do {
            let data = try await loader(url)
            guard !Task.isCancelled, loadRequest == request else { return }
            speechDetail = data
            episodes = data.rows
            episodesByID = Dictionary(data.rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            searchIndex = CatalogSearchIndex(episodes: data.rows)
            applySearch()
            queueSnapshot = QueueSnapshot(seriesID: series.id, title: series.title, detailURL: series.url,
                                          serverURL: data.serverUrl, episodes: data.rows,
                                          isComplete: data.totalCount > 0 && data.rows.count == data.totalCount)
        } catch {
            if !Task.isCancelled, loadRequest == request { errorMessage = CatalogLoadFailure.message(for: error) }
        }
    }
}
