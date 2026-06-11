import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 可组合的渲染管线 — 编排多个插件按阶段执行
///
/// 渲染流程：
/// 1. **Block 渲染**：按 blockRenderers 注册顺序依次询问，第一个返回非 nil 的胜出
/// 2. **Inline 渲染**：对每个 block 的 inlines，按 inlineRenderers 顺序依次询问
/// 3. **AttributedString 后处理**：按 postProcessors 顺序依次执行
/// 4. **桥接为 NSAttributedString**
/// 5. **NSAttributedString 增强**：按 enhancers 顺序依次执行
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
    /// 内联渲染器（按注册顺序，第一个返回 true 的胜出）
    public let inlineRenderers: [any InlineRendering]
    /// AttributedString 后处理器
    public let postProcessors: [any AttributedStringProcessing]
    /// NSAttributedString 增强器
    public let enhancers: [any NSAttributedStringProcessing]
    /// AttributedString → NSAttributedString 桥接器
    public let bridge: NSAttributedStringRenderer

    // MARK: - 初始化

    /// 按阶段分别注册渲染器
    public init(
        blockRenderers: [any BlockRendering] = [],
        inlineRenderers: [any InlineRendering] = [],
        postProcessors: [any AttributedStringProcessing] = [],
        enhancers: [any NSAttributedStringProcessing] = []
    ) {
        self.blockRenderers = blockRenderers
        self.inlineRenderers = inlineRenderers
        self.postProcessors = postProcessors
        self.enhancers = enhancers
        self.bridge = NSAttributedStringRenderer()
    }

    /// 从 RendererPlugin 数组自动分类到各阶段
    ///
    /// 同一组插件实例同时注册到所有四个阶段，每个插件只需覆写关心的方法。
    public init(plugins: [any RendererPlugin]) {
        self.blockRenderers = plugins
        self.inlineRenderers = plugins
        self.postProcessors = plugins
        self.enhancers = plugins
        self.bridge = NSAttributedStringRenderer()
    }

    // MARK: - 主渲染入口

    /// 完整渲染：MarkupDocument → NSAttributedString
    public func render(_ document: MarkupDocument, theme: MarkupTheme = .default) -> NSAttributedString {
        let totalBlocks = document.blocks.count

        // Phase 1: Block 渲染（含 inline 渲染）
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

    // MARK: - Block 渲染

    /// 渲染块列表，合并为单个 AttributedString
    private func renderBlocks(_ blocks: [MarkupBlock], theme: MarkupTheme) -> AttributedString {
        let totalBlocks = blocks.count
        var result = AttributedString("")

        for (i, block) in blocks.enumerated() {
            if i > 0 { result.append(AttributedString("\n")) }

            let ctx = RenderingContext(theme: theme, blockIndex: i, totalBlocks: totalBlocks)

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
}
