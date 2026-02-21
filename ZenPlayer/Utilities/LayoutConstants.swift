//
//  LayoutConstants.swift
//  ZenPlayer
//
//  响应式布局常量，根据平台和 Size Class 提供合适的间距值
//

import SwiftUI

/// 响应式布局常量
enum LayoutConstants {
    /// 页面水平边距：macOS 28pt，iPad 24pt，iPhone 16pt
    static func horizontalPadding(sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        #if os(macOS)
        return 28
        #else
        switch sizeClass {
        case .regular: return 24
        default: return 16
        }
        #endif
    }

    /// 页面垂直边距：macOS 24pt，iPad 20pt，iPhone 16pt
    static func verticalPadding(sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        #if os(macOS)
        return 24
        #else
        switch sizeClass {
        case .regular: return 20
        default: return 16
        }
        #endif
    }
}
