import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认块级渲染器 — 处理除 table 和 media attachment 外的所有 block 类型
///
/// 从 RenderingContext.theme 读取 typed theme 配置，替代旧的 tagStyles 字典。
/// 不处理 `.table`（由 DefaultTableRenderer 处理）和带 attachment 的 block（由 DefaultAttachmentRenderer 处理）。
public struct DefaultBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? {
        // table 由 DefaultTableRenderer 处理
        if case .table = block.kind { return nil }

        // media attachment 由 DefaultAttachmentRenderer 处理
        if block.attachment != nil { return nil }

        return renderBlockInternal(block, theme: context.theme)
    }

    // MARK: - 内部渲染（复用现有自由函数）

    /// 将现有 renderBlock 自由函数包装为协议方法
    ///
    /// Phase 5 将把完整渲染逻辑内联到此处，当前复用 Rendering/BlockRenderer.swift
    private func renderBlockInternal(_ block: MarkupBlock, theme: MarkupTheme) -> AttributedString {
        // 复用列表组分析后的渲染（这里用无共享列表的简化路径）
        let lists: [NSTextList]? = nil
        return XMarkup.renderBlock(block, sharedLists: lists, isFirstInListGroup: false, isLastInListGroup: false, theme: theme)
    }
}
