import Foundation

/// NSAttributedString 增强器 — 在桥接为 NSAttributedString 后追加平台视觉属性
///
/// 用于添加平台特定的视觉属性，如 NSTextBlock（macOS blockquote/pre）、
/// 自定义 NSTextAttachment、动态颜色等。
/// 按注册顺序依次执行。
public protocol NSAttributedStringProcessing: Sendable {
    /// 增强 NSMutableAttributedString
    ///
    /// - Parameters:
    ///   - nsAttr: 已桥接为 NSAttributedString 的可变副本
    ///   - context: 渲染上下文
    func enhance(_ nsAttr: NSMutableAttributedString, context: RenderingContext)
}
