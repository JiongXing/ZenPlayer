//
//  Series.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import Foundation

/// 二级类目响应数据
struct SeriesData: Codable {
    let serverUrl: String
    let updateTime: Int
    let total: Int
    let rows: [SeriesItem]
}

/// 二级类目条目（讲演专辑）
struct SeriesItem: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let cateId: String
    let num: String
    let date: String
    let author: String
    let address: String
    let total: Int
    let finish: Int
    let type: String        // "mp4" 或 "mp3"
    let typeName: String
    let coverUrl: String
    let url: String
    let pageUrl: String

    /// 是否为视频类型
    var isVideo: Bool { type == "mp4" }
}
