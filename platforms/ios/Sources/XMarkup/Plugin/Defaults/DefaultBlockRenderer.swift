import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认块级渲染器 — 处理除 table 和 media attachment 外的所有 block 类型
///
/// 从 RenderingContext.theme 读取 typed theme 配置，从 sharedState 读取列表组信息。
/// 不处理 `.table`（由 DefaultTableRenderer 处理）和带 attachment 的 block（由 DefaultAttachmentRenderer 处理）。
public struct DefaultBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? {
        // table 由 DefaultTableRenderer 处理
        if case .table = block.kind { return nil }

        // media attachment 由 DefaultAttachmentRenderer 处理
        if block.attachment != nil { return nil }

        // 从 sharedState 读取列表组信息（由 RenderPipeline 分析后注入）
        let sharedLists = context.sharedState[RenderPipeline.SharedStateKeys.listTextLists] as? [NSTextList]
        let isFirst = context.sharedState[RenderPipeline.SharedStateKeys.isFirstInListGroup] as? Bool ?? false
        let isLast = context.sharedState[RenderPipeline.SharedStateKeys.isLastInListGroup] as? Bool ?? false

        return XMarkup.renderBlock(block, sharedLists: sharedLists,
                                    isFirstInListGroup: isFirst, isLastInListGroup: isLast,
                                    theme: context.theme)
    }
}
