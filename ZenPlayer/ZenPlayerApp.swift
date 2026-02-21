//
//  ZenPlayerApp.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI
import Atlantis
import Kingfisher

@main
struct ZenPlayerApp: App {

    init() {
        #if DEBUG
        Atlantis.start()
        #endif
        configureKingfisher()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .frame(minWidth: 500, minHeight: 500)
#endif
        }
#if os(macOS)
        .defaultSize(width: 700, height: 700)
#endif
    }

    // MARK: - Kingfisher 全局配置

    private func configureKingfisher() {
        let downloader = ImageDownloader.default
        // 请求超时时间（默认 15 秒，调整为 30 秒）
        downloader.downloadTimeout = 30

        let cache = ImageCache.default
        // 内存缓存最大容量：300 MB
        cache.memoryStorage.config.totalCostLimit = 300 * 1024 * 1024
        // 磁盘缓存最大容量：1 GB
        cache.diskStorage.config.sizeLimit = 1024 * 1024 * 1024
        // 磁盘缓存过期时间：100 天
        cache.diskStorage.config.expiration = .days(100)
    }
}
