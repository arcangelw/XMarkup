import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Name Mappings

func blockKindName(for kind: BlockKind) -> String {
    switch kind {
    case .paragraph: return "paragraph"
    case .heading(let level): return "heading\(level.rawValue)"
    case .blockquote: return "blockquote"
    case .preformatted: return "preformatted"
    case .listItem: return "listItem"
    case .division: return "division"
    case .horizontalRule: return "horizontalRule"
    case .table: return "table"
    }
}

func inlineKindName(for kind: InlineKind) -> String {
    switch kind {
    case .bold: return "bold"
    case .italic: return "italic"
    case .underline: return "underline"
    case .strikethrough: return "strikethrough"
    case .code: return "code"
    case .mark: return "mark"
    case .link: return "link"
    case .subscriptText: return "subscript"
    case .superscript: return "superscript"
    case .span: return "span"
    }
}

func blockStyleKey(for kind: BlockKind) -> TagStyleKey? {
    switch kind {
    case .paragraph: return .paragraph
    case .heading: return .heading
    case .blockquote: return .blockquote
    case .preformatted: return .preformatted
    case .listItem: return .listItem
    case .division: return .division
    case .horizontalRule: return .horizontalRule
    case .table: return .table
    }
}

func inlineStyleKey(for kind: InlineKind) -> TagStyleKey? {
    switch kind {
    case .bold: return .bold
    case .italic: return .italic
    case .underline: return .underline
    case .strikethrough: return .strikethrough
    case .code: return .code
    case .mark: return .mark
    case .link: return .link
    case .subscriptText: return .subscriptText
    case .superscript: return .superscript
    case .span: return nil
    }
}

func extractSrc(from content: AttachmentContent) -> String {
    switch content {
    case .image(let src), .video(let src), .audio(let src): return src
    case .custom(_, let metadata): return metadata["src"] ?? ""
    }
}

func srcIdentifier(from content: AttachmentContent) -> String {
    switch content {
    case .image(let src): return "image:\(src)"
    case .video(let src): return "video:\(src)"
    case .audio(let src): return "audio:\(src)"
    case .custom(let type, _): return "custom:\(type)"
    }
}

// MARK: - 跨平台字体 Trait 常量

#if canImport(UIKit)
let traitBold: UIFontDescriptor.SymbolicTraits = .traitBold
let traitItalic: UIFontDescriptor.SymbolicTraits = .traitItalic
#elseif canImport(AppKit)
let traitBold: NSFontDescriptor.SymbolicTraits = .bold
let traitItalic: NSFontDescriptor.SymbolicTraits = .italic
#endif
