import Foundation

/// 便利组合协议 — 同时遵循三个阶段协议（BlockRendering + InlineRendering + NSAttributedStringProcessing），所有方法有默认空实现
///
/// 用户只需覆写关心的方法，实现自定义渲染逻辑：
///
/// ```swift
/// struct MyPlugin: RendererPlugin {
///     func render(block: MarkupBlock, context: inout RenderingContext) -> NSMutableAttributedString? {
///         // 只处理 blockquote，其余交由默认渲染器
///         guard case .blockquote = block.kind else { return nil }
///         // 自定义渲染逻辑...
///     }
/// }
/// ```
public protocol RendererPlugin: BlockRendering, InlineRendering,
                                 NSAttributedStringProcessing {}

extension RendererPlugin {
    /// 默认不处理任何 block
    public func render(block: MarkupBlock, context: inout RenderingContext) -> NSMutableAttributedString? { nil }

    /// 默认不处理任何 inline
    public func apply(inline: MarkupInline, to attributed: NSMutableAttributedString,
                      context: RenderingContext) -> Bool { false }

    /// 默认不做任何增强
    public func enhance(_ nsAttr: NSMutableAttributedString, context: RenderingContext) {}
}
