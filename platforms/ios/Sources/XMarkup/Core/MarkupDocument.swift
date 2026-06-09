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
