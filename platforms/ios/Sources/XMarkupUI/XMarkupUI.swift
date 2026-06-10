import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// XMarkupUI 模块入口
///
/// 通过 `XMarkupUI.shared` 访问全局配置。
///
/// ```swift
/// import XMarkupUI
///
/// let textView = XMarkupTextView()
/// textView.load(document)
/// ```
public struct XMarkupUI: @unchecked Sendable {
    /// 共享实例
    public static let shared = XMarkupUI()

    /// 全局配置
    public var config: XMarkupViewConfig

    private init() {
        self.config = XMarkupViewConfig()
    }
}
