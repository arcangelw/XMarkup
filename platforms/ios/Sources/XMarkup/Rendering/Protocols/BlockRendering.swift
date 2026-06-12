import Foundation

/// 块级渲染器协议 — 控制单个 block 如何渲染为 NSMutableAttributedString
///
/// 返回 `nil` 表示不处理此 block，交由管线中下一个渲染器。
/// 按注册顺序依次询问，第一个返回非 nil 的胜出。
///
/// `context` 为 `inout`，渲染器可通过它向管线回传信息：
/// - `context.textPrefixLength`：渲染器在文本前插入的标记前缀长度
///   （如有序列表 "1.\t" = 3），管线据此自动偏移 inline 样式范围。
public protocol BlockRendering: Sendable {
    /// 渲染单个块级元素
    ///
    /// - Parameters:
    ///   - block: 待渲染的块级元素
    ///   - context: 渲染上下文（含主题、位置信息、共享状态），`inout` 允许回传前缀长度等元信息
    /// - Returns: 渲染后的 NSMutableAttributedString，或 nil 表示不处理
    func render(block: MarkupBlock, context: inout RenderingContext) -> NSMutableAttributedString?
}
