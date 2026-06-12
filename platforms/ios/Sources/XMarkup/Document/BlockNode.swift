import Foundation

/// 列表项 — 包含内容块序列（段落、嵌套列表等）
public struct ListItem: Sendable, Equatable {
    public let blocks: [BlockNode]
    public init(blocks: [BlockNode]) { self.blocks = blocks }
}

/// 块级节点 — 可嵌套的树结构，支持两个渲染路径：
///
/// 1. NSAttributedString 路径：通过 Flattener 压平为 text + ranges
/// 2. 未来 UIView 路径：直接映射为 UIView 树
///
/// `indirect` 枚举允许嵌套（如 blockquote 包含 paragraph），
/// 使用纯基本类型（Int、String、Bool、[InlineNode]、[BlockNode]），
/// 确保在 Swift/Kotlin/ArkTS 上可用同一结构定义。
///
/// - Note: `.division(tag:)` 保留原始 HTML 标签名（article/section/header 等），
///   供 UI 层做样式匹配。
public indirect enum BlockNode: Sendable, Equatable {
    /// 段落（含内联样式）
    case paragraph([InlineNode])
    /// 标题
    case heading(level: Int, _ content: [InlineNode])
    /// 引用块（可嵌套，children 可以是任意 BlockNode）
    case blockquote(children: [BlockNode])
    /// 预格式化
    case preformatted([InlineNode])
    /// 定义术语
    case definitionTerm([InlineNode])
    /// 定义描述
    case definitionDescription([InlineNode])
    /// 列表（indentLevel 由 Flattener 从递归深度计算）
    case list(isOrdered: Bool, items: [ListItem])
    /// 水平线
    case horizontalRule
    /// 语义容器（div/article/section/header/footer 等，保留 tag 名）
    case division(tag: String, children: [BlockNode])
    /// 表格
    case table(TableStructure)
    /// 媒体附件
    case media(attachment: MarkupAttachment)
    /// 自定义扩展点（为未来预留的非标准元素）
    case custom(tag: String, attributes: [String: String], children: [BlockNode])
}
