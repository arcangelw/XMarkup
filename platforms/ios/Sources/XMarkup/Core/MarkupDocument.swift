import Foundation

/// 平台无关的标记文档，从 C++ 引擎的 flat spans 一次性构建
public struct MarkupDocument: Sendable, Equatable {
    /// 段落级块列表
    public let blocks: [MarkupBlock]

    public init(blocks: [MarkupBlock]) {
        self.blocks = blocks
    }

    /// 追加内容（聊天场景）
    public func appending(_ other: MarkupDocument) -> MarkupDocument {
        MarkupDocument(blocks: blocks + other.blocks)
    }
}
