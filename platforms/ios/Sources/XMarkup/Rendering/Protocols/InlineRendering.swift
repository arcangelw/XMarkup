import Foundation

/// 内联渲染器协议 — 控制单个 inline 样式如何应用
///
/// 返回 `false` 表示不处理此 inline，交由管线中下一个渲染器。
/// 按注册顺序依次询问，第一个返回 true 的胜出。
public protocol InlineRendering: Sendable {
    /// 将内联样式应用到 NSMutableAttributedString
    ///
    /// - Parameters:
    ///   - inline: 待应用的内联元素
    ///   - attributed: 目标 NSMutableAttributedString
    ///   - context: 渲染上下文
    /// - Returns: true 表示已处理，false 表示跳过交由下一个渲染器
    func apply(inline: MarkupInline, to attributed: NSMutableAttributedString,
               context: RenderingContext) -> Bool
}
