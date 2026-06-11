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
/// 3. **AttributedString 后处理**：按 postProcessors 顺序依次执行
/// 4. **桥接为 NSAttributedString**
/// 5. **NSAttributedString 增强**：按 enhancers 顺序依次执行
///
/// 注意：当前 inline 渲染由 DefaultBlockRenderer 内部完成（包装了旧的 renderBlock 自由函数）。
/// inlineRenderers 预留给自定义插件拦截特定 inline 类型。
/// Phase 5 内联渲染逻辑后将 block/inline 完全分离。
///
/// 使用方式：
/// ```swift
/// let pipeline = RenderPipeline(plugins: [MyPlugin()])
/// let nsAttr = pipeline.render(document, theme: .default)
/// ```
public struct RenderPipeline: @unchecked Sendable {

    // MARK: - 阶段注册表

    /// 块级渲染器（按注册顺序，第一个返回非 nil 的胜出）
    public let blockRenderers: [any BlockRendering]
    /// 内联渲染器（预留给自定义插件拦截特定 inline 类型）
    public let inlineRenderers: [any InlineRendering]
    /// AttributedString 后处理器
    public let postProcessors: [any AttributedStringProcessing]
    /// NSAttributedString 增强器
    public let enhancers: [any NSAttributedStringProcessing]
    /// AttributedString → NSAttributedString 桥接器
    public let bridge: any MarkupRenderer<NSAttributedString>

    // MARK: - 初始化

    /// 按阶段分别注册渲染器
    public init(
        blockRenderers: [any BlockRendering] = [],
        inlineRenderers: [any InlineRendering] = [],
        postProcessors: [any AttributedStringProcessing] = [],
        enhancers: [any NSAttributedStringProcessing] = [],
        bridge: some MarkupRenderer<NSAttributedString> = NSAttributedStringRenderer()
    ) {
        self.blockRenderers = blockRenderers
        self.inlineRenderers = inlineRenderers
        self.postProcessors = postProcessors
        self.enhancers = enhancers
        self.bridge = bridge
    }

    /// 从 RendererPlugin 数组自动分类到各阶段
    ///
    /// 同一组插件实例同时注册到所有四个阶段，每个插件只需覆写关心的方法。
    public init(
        plugins: [any RendererPlugin],
        bridge: some MarkupRenderer<NSAttributedString> = NSAttributedStringRenderer()
    ) {
        self.blockRenderers = plugins
        self.inlineRenderers = plugins
        self.postProcessors = plugins
        self.enhancers = plugins
        self.bridge = bridge
    }

    // MARK: - 主渲染入口

    /// 完整渲染：MarkupDocument → NSAttributedString
    public func render(_ document: MarkupDocument, theme: MarkupTheme = .default) -> NSAttributedString {
        let totalBlocks = document.blocks.count

        // Phase 1: Block 渲染（含列表组分析 + inline 渲染）
        var attr = renderBlocks(document.blocks, theme: theme)

        // Phase 2: AttributedString 后处理
        for processor in postProcessors {
            let ctx = RenderingContext(theme: theme, blockIndex: 0, totalBlocks: totalBlocks)
            attr = processor.process(attr, context: ctx)
        }

        // Phase 3: 桥接为 NSAttributedString
        let nsAttr = bridge.render(attr)
        let mutableAttr = nsAttr.mutableCopy() as! NSMutableAttributedString

        // Phase 4: NSAttributedString 增强
        for enhancer in enhancers {
            let ctx = RenderingContext(theme: theme, blockIndex: 0, totalBlocks: totalBlocks)
            enhancer.enhance(mutableAttr, context: ctx)
        }

        return mutableAttr
    }

    /// 渲染为 AttributedString（不含 NS 桥接和增强）
    public func renderAttributed(_ document: MarkupDocument, theme: MarkupTheme = .default) -> AttributedString {
        let totalBlocks = document.blocks.count
        var attr = renderBlocks(document.blocks, theme: theme)

        for processor in postProcessors {
            let ctx = RenderingContext(theme: theme, blockIndex: 0, totalBlocks: totalBlocks)
            attr = processor.process(attr, context: ctx)
        }

        return attr
    }

    // MARK: - Block 渲染（含列表组分析）

    /// 渲染块列表，合并为单个 AttributedString
    private func renderBlocks(_ blocks: [MarkupBlock], theme: MarkupTheme) -> AttributedString {
        let totalBlocks = blocks.count
        let groups = analyzeBlockGroups(blocks)
        var result = AttributedString("")

        for (i, block) in blocks.enumerated() {
            if i > 0 { result.append(AttributedString("\n")) }

            var ctx = RenderingContext(theme: theme, blockIndex: i, totalBlocks: totalBlocks)

            // 传递列表组信息到 sharedState
            if let lists = groups.listTextLists[i] {
                ctx.sharedState[SharedStateKeys.listTextLists] = lists
            }
            ctx.sharedState[SharedStateKeys.isFirstInListGroup] = groups.listGroupFirst.contains(i)
            ctx.sharedState[SharedStateKeys.isLastInListGroup] = groups.listGroupLast.contains(i)

            // 按顺序询问 blockRenderers
            var rendered: AttributedString?
            for renderer in blockRenderers {
                rendered = renderer.render(block: block, context: ctx)
                if rendered != nil { break }
            }

            if let rendered {
                result.append(rendered)
            }
        }

        return result
    }

    // MARK: - sharedState key 常量

    /// RenderingContext.sharedState 的 key 常量
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
