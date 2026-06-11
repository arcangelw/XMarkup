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
    case .tableRow: return "tableRow"
    case .tableCell: return "tableCell"
    case .tableHeader: return "tableHeader"
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

// MARK: - 合成斜体

/// 创建合成斜体字体（Synthetic Oblique）
///
/// 大多数中文字体没有 italic 变体，`withSymbolicTraits(.traitItalic)` 返回的原字体不变。
/// 通过 `CGAffineTransform` 矩阵倾斜实现视觉斜体效果（约 15°），UITextView/NSTextView 可正确渲染。
///
/// 参考：https://www.cnblogs.com/iOS-Girl/p/3753282.html
func makeSyntheticItalicFont(from font: XMFont) -> XMFont {
    let skew = CGFloat(tan(15.0 * Double.pi / 180.0))
    #if canImport(UIKit)
    let matrix = CGAffineTransform(1, 0, skew, 1, 0, 0)
    let descriptor = font.fontDescriptor.withMatrix(matrix)
    return UIFont(descriptor: descriptor, size: font.pointSize)
    #elseif canImport(AppKit)
    let matrix = AffineTransform(m11: 1, m12: 0, m21: skew, m22: 1, tX: 0, tY: 0)
    let descriptor = font.fontDescriptor.withMatrix(matrix)
    return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    #endif
}

// MARK: - 字体派生

/// 基于当前字体派生新字体，保留所有已有属性（matrix、family、traits）
///
/// 所有 font 修改应通过此函数进行，确保 trait 累积和属性不丢失。
/// - Parameters:
///   - font: 当前字体
///   - addTraits: 需要追加的 symbolic traits（与已有 traits 合并）
///   - size: 新字号（nil 保留当前）
///   - weight: 新字重（nil 保留当前）
/// - Returns: 派生后的新字体
func deriveFont(
    from font: XMFont,
    addTraits traits: XMFontDescriptor.SymbolicTraits? = nil,
    size: CGFloat? = nil,
    weight: XMFont.Weight? = nil
) -> XMFont {
    let newSize = size ?? font.pointSize
    var descriptor = font.fontDescriptor

    #if canImport(UIKit)
    // 追加 traits（与已有合并）
    if let traits {
        var currentTraits = descriptor.symbolicTraits
        currentTraits.insert(traits)
        if let newDesc = descriptor.withSymbolicTraits(currentTraits) {
            descriptor = newDesc
        }
    }
    // 设置字重（通过 traits 属性）
    if let weight {
        descriptor = descriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
    }
    return UIFont(descriptor: descriptor, size: newSize)
    #elseif canImport(AppKit)
    // 追加 traits（NSFontDescriptor.withSymbolicTraits 返回非 Optional）
    if let traits {
        var currentTraits = descriptor.symbolicTraits
        currentTraits.insert(traits)
        descriptor = descriptor.withSymbolicTraits(currentTraits)
    }
    // 设置字重
    if let weight {
        descriptor = descriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: weight]
        ])
    }
    return NSFont(descriptor: descriptor, size: newSize) ?? font
    #endif
}
