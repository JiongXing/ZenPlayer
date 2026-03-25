//
//  ZenPlayerApp.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI
import Kingfisher

#if os(iOS)
/// AppDelegate：通过 OrientationManager 控制全局方向锁定
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationManager.shared.supportedOrientations
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DownloadManager.shared.setBackgroundSessionCompletionHandler(
            identifier: identifier,
            completionHandler: completionHandler
        )
    }
}
#endif

@main
struct ZenPlayerApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    init() {
        configureKingfisher()
        configureNavigationBarStyle()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(iOS)
                .tint(.secondary)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1024, height: 768)
        .windowResizability(.automatic)
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

    // MARK: - NavigationBar 全局样式

    private func configureNavigationBarStyle() {
        #if os(iOS)
        // 返回按钮使用稍浅层级，避免视觉上压过导航标题
        UINavigationBar.appearance().tintColor = .secondaryLabel
        #endif
    }
}
