//
//  Category.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import Foundation

/// 一级类目响应数据
struct CategoryData: Codable {
    let serverUrl: String
    let updateTime: Int
    let total: Int
    let title: String
    let subtitle: String
    let rows: [CategoryItem]
}

/// 一级类目条目
struct CategoryItem: Codable, Identifiable, Hashable {
    let title: String
    let cateId: Int
    let url: String
    let coverUrl: String
    let desc: String

    var id: Int { cateId }
}
