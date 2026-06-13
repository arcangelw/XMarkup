import Foundation
import XMarkup

/// 用例一级分类 — 12 族（详见设计规格 §3.1）
public enum ExampleFamily: String, CaseIterable, Sendable {
    case inlineText
    case headingParagraph
    case blockquotePre
    case list
    case link
    case table
    case media
    case semantic
    case inlineStyle
    case theme
    case showcase
    case robustness

    public var displayName: String {
        switch self {
        case .inlineText:       return "内联文本"
        case .headingParagraph: return "标题与段落"
        case .blockquotePre:    return "引用与预格式"
        case .list:             return "列表"
        case .link:             return "链接"
        case .table:            return "表格"
        case .media:            return "媒体"
        case .semantic:         return "语义容器"
        case .inlineStyle:      return "内联样式"
        case .theme:            return "主题对比"
        case .showcase:         return "综合实战"
        case .robustness:       return "容错与边界"
        }
    }

    /// 侧边栏图标（SF Symbol）
    public var symbol: String {
        switch self {
        case .inlineText:       return "textformat"
        case .headingParagraph: return "text.alignleft"
        case .blockquotePre:    return "quote.opening"
        case .list:             return "list.bullet"
        case .link:             return "link"
        case .table:            return "tablecells"
        case .media:            return "photo"
        case .semantic:         return "square.stack.3d.up"
        case .inlineStyle:      return "paintbrush"
        case .theme:            return "swatchpalette"
        case .showcase:         return "doc.richtext"
        case .robustness:       return "shield.lefthalf.filled"
        }
    }

    /// 是否为功能族（非纯标签族，不强制 tier 分层）
    public var isFunctional: Bool {
        switch self {
        case .theme, .showcase, .robustness: return true
        default: return false
        }
    }
}

/// 用例二级分层（详见设计规格 §3.2）
public enum ExampleTier: String, CaseIterable, Sendable {
    case basic    = "基础"
    case nested   = "嵌套"
    case boundary = "边界"
}

/// 用例可见性（详见设计规格 §3.3）
public enum ExampleVisibility: Sendable, Equatable {
    case visible
    case hidden
}

/// 单个 Demo 用例（详见设计规格 §3.4）
public struct DemoExample: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let html: String
    public let family: ExampleFamily
    public let tier: ExampleTier
    public var visibility: ExampleVisibility
    public var isRegression: Bool
    public var note: String?
    public var themeOverride: MarkupTheme?
    public var themeVariants: [MarkupTheme]?
    public var appendHTML: String?

    public init(
        id: String, title: String, summary: String, html: String,
        family: ExampleFamily, tier: ExampleTier,
        visibility: ExampleVisibility = .visible,
        isRegression: Bool = false,
        note: String? = nil,
        themeOverride: MarkupTheme? = nil,
        themeVariants: [MarkupTheme]? = nil,
        appendHTML: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.html = html
        self.family = family
        self.tier = tier
        self.visibility = visibility
        self.isRegression = isRegression
        self.note = note
        self.themeOverride = themeOverride
        self.themeVariants = themeVariants
        self.appendHTML = appendHTML
    }
}
