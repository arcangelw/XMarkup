import Foundation

/// 平台无关的标记文档，从 C++ 引擎的 flat spans 一次性构建
///
/// 使用方式：
/// ```swift
/// let parser = try XMarkupParser()
/// let result = try parser.parse("<h1>Title</h1><p>Hello <b>world</b></p>")
/// let document = MarkupDocument.from(result)
/// let attributed = document.render(theme: .default)
/// ```
public struct MarkupDocument: Sendable, Equatable {
    /// 段落级块列表
    public let blocks: [MarkupBlock]

    public init(blocks: [MarkupBlock]) {
        self.blocks = blocks
    }

    /// 将文档渲染为 AttributedString
    ///
    /// 通过 RenderPipeline.default 执行渲染：
    /// 1. 列表组分析（连续 list item 共享 NSTextList 实例）
    /// 2. Block 渲染（table → attachment → 通用 block，按优先级）
    /// 3. Inline 渲染（bold/italic/code/link 等）
    /// 4. AttributedString 后处理
    ///
    /// ```swift
    /// let parser = try XMarkupParser()
    /// let result = try parser.parse("<h1>Title</h1><p>Hello <b>world</b></p>")
    /// let doc = MarkupDocument.from(result)
    /// let attr = doc.render(theme: .default)
    /// ```
    public func render(theme: MarkupTheme = .default) -> AttributedString {
        RenderPipeline.default.renderAttributed(self, theme: theme)
    }

    /// 使用自定义管线渲染为 NSAttributedString
    public func render(theme: MarkupTheme = .default, pipeline: RenderPipeline) -> NSAttributedString {
        pipeline.render(self, theme: theme)
    }

    /// 追加内容（聊天场景）
    ///
    /// ```swift
    /// let doc1 = MarkupDocument.from(try parser.parse("<p>Hello</p>"))
    /// let doc2 = MarkupDocument.from(try parser.parse("<p>World</p>"))
    /// let combined = doc1.appending(doc2)
    /// ```
    public func appending(_ other: MarkupDocument) -> MarkupDocument {
        MarkupDocument(blocks: blocks + other.blocks)
    }
}
