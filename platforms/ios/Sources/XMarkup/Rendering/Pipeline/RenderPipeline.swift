import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 可组合的渲染管线 — 编排多个插件按阶段执行
///
/// 渲染流程：
/// 1. **列表组分析**：识别连续的 list item 组，共享 NSTextList 实例
/// 2. **Block 渲染**：按 blockRenderers 注册顺序依次询问，第一个返回非 nil 的胜出
/// 3. **Inline 渲染**：对每个 block 的 inlines，按 inlineRenderers 顺序依次询问
/// 4. **NSAttributedString 增强**：按 enhancers 顺序依次执行
///
/// 全程直接操作 NSMutableAttributedString，无需 AttributedString 桥接。
///
/// 使用方式：
/// ```swift
/// let pipeline = RenderPipeline(plugins: [MyPlugin()])
/// let nsAttr = pipeline.render(document, theme: .default)
/// ```
///
/// - Note: `@unchecked Sendable` 标记因为持有 protocol existential 数组，
///   实际约束为所有注册的渲染器必须为 Sendable（由协议要求保证）。
public struct RenderPipeline: @unchecked Sendable {

    // MARK: - 阶段注册表

    /// 块级渲染器（按注册顺序，第一个返回非 nil 的胜出）
    public let blockRenderers: [any BlockRendering]
    /// 内联渲染器（预留给自定义插件拦截特定 inline 类型）
    public let inlineRenderers: [any InlineRendering]
    /// NSAttributedString 增强器（后处理 + 平台增强）
    public let enhancers: [any NSAttributedStringProcessing]

    // MARK: - 初始化

    /// 按阶段分别注册渲染器
    public init(
        blockRenderers: [any BlockRendering] = [],
        inlineRenderers: [any InlineRendering] = [],
        enhancers: [any NSAttributedStringProcessing] = []
    ) {
        self.blockRenderers = blockRenderers
        self.inlineRenderers = inlineRenderers
        self.enhancers = enhancers
    }

    /// 从 RendererPlugin 数组自动分类到各阶段
    ///
    /// 同一组插件实例同时注册到 blockRenderers/inlineRenderers/enhancers，
    /// 每个插件只需覆写关心的方法，未覆写的使用 RendererPlugin 协议的默认空实现。
    public init(
        plugins: [any RendererPlugin],
        enhancers: [any NSAttributedStringProcessing] = []
    ) {
        self.blockRenderers = plugins
        self.inlineRenderers = plugins
        // RendererPlugin 也遵循 NSAttributedStringProcessing，一并注册到 enhancers
        self.enhancers = plugins as [any NSAttributedStringProcessing] + enhancers
    }

    // MARK: - 派生方法

    /// 基于当前管线追加增强器，返回新管线实例
    ///
    /// 用于 XMarkupUI 等上层模块在默认管线基础上添加平台增强插件：
    /// ```swift
    /// let pipeline = RenderPipeline.default.addingEnhancers([PlatformEnhancementPlugin()])
    /// ```
    public func addingEnhancers(_ newEnhancers: [any NSAttributedStringProcessing]) -> RenderPipeline {
        RenderPipeline(
            blockRenderers: blockRenderers,
            inlineRenderers: inlineRenderers,
            enhancers: enhancers + newEnhancers
        )
    }

    // MARK: - 主渲染入口

    /// 完整渲染：MarkupDocument → NSAttributedString
    public func render(_ document: MarkupDocument, theme: MarkupTheme = .default) -> NSAttributedString {
        // BlockNode 树 → 扁平 MarkupBlock[]（供 NSAttributedString 管线使用）
        let flatBlocks = Flattener.flatten(document.blocks)
        let totalBlocks = flatBlocks.count

        // Phase 1 & 2: Block 渲染（含列表组分析 + inline 渲染）
        let result = renderBlocks(flatBlocks, theme: theme)

        // Phase 3: NSAttributedString 增强（blockIndex = -1 表示全局上下文，非单块）
        for enhancer in enhancers {
            let ctx = RenderingContext(theme: theme, blockIndex: -1, totalBlocks: totalBlocks)
            enhancer.enhance(result, context: ctx)
        }

        return result
    }

    /// 渲染为 AttributedString（便利包装，可直接用于 SwiftUI Text）
    public func renderAttributed(_ document: MarkupDocument, theme: MarkupTheme = .default) -> AttributedString {
        AttributedString(render(document, theme: theme))
    }

    // MARK: - Block 渲染（含列表组分析）

