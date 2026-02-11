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
    /// - Parameter cateId: 一级类目 ID
    func loadSeries(cateId: Int) async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await apiService.fetchSeries(cateId: cateId)
            seriesList = data.rows
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
