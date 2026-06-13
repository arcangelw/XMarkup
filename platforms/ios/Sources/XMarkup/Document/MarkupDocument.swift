import Foundation

/// 平台无关的标记文档，从 C++ 引擎的 flat spans 构建为 BlockNode 树
///
/// 两种渲染路径：
/// - `render()` → NSAttributedString（Apple 平台，当前）
/// - 未来：`makeView()` → UIView（通过 BlockNode 树直接构建）
///
/// 使用方式：
/// ```swift
/// // 快速初始化：一行代码完成 parse → build
/// let doc = try MarkupDocument.from(html: "<h1>Title</h1><p>Hello <b>world</b></p>")
///
/// // 渲染为 NSAttributedString
/// let nsAttr = doc.render(theme: .default)
/// textView.attributedText = nsAttr
/// ```
public struct MarkupDocument: Sendable, Equatable {
    /// 块节点树（跨平台核心模型）
    ///
    /// 保留 HTML 的嵌套结构。通过 Flattener 压平后送入 NSAttributedString 管线。
    public let blocks: [BlockNode]

    /// 文档元数据
    public let metadata: DocumentMetadata

    /// 原始解析结果（text + spans），调试 / Demo 检查用
    ///
    /// `from(XMarkupResult)` 时保留，供上层（如 Demo Span 面板）展示原始解析数据。
    /// 不参与 `==` 比较（调试辅助，非文档结构）。
    public let source: XMarkupResult?

    public init(
        blocks: [BlockNode],
        metadata: DocumentMetadata = DocumentMetadata(),
        source: XMarkupResult? = nil
    ) {
        self.blocks = blocks
        self.metadata = metadata
        self.source = source
    }

    /// 等价仅比较 blocks + metadata（source 为调试辅助，不参与）
    public static func == (lhs: MarkupDocument, rhs: MarkupDocument) -> Bool {
        lhs.blocks == rhs.blocks && lhs.metadata == rhs.metadata
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

    // from(_:) 实现在 MarkupDocumentBuilder.swift 中

    // MARK: - Render（Apple 平台 NSAttributedString 路径）

    /// 渲染为 NSAttributedString
    ///
    /// 流程：
    ///   BlockNode[] → Flattener → MarkupBlock[] → RenderPipeline → NSAttributedString
    ///
    /// - Parameters:
    ///   - theme: 渲染主题，默认 `.default`
    ///   - pipeline: 渲染管线，默认 `RenderPipeline.default`
    /// - Returns: 渲染后的 NSAttributedString
    public func render(
        theme: MarkupTheme = .default,
        pipeline: RenderPipeline = .default
    ) -> NSAttributedString {
        pipeline.render(self, theme: theme)
    }

    /// 渲染为 AttributedString（Apple 平台便利包装）
    public func renderAttributed(
        theme: MarkupTheme = .default,
        pipeline: RenderPipeline = .default
    ) -> AttributedString {
        pipeline.renderAttributed(self, theme: theme)
    }

    // MARK: - Document Operations

    /// 追加内容（聊天场景）
    ///
    /// source 合并：text 直接拼接，rhs 的 spans 按 lhs.text 的 UTF-16 码元数偏移，
    /// 保持与 NSString/NSAttributedString 索引体系一致（XMarkupSpan.range 为 UTF-16）。
    public func appending(_ other: MarkupDocument) -> MarkupDocument {
        MarkupDocument(
            blocks: blocks + other.blocks,
            metadata: metadata,
            source: XMarkupResult.merged(lhs: source, rhs: other.source)
        )
    }
}
