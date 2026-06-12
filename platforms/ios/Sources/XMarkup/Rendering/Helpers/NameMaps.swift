import Foundation

// MARK: - 块级/内联类型名称映射

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
    case .tableRow: return "tableRow"
    case .tableCell: return "tableCell"
    case .tableHeader: return "tableHeader"
    case .media: return "media"
    case .definitionTerm: return "definitionTerm"
    case .definitionDescription: return "definitionDescription"
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
    case .lineBreak: return "lineBreak"
    }
}

// MARK: - Attachment 内容提取

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
