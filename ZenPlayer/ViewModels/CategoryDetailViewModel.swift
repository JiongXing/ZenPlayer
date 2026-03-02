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
    enum SortField: String, CaseIterable, Identifiable {
        case number
        case date

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .number: return L10n.string(.categorySortByNumber)
            case .date: return L10n.string(.categorySortByDate)
            }
        }
    }

    var seriesList: [SeriesItem] = []
    var isLoading = false
    var errorMessage: String?
    var sortField: SortField = .number {
        didSet { applySort() }
    }
    var isAscending = true {
        didSet { applySort() }
    }

    private let apiService = APIService.shared

    /// 加载二级类目数据
    /// - Parameter url: 由一级类目数据中 `CategoryItem.url` 提供的完整请求地址
    func loadSeries(url: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await apiService.fetchSeries(url: url)
            seriesList = data.rows
            applySort()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 排序

    private func applySort() {
        seriesList.sort { lhs, rhs in
            switch sortField {
            case .number:
                let leftNumber = numericValue(from: lhs.num)
                let rightNumber = numericValue(from: rhs.num)
                if leftNumber != rightNumber {
                    return isAscending ? leftNumber < rightNumber : leftNumber > rightNumber
                }
                return isAscending ? lhs.id < rhs.id : lhs.id > rhs.id
            case .date:
                let leftDate = dateSortKey(from: lhs.date)
                let rightDate = dateSortKey(from: rhs.date)
                if leftDate != rightDate {
                    return isAscending ? leftDate < rightDate : leftDate > rightDate
                }
                return isAscending ? lhs.id < rhs.id : lhs.id > rhs.id
            }
        }
    }

    /// 提取字符串中的数字用于编号排序，例如 "第12集" -> 12
    private func numericValue(from value: String) -> Int {
        let digits = value.filter(\.isNumber)
        return Int(digits) ?? Int.min
    }

    /// 解析日期排序键，兼容 "1983" / "1984.12" / "1994.6.4" / "1993.10-1985.10" 等格式
    /// 返回值越大代表越新；无法解析时回退到自然字符串比较，避免与显示值不一致
    private func dateSortKey(from dateText: String) -> DateSortKey {
        let trimmed = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return DateSortKey(year: Int.min, month: Int.min, day: Int.min, fallbackText: "")
        }

        // 区间格式取左侧起始值，如 "1993.10-1985.10" -> "1993.10"
        let primary = trimmed
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? trimmed

        let normalized = primary
            .replacingOccurrences(of: "年", with: ".")
            .replacingOccurrences(of: "月", with: ".")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = normalized
            .split(separator: ".")
            .compactMap { Int($0) }

        if let year = parts.first {
            let month = parts.count > 1 ? parts[1] : 0
            let day = parts.count > 2 ? parts[2] : 0
            return DateSortKey(year: year, month: month, day: day, fallbackText: trimmed)
        }

        return DateSortKey(year: Int.min, month: Int.min, day: Int.min, fallbackText: trimmed)
    }
}

private struct DateSortKey: Comparable {
    let year: Int
    let month: Int
    let day: Int
    let fallbackText: String

    static func < (lhs: DateSortKey, rhs: DateSortKey) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        return lhs.fallbackText.localizedStandardCompare(rhs.fallbackText) == .orderedAscending
    }
}
