import Foundation

/// 平台无关的标记文档，从 C++ 引擎的 flat spans 一次性构建
///
/// 使用方式：
/// ```swift
/// // 快速初始化：一行代码完成 parse → build
/// let doc = try MarkupDocument.from(html: "<h1>Title</h1><p>Hello <b>world</b></p>")
///
/// // 渲染 — 命名对齐 RenderPipeline
/// let nsAttr = doc.render(theme: .default)           // → NSAttributedString
/// let attr = doc.renderAttributed(theme: .default)   // → AttributedString
/// ```
public struct MarkupDocument: Sendable, Equatable {
    /// 段落级块列表
    public let blocks: [MarkupBlock]

    public init(blocks: [MarkupBlock]) {
        self.blocks = blocks
    }

    // MARK: - 便利初始化

    /// 从 HTML 字符串快速构建文档
    ///
    /// 一行代码完成 parse → build 流程：
    /// ```swift
    /// let doc = try MarkupDocument.from(html: "<p>Hello <b>world</b></p>")
    /// ```
    ///
    /// - Parameters:
    ///   - html: HTML 输入字符串
    ///   - parser: 可选的解析器实例（nil 时自动创建默认解析器）
    /// - Returns: 构建好的 MarkupDocument
    /// - Throws: `XMarkupError` 解析错误
    public static func from(html: String, parser: XMarkupParser? = nil) throws -> MarkupDocument {
        let p = try parser ?? XMarkupParser()
        let result = try p.parse(html)
        return from(result)
    }

    /// 从 XMarkupResult 构建（实现见 MarkupDocumentBuilder.swift）
    // public static func from(_ result: XMarkupResult) -> MarkupDocument

    // MARK: - Render（对齐 RenderPipeline 命名）

    // ---- render = NSAttributedString 输出 ----

    /// 使用默认管线渲染为 NSAttributedString
    ///
    /// ```swift
    /// let nsAttr = doc.render(theme: .default)
    /// textView.attributedText = nsAttr
    /// ```
    public func render(theme: MarkupTheme = .default) -> NSAttributedString {
        RenderPipeline.default.render(self, theme: theme)
    }

    /// 使用自定义管线渲染为 NSAttributedString
    ///
    /// ```swift
    /// let customPipeline = RenderPipeline.default.addingEnhancers([MyPlugin()])
    /// let nsAttr = doc.render(theme: .default, pipeline: customPipeline)
    /// ```
    public func render(theme: MarkupTheme = .default, pipeline: RenderPipeline) -> NSAttributedString {
        pipeline.render(self, theme: theme)
    }

    // ---- renderAttributed = AttributedString 输出 ----

    /// 使用默认管线渲染为 AttributedString
    ///
    /// ```swift
    /// let attr = doc.renderAttributed(theme: .default)
    /// // 可在 AttributedString 层做进一步处理
    /// ```
    public func renderAttributed(theme: MarkupTheme = .default) -> AttributedString {
        RenderPipeline.default.renderAttributed(self, theme: theme)
    }

    /// 使用自定义管线渲染为 AttributedString
    ///
    /// ```swift
    /// let attr = doc.renderAttributed(theme: .default, pipeline: myPipeline)
    /// ```
    public func renderAttributed(theme: MarkupTheme = .default, pipeline: RenderPipeline) -> AttributedString {
        pipeline.renderAttributed(self, theme: theme)
    }

    // MARK: - Document Operations

    /// 追加内容（聊天场景）
    ///
    /// ```swift
    /// let doc1 = try MarkupDocument.from(html: "<p>Hello</p>")
    /// let doc2 = try MarkupDocument.from(html: "<p>World</p>")
    /// let combined = doc1.appending(doc2)
    /// ```
    public func appending(_ other: MarkupDocument) -> MarkupDocument {
        MarkupDocument(blocks: blocks + other.blocks)
    }
}
