import Foundation

/// 内联节点 — 结构化内容模型，非 text + range 形式。
///
/// 与 `BlockNode` 一样使用纯基本类型（String, [InlineNode], [InlineStyle]），
/// 确保跨平台模型统一。
///
/// `indirect` 枚举允许嵌套（如 `.bold([.italic([.text("hi")])])`），
/// 完整表达 HTML 内联元素的层级关系。
///
/// NSAttributedString 路径通过 Flattener 将树结构的 InlineNode 压平为
/// 连续文本 + TextRange 偏移，再送入 RenderPipeline。
///
/// 未来 UIView 路径直接映射为 UILabel 的属性文本或自定义 TextKit 视图。
public indirect enum InlineNode: Sendable, Equatable {
    /// 纯文本
    case text(String)
    /// 粗体（可嵌套）
    case bold([InlineNode])
    /// 斜体（可嵌套）
    case italic([InlineNode])
    /// 下划线
    case underline([InlineNode])
    /// 删除线
    case strikethrough([InlineNode])
    /// 行内代码
    case code(String)
    /// 高亮标记
    case mark(String)
    /// 链接
    case link(url: String, _ content: [InlineNode])
    /// 下标
    case subscriptText([InlineNode])
    /// 上标
    case superscript([InlineNode])
    /// CSS 内联样式
    case styled(styles: [InlineStyle], _ content: [InlineNode])
    /// 换行
    case lineBreak
}
