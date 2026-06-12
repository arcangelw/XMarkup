import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import XMarkup

/// XMarkupUI 全局配置
///
/// 所有 XMarkupUI 视图读取此配置决定渲染行为。
/// 通过 `XMarkupUI.shared.config` 访问。
///
/// ```swift
/// XMarkupUI.shared.config.blockquoteBorderWidth = 4
/// XMarkupUI.shared.config.enableMediaAutoLoad = false
/// ```
public struct XMarkupViewConfig: Sendable {
    // MARK: - hr 分隔线

    /// hr NSTextAttachment 最小宽度（pt）
    public var hrMinWidth: CGFloat = 100

    // MARK: - blockquote 左边框

    /// 左侧竖线宽度（pt）
    public var blockquoteBorderWidth: CGFloat = 3
    /// 左侧竖线颜色
    public var blockquoteBorderColor: XMColor = {
        #if canImport(UIKit)
        return .systemGray
        #elseif canImport(AppKit)
        return .systemGray
        #endif
    }()
    /// 竖线相对缩进后文本起点的水平偏移（负值向左）
    public var blockquoteBorderOffset: CGFloat = -6

    // MARK: - 异步媒体加载

    /// 加载文档后自动运行 AsyncMediaLoader 下载附件图片
    public var enableMediaAutoLoad: Bool = true

    public init() {}
}
