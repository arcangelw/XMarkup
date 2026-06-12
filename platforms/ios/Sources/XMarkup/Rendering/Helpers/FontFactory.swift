import Foundation

#if canImport(UIKit)
import UIKit
import CoreText
#elseif canImport(AppKit)
import AppKit
import CoreText
#endif

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
    let originalMatrix = descriptor.matrix

    var currentTraits = descriptor.symbolicTraits
    if let add { currentTraits.insert(add) }
    if let remove { currentTraits.remove(remove) }
    if let newDesc = descriptor.withSymbolicTraits(currentTraits) {
        descriptor = newDesc
    }

    if let weight {
        descriptor = descriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
    }

    if !clearMatrix, originalMatrix.b != 0 {
        descriptor = descriptor.withMatrix(originalMatrix)
        return UIFont(descriptor: descriptor, size: newSize)
    }

    // CTFont 渲染级 matrix（makeSyntheticItalicFont 设置，descriptor 中不可见）
    if !clearMatrix {
        let ctMatrix = CTFontGetMatrix(font as CTFont)
        if ctMatrix.b != 0 {
            var m = ctMatrix
            let ctFont = CTFontCreateWithFontDescriptor(
                descriptor as CTFontDescriptor,
                newSize,
                &m
            )
            return ctFont as? XMFont ?? UIFont(descriptor: descriptor, size: newSize)
        }
    }
    return UIFont(descriptor: descriptor, size: newSize)

    #elseif canImport(AppKit)
    let originalMatrix = descriptor.matrix

    var currentTraits = descriptor.symbolicTraits
    if let add { currentTraits.insert(add) }
    if let remove { currentTraits.remove(remove) }
    descriptor = descriptor.withSymbolicTraits(currentTraits)

    if let weight {
        descriptor = descriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: weight]
        ])
    }

    if !clearMatrix, let matrix = originalMatrix {
        descriptor = descriptor.withMatrix(matrix)
        return NSFont(descriptor: descriptor, size: newSize) ?? font
    }

    // CTFont 渲染级 matrix 检测（与 UIKit 分支对齐）
    if !clearMatrix {
        let ctMatrix = CTFontGetMatrix(font as CTFont)
        if ctMatrix.b != 0 {
            var m = ctMatrix
            let ctFont = CTFontCreateWithFontDescriptor(
                descriptor as CTFontDescriptor,
                newSize,
                &m
            )
            return ctFont as XMFont
        }
    }
    return NSFont(descriptor: descriptor, size: newSize) ?? font
    #endif
}

// MARK: - 等宽字体派生

func deriveMonospacedFont(from font: XMFont) -> XMFont {
    #if canImport(UIKit)
    let monoDescriptor = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        .fontDescriptor
    let targetTraits = font.fontDescriptor.symbolicTraits
    var resultDescriptor: UIFontDescriptor = monoDescriptor
    if let combined = monoDescriptor.withSymbolicTraits(targetTraits) {
        resultDescriptor = combined
    }
    let sourceMatrix = font.fontDescriptor.matrix
    if sourceMatrix.b != 0 {
        resultDescriptor = resultDescriptor.withMatrix(sourceMatrix)
    }
    return UIFont(descriptor: resultDescriptor, size: font.pointSize)

    #elseif canImport(AppKit)
    let monoDescriptor = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        .fontDescriptor
    let targetTraits = font.fontDescriptor.symbolicTraits
    var resultDescriptor: NSFontDescriptor = monoDescriptor.withSymbolicTraits(targetTraits)
    let sourceMatrix = font.fontDescriptor.matrix
    if sourceMatrix != nil {
        resultDescriptor = resultDescriptor.withMatrix(sourceMatrix!)
    }
    return NSFont(descriptor: resultDescriptor, size: font.pointSize) ?? font
    #endif
}
