import Foundation

/// 块级渲染器协议 — 控制单个 block 如何渲染为 AttributedString
///
/// 返回 `nil` 表示不处理此 block，交由管线中下一个渲染器。
/// 按注册顺序依次询问，第一个返回非 nil 的胜出。
public protocol BlockRendering: Sendable {
    /// 渲染单个块级元素
    ///
    /// - Parameters:
    ///   - block: 待渲染的块级元素
    ///   - context: 渲染上下文（含主题、位置信息、共享状态）
    /// - Returns: 渲染后的 AttributedString，或 nil 表示不处理
    func render(block: MarkupBlock, context: RenderingContext) -> AttributedString?
}
