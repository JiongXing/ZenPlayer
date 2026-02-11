//
//  APIResponse.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import Foundation

/// 通用 API 响应结构
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let msg: String
    let data: T
}
