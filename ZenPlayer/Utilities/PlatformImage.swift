//
//  PlatformImage.swift
//  ZenPlayer
//
//  跨平台图片工具，封装 macOS / iOS 的 SF Symbol 创建差异
//

import Kingfisher

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 跨平台图片工具
enum PlatformImage {
    /// 根据 SF Symbol 名称创建平台原生图片
    static func systemImage(_ systemName: String) -> KFCrossPlatformImage {
        #if os(macOS)
        NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage()
        #else
        UIImage(systemName: systemName) ?? UIImage()
        #endif
    }
}
