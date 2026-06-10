import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// XMarkupUI 模块入口
///
/// 通过 `XMarkupUI.shared` 访问全局配置。
///
/// ```swift
/// XMarkupUI.shared.config.blockquoteBorderWidth = 4
/// XMarkupUI.shared.config.enableMediaAutoLoad = false
/// ```
public final class XMarkupUI: @unchecked Sendable {
    /// 共享实例
    public static let shared = XMarkupUI()

    /// 全局配置（class 实例允许通过 .shared.config 直接修改属性）
    public var config: XMarkupViewConfig

    private init() {
        self.config = XMarkupViewConfig()
    }
}