    /// 渲染块列表，合并为单个 NSMutableAttributedString
    private func renderBlocks(_ blocks: [MarkupBlock], theme: MarkupTheme) -> NSMutableAttributedString {
        let totalBlocks = blocks.count
        let groups = analyzeBlockGroups(blocks)
        let result = NSMutableAttributedString()

        for (i, block) in blocks.enumerated() {
            if i > 0 { result.append(NSAttributedString(string: "\n")) }

            var ctx = RenderingContext(theme: theme, blockIndex: i, totalBlocks: totalBlocks)

            // 传递列表组信息（类型安全的 listContext，优先使用）
            if let lists = groups.listTextLists[i] {
                ctx.listContext = ListContext(
                    textLists: lists,
                    isFirstInGroup: groups.listGroupFirst.contains(i),
                    isLastInGroup: groups.listGroupLast.contains(i)
                )
            }

            // 按顺序询问 blockRenderers
            var rendered: NSMutableAttributedString?
            for renderer in blockRenderers {
                rendered = renderer.render(block: block, context: ctx)
                if rendered != nil { break }
            }

            // 兜底：无 renderer 处理时，至少产出纯文本段落
            if rendered == nil {
                rendered = NSMutableAttributedString(
                    string: block.text,
                    attributes: [.font: theme.baseFont]
                )
                // 将块内 inline 注入 fallback 段落
                for inline in block.inlines {
                    for inlineRenderer in inlineRenderers {
                        if inlineRenderer.apply(inline: inline, to: rendered!, context: ctx) {
                            break
                        }
                    }
                }
                result.append(rendered!)
                continue
            }

            if let rendered {
                // 调度 inlineRenderers：对每个 inline 按注册顺序询问
                for inline in block.inlines {
                    for inlineRenderer in inlineRenderers {
                        if inlineRenderer.apply(inline: inline, to: rendered, context: ctx) {
                            break
                        }
                    }
                }
                result.append(rendered)
            }
        }

        return result
    }

    // MARK: - sharedState key 常量（已由 RenderingContext.listContext 替代）

    /// RenderingContext.sharedState 的 key 常量
    /// - Note: 新代码优先使用 `RenderingContext.listContext`（类型安全）。
    @available(*, deprecated, message: "使用 RenderingContext.listContext 替代")
    public enum SharedStateKeys {
        public static let listTextLists = "listTextLists"
        public static let isFirstInListGroup = "isFirstInListGroup"
        public static let isLastInListGroup = "isLastInListGroup"
    }

    // MARK: - 列表组分析

    /// 列表组分析结果
    private struct BlockGroups {
        var listTextLists: [Int: [NSTextList]] = [:]
        var listGroupFirst: Set<Int> = []
        var listGroupLast: Set<Int> = []
    }

    /// 分析连续的 list item 组，为同组项共享 NSTextList 实例
    private func analyzeBlockGroups(_ blocks: [MarkupBlock]) -> BlockGroups {
        var groups = BlockGroups()
        var currentIdx: [Int] = []
        var currentOrdered: Bool?
        var currentIndent: Int?

        for (i, block) in blocks.enumerated() {
            guard case .listItem(let isOrdered, let indent) = block.kind else {
                finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
                currentIdx = []; currentOrdered = nil; currentIndent = nil
                continue
            }
            if currentIdx.isEmpty {
                currentIdx = [i]; currentOrdered = isOrdered; currentIndent = indent
            } else if isOrdered == currentOrdered && indent == currentIndent {
                currentIdx.append(i)
            } else {
                finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
                currentIdx = [i]; currentOrdered = isOrdered; currentIndent = indent
            }
        }
        finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
        return groups
    }

    private func finalizeGroup(_ idx: inout [Int], _ groups: inout BlockGroups,
                                ordered: Bool?, indent: Int?) {
        guard !idx.isEmpty, let ord = ordered, let ind = indent else { return }
        let lists = buildTextLists(isOrdered: ord, indentLevel: ind)
        groups.listGroupFirst.insert(idx.first!)
        groups.listGroupLast.insert(idx.last!)
        for i in idx { groups.listTextLists[i] = lists }
        idx = []
    }

    private func buildTextLists(isOrdered: Bool, indentLevel: Int) -> [NSTextList] {
        var lists: [NSTextList] = []
        for level in 0...indentLevel {
            let fmt: NSTextList.MarkerFormat = (level == 0)
                ? (isOrdered ? .decimal : .disc)
                : (isOrdered ? .decimal : .circle)
            lists.append(NSTextList(markerFormat: fmt, options: 0))
        }
        return lists
    }
}
