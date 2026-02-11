//
//  HomeViewModel.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

/// 首页 ViewModel，负责加载一级类目数据
@MainActor
@Observable
final class HomeViewModel {
    var categories: [CategoryItem] = []
    var headerTitle: String = ""
    var headerSubtitle: String = ""
    var isLoading = false
    var errorMessage: String?

    private let apiService = APIService.shared

    /// 加载一级类目数据
    func loadCategories() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await apiService.fetchCategories()
            categories = data.rows
            headerTitle = data.title
            headerSubtitle = data.subtitle
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
