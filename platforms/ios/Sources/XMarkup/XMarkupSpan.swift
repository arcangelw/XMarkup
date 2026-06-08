import Foundation

/// 样式区间，描述一个标签或 CSS 属性在文本中的位置
///
/// `range` 使用 UTF-16 码元索引，与 NSString/NSAttributedString 索引体系直接对齐。
public struct XMarkupSpan: Sendable, Equatable {
    /// 文本区间（UTF-16 码元索引，半开区间 [start, end)）
    public let range: NSRange
    /// 标签类型
    public let tag: XMarkupTag
    /// CSS 样式类型
    public let style: XMarkupStyle
    /// 属性值（href/src/颜色值等），可能为 nil
    public let value: String?
}
