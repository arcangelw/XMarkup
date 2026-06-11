import Foundation

#if canImport(UIKit)
import UIKit
import CoreText
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

// MARK: - 斜体字体

/// 通过矩阵变换创建合成斜体字体
///
/// 使用 Core Text C API 的独立 matrix 参数创建字体：
/// `CTFontCreateWithFontDescriptor` 的 matrix 参数是渲染级变换，
/// 不存储在 font descriptor 中，由 Core Text 在光栅化时直接应用。
///
/// 区别于 `UIFont(descriptor:withMatrix:size:)`——后者将 matrix 存在
/// descriptor 中，Apple 系统字体会丢弃该值。
func makeSyntheticItalicFont(from font: XMFont) -> XMFont {
    let skew = CGFloat(tan(15.0 * Double.pi / 180.0))

    #if canImport(UIKit)
    var matrix = CGAffineTransform(1, 0, skew, 1, 0, 0)
    let ctFont = CTFontCreateWithFontDescriptor(
        font.fontDescriptor as CTFontDescriptor,
        font.pointSize,
        &matrix
    )
    return ctFont as UIFont

    #elseif canImport(AppKit)
    var matrix = CGAffineTransform(1, 0, skew, 1, 0, 0)
    let ctFont = CTFontCreateWithFontDescriptor(
        font.fontDescriptor as CTFontDescriptor,
        font.pointSize,
        &matrix
    )
    return ctFont as NSFont
    #endif
}

// MARK: - 字体派生

/// 基于当前字体派生新字体，保留所有已有属性（matrix、family、traits）
///
/// 所有 font 修改应通过此函数进行，确保 trait 累积和属性不丢失。
/// - Parameters:
///   - font: 当前字体
///   - addTraits: 需要追加的 symbolic traits（与已有 traits 合并）
///   - removeTraits: 需要移除的 symbolic traits（如 CSS font-weight:normal 清除 bold）
///   - clearMatrix: 是否清除 italic 矩阵倾斜（用于 CSS font-style:normal 恢复正体）
///   - size: 新字号（nil 保留当前）
///   - weight: 新字重（nil 保留当前）
/// - Returns: 派生后的新字体
func deriveFont(
    from font: XMFont,
    addTraits add: XMFontDescriptor.SymbolicTraits? = nil,
    removeTraits remove: XMFontDescriptor.SymbolicTraits? = nil,
    clearMatrix: Bool = false,
    size: CGFloat? = nil,
    weight: XMFont.Weight? = nil
) -> XMFont {
    let newSize = size ?? font.pointSize
    var descriptor = font.fontDescriptor

    #if canImport(UIKit)
    // 保存原始 matrix（italic 通过 matrix 实现，withSymbolicTraits 会丢弃）
    let originalMatrix = descriptor.matrix

    // 合并 symbolic traits（添加 + 移除，总是执行以确保 remove 生效）
    var currentTraits = descriptor.symbolicTraits
    if let add { currentTraits.insert(add) }
    if let remove { currentTraits.remove(remove) }
    if let newDesc = descriptor.withSymbolicTraits(currentTraits) {
        descriptor = newDesc
    }
    // withSymbolicTraits 返回 nil 时保留原 descriptor（trait 组合不可用）
    // 后续 matrix/weight 设置仍会生效

    // 设置字重（通过 traits 属性）
    if let weight {
        descriptor = descriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
    }
    // 恢复 matrix（确保 italic 的矩阵变换不因 withSymbolicTraits 丢失）
    if !clearMatrix, originalMatrix.b != 0 {
        descriptor = descriptor.withMatrix(originalMatrix)
        return UIFont(descriptor: descriptor, size: newSize)
    }

    // 检查 CTFont 渲染级 matrix（makeSyntheticItalicFont 设置的矩阵在 descriptor 中不可见）
    if !clearMatrix {
        #if canImport(UIKit)
        let ctMatrix = CTFontGetMatrix(font as CTFont)
        if ctMatrix.b != 0 {
            var m = ctMatrix
            return CTFontCreateWithFontDescriptor(
                descriptor as CTFontDescriptor,
                newSize,
                &m
            ) as! XMFont
        }
        #endif
    }
    return UIFont(descriptor: descriptor, size: newSize)
    #elseif canImport(AppKit)
    // 保存原始 matrix
    let originalMatrix = descriptor.matrix

    // 合并 symbolic traits
    var currentTraits = descriptor.symbolicTraits
    if let add { currentTraits.insert(add) }
    if let remove { currentTraits.remove(remove) }
    descriptor = descriptor.withSymbolicTraits(currentTraits)

    // 设置字重
    if let weight {
        descriptor = descriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: weight]
        ])
    }
    // 恢复 matrix
    if !clearMatrix, let matrix = originalMatrix {
        descriptor = descriptor.withMatrix(matrix)
    }
    return NSFont(descriptor: descriptor, size: newSize) ?? font
    #endif
}

// MARK: - 等宽字体派生

/// 从当前字体派生等宽字体，保留所有已有 traits（bold）和 matrix（italic）
///
/// 获取系统等宽字体的 descriptor（提供 monospace family），
/// 将当前字体的 symbolicTraits + matrix 合并上去，用当前字号创建。
/// 确保嵌套场景（如 `<b><code>` 或 `<i><code>`）不丢失已有样式。
///
/// ```swift
/// // <h1><b><i><code>text</code></i></b></h1>
/// // 当前 font = .SFNS-Bold + matrix(italic) 32pt
/// let monoFont = deriveMonospacedFont(from: currentFont)
/// // → .AppleSystemUIFontMonospaced-Semibold + matrix(italic) 32pt
/// ```
func deriveMonospacedFont(from font: XMFont) -> XMFont {
    #if canImport(UIKit)
    let monoDescriptor = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        .fontDescriptor
    // 1. 合并 traits
    let targetTraits = font.fontDescriptor.symbolicTraits
    var resultDescriptor: UIFontDescriptor = monoDescriptor
    if let combined = monoDescriptor.withSymbolicTraits(targetTraits) {
        resultDescriptor = combined
    }
    // 2. 合并 matrix（italic 通过 matrix 实现时需保留）
    let sourceMatrix = font.fontDescriptor.matrix
    if sourceMatrix.b != 0 {
        resultDescriptor = resultDescriptor.withMatrix(sourceMatrix)
    }
    return UIFont(descriptor: resultDescriptor, size: font.pointSize)

    #elseif canImport(AppKit)
    let monoDescriptor = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        .fontDescriptor
    // 1. 合并 traits
    let targetTraits = font.fontDescriptor.symbolicTraits
    var resultDescriptor: NSFontDescriptor = monoDescriptor.withSymbolicTraits(targetTraits)
    // 2. 合并 matrix
    let sourceMatrix = font.fontDescriptor.matrix
    if sourceMatrix != nil {
        resultDescriptor = resultDescriptor.withMatrix(sourceMatrix!)
    }
    return NSFont(descriptor: resultDescriptor, size: font.pointSize) ?? font
    #endif
}

