import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 类型化主题配置
///
/// 每个 BlockKind / InlineKind 有独立的 typed theme struct，提供：
/// - 声明式默认值
/// - 三级精度控制（base → per-level override → 动态 resolve 闭包）
/// - 编译时类型安全
///
/// `Equatable` 排除 `media`（含闭包，不可比较）和所有 theme struct 的 resolve 闭包。
public struct MarkupTheme: @unchecked Sendable, Equatable {
    /// 基础字体
    public var baseFont: XMFont

    // MARK: - 块级主题（按 kind 类型化）

    /// 段落主题（也是 spacing 的 fallback）
    public var paragraph: ParagraphTheme
    /// 标题主题（含 h1-h6 逐级覆盖）
    public var heading: HeadingTheme
    /// 引用块主题
    public var blockquote: BlockquoteTheme
    /// 代码块主题
    public var preformatted: PreformattedTheme
    /// 列表主题
    public var list: ListTheme
    /// 表格主题
    public var table: TableTheme
    /// 水平线主题
    public var horizontalRule: HorizontalRuleTheme

    // MARK: - 内联主题（按 kind 类型化）

    /// 粗体内联
    public var bold: InlineTextTheme
    /// 斜体内联
    public var italic: InlineTextTheme
    /// 下划线内联
    public var underline: InlineTextTheme
    /// 删除线内联
    public var strikethrough: InlineTextTheme
    /// 行内代码
    public var codeInline: InlineTextTheme
    /// 高亮标记
    public var mark: InlineTextTheme
    /// 链接
    public var link: LinkTheme
    /// 下标
    public var subscriptText: InlineTextTheme
    /// 上标
    public var superscript: InlineTextTheme

    // MARK: - 媒体

    /// 媒体渲染策略（不参与 Equatable 比较，因包含闭包）
    public var media: MediaRenderingStrategy

    public init(baseFont: XMFont = XMFont.systemFont(ofSize: 16)) {
        self.baseFont = baseFont
        self.paragraph = .default
        self.heading = .default
        self.blockquote = .default
        self.preformatted = .default
        self.list = .default
        self.table = .default
        self.horizontalRule = .default
        self.bold = .default
        self.italic = .default
        self.underline = .default
        self.strikethrough = .default
        self.codeInline = .default
        self.mark = .default
        self.link = .default
        self.subscriptText = .default
        self.superscript = .default
        self.media = .placeholder
    }

    // Equatable 排除 media（闭包不可比较），
    // 各 typed theme 的 resolve 闭包也被各自的手动 == 排除
    public static func == (lhs: MarkupTheme, rhs: MarkupTheme) -> Bool {
        lhs.baseFont == rhs.baseFont
            && lhs.paragraph == rhs.paragraph
            && lhs.heading == rhs.heading
            && lhs.blockquote == rhs.blockquote
            && lhs.preformatted == rhs.preformatted
            && lhs.list == rhs.list
            && lhs.table == rhs.table
            && lhs.horizontalRule == rhs.horizontalRule
            && lhs.bold == rhs.bold
            && lhs.italic == rhs.italic
            && lhs.underline == rhs.underline
            && lhs.strikethrough == rhs.strikethrough
            && lhs.codeInline == rhs.codeInline
            && lhs.mark == rhs.mark
            && lhs.link == rhs.link
            && lhs.subscriptText == rhs.subscriptText
            && lhs.superscript == rhs.superscript
    }
}
