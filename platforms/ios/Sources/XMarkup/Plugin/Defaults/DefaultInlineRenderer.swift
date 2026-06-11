import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认内联渲染器 — 处理所有 InlineKind 的样式应用
///
/// Phase 5 将从 typed theme（context.theme.codeInline 等）读取配置，
/// 当前复用 Rendering/InlineRenderer.swift 的现有逻辑。
public struct DefaultInlineRenderer: InlineRendering, Sendable {
    public init() {}

    public func apply(inline: MarkupInline, to attributed: inout AttributedString,
                      blockText: String, context: RenderingContext) -> Bool {
        // 复用现有自由函数
        applyInlineAttributes(inline, theme: context.theme, to: &attributed, blockText: blockText)
        return true
    }
}
