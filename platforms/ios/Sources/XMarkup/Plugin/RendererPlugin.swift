import Foundation

/// 便利组合协议 — 同时遵循四个阶段协议，所有方法有默认空实现
///
/// 用户只需覆写关心的方法，实现自定义渲染逻辑：
///
/// ```swift
/// struct MyPlugin: RendererPlugin {
///     func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? {
///         // 只处理 blockquote，其余交由默认渲染器
///         guard case .blockquote = block.kind else { return nil }
///         // 自定义渲染逻辑...
///     }
/// }
/// ```
public protocol RendererPlugin: BlockRendering, InlineRendering,
                                 AttributedStringProcessing, NSAttributedStringProcessing {}

extension RendererPlugin {
    /// 默认不处理任何 block
    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? { nil }

    /// 默认不处理任何 inline
    public func apply(inline: MarkupInline, to attributed: inout AttributedString,
                      blockText: String, context: RenderingContext) -> Bool { false }

    /// 默认原样返回
    public func process(_ attributed: AttributedString, context: RenderingContext) -> AttributedString { attributed }

    /// 默认不做任何增强
    public func enhance(_ nsAttr: NSMutableAttributedString, context: RenderingContext) {}
}
