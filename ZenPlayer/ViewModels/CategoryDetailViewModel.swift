//
//  CategoryDetailViewModel.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

/// 二级类目 ViewModel，负责加载指定一级类目下的讲演列表
@MainActor
@Observable
final class CategoryDetailViewModel {
    var seriesList: [SeriesItem] = []
    var isLoading = false
    var errorMessage: String?

    private let apiService = APIService.shared

    /// 加载二级类目数据
    /// - Parameter url: 由一级类目数据中 `CategoryItem.url` 提供的完整请求地址
    func loadSeries(url: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await apiService.fetchSeries(url: url)
            seriesList = data.rows
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
