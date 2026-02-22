//
//  OrientationManager.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/22.
//

#if os(iOS)
import UIKit

/// 全局方向锁定管理：默认竖屏，全屏播放时允许横屏
final class OrientationManager {
    static let shared = OrientationManager()

    /// 当前允许的方向（默认仅竖屏）
    var supportedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}
}
#endif
