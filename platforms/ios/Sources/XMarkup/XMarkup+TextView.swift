#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// UITextView / NSTextView 便利扩展
///
/// 提供 XMarkup 富文本渲染所需的 TextView 配置。
#if canImport(UIKit)
public typealias XMTextView = UITextView
#elseif canImport(AppKit)
public typealias XMTextView = NSTextView
#endif

extension XMTextView {
    /// 配置 TextView 以正确渲染 XMarkup 富文本
    ///
    /// 清空默认的 `linkTextAttributes`，让 NSAttributedString 自身的
    /// `.foregroundColor` 生效，避免链接文字被系统蓝色覆盖。
    ///
    /// 在设置 `attributedText` **之前**调用：
    /// ```swift
    /// textView.configureForXMarkup()
    /// textView.attributedText = result.makeAttributedString()
    /// ```
    public func configureForXMarkup() {
        linkTextAttributes = [:]
    }
}
