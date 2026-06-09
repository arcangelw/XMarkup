import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Inline Attributes

func applyInlineAttributes(
    _ inline: MarkupInline,
    theme: MarkupTheme,
    to attr: inout AttributedString,
    blockText: String
) {
    // inline.range 是 UTF-16 NSRange（相对于块文本起始位置）
    // 通过 String.Index 中转后使用 character offset 定位 AttributedString，
    // 避免 Range(NSRange, in: AttributedString) 在 emoji 场景下可能出现的边界错位。
    //
    // 关键假设：AttributedString(block.text) 的 character index 与 String(block.text) 的
    // character index 一致（两者都基于 Extended Grapheme Cluster）。
    // Apple 的 AttributedString 初始化时未做 Unicode 规范化（NFC），
    // 因此此假设在当前 Apple 实现下成立。
    let attrRange: Range<AttributedString.Index>
    do {
        guard let stringRange = Range(inline.range, in: blockText) else { return }
        let charOffset = blockText.distance(from: blockText.startIndex, to: stringRange.lowerBound)
        let charLength = blockText.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
        guard charLength > 0 else { return }
        let start = attr.index(attr.startIndex, offsetByCharacters: charOffset)
        let end = attr.index(start, offsetByCharacters: charLength)
        #if DEBUG
        assert(String(attr[start..<end].characters) == String(blockText[stringRange]),
               "AttributedString character index 与 String character index 不一致，请检查 Unicode 规范化问题")
        #endif
        attrRange = start..<end
    }

    switch inline.kind {
    case .bold:
        applyFontTrait(traitBold, to: attrRange, in: &attr)

    case .italic:
        applyFontTrait(traitItalic, to: attrRange, in: &attr)

    case .underline:
        #if canImport(UIKit)
        attr[attrRange].uiKit.underlineStyle = .single
        #elseif canImport(AppKit)
        attr[attrRange].appKit.underlineStyle = .single
        #endif

    case .strikethrough:
        #if canImport(UIKit)
        attr[attrRange].uiKit.strikethroughStyle = .single
        #elseif canImport(AppKit)
        attr[attrRange].appKit.strikethroughStyle = .single
        #endif

    case .code:
        #if canImport(UIKit)
        attr[attrRange].uiKit.font = UIFont.monospacedSystemFont(
            ofSize: theme.baseFont.pointSize, weight: .regular
        )
        #elseif canImport(AppKit)
        attr[attrRange].appKit.font = NSFont.monospacedSystemFont(
            ofSize: theme.baseFont.pointSize, weight: .regular
        )
        #endif

    case .mark:
        break  // 颜色由主题 tagStyles 覆盖

    case .link(let url):
        #if canImport(UIKit)
        attr[attrRange].uiKit.foregroundColor = .systemBlue
        #elseif canImport(AppKit)
        attr[attrRange].appKit.foregroundColor = .linkColor
        #endif
        attr[attrRange].link = URL(string: url)
        attr[attrRange][XMarkupLinkURLKey.self] = url

    case .subscriptText:
        break  // P2

    case .superscript:
        break  // P2

    case .span(let styles):
        for style in styles {
            applyInlineStyle(style, to: attrRange, in: &attr)
        }
    }

    // 为所有内联元素设置自定义 tag
    let tagName = inlineKindName(for: inline.kind)
    attr[attrRange][XMarkupTagKey.self] = tagName
}

func applyFontTrait(
    _ trait: XMFontDescriptor.SymbolicTraits,
    to range: Range<AttributedString.Index>,
    in attr: inout AttributedString
) {
    for run in attr[range].runs {
        #if canImport(UIKit)
        if let font = run.uiKit.font {
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                attr[run.range].uiKit.font = UIFont(descriptor: descriptor, size: font.pointSize)
            } else if trait == traitItalic {
                let matrix = CGAffineTransform(a: 1, b: 0, c: CGFloat(tanf(Float.pi / 180 * 14)), d: 1, tx: 0, ty: 0)
                let descriptor = font.fontDescriptor.withMatrix(matrix)
                attr[run.range].uiKit.font = UIFont(descriptor: descriptor, size: font.pointSize)
            } else if trait == traitBold {
                attr[run.range].uiKit.font = UIFont.systemFont(ofSize: font.pointSize, weight: .bold)
            }
        }
        #elseif canImport(AppKit)
        if let font = run.appKit.font {
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            if let newFont = NSFont(descriptor: descriptor, size: font.pointSize) {
                attr[run.range].appKit.font = newFont
            } else if trait == traitItalic {
                let matrix = AffineTransform(m11: 1, m12: 0, m21: CGFloat(tanf(Float.pi / 180 * 14)), m22: 1, tX: 0, tY: 0)
                let descriptor = font.fontDescriptor.withMatrix(matrix)
                if let newFont = NSFont(descriptor: descriptor, size: font.pointSize) {
                    attr[run.range].appKit.font = newFont
                }
            } else if trait == traitBold {
                attr[run.range].appKit.font = NSFont.boldSystemFont(ofSize: font.pointSize)
            }
        }
        #endif
    }
}

func applyInlineStyle(
    _ style: InlineStyle,
    to range: Range<AttributedString.Index>,
    in attr: inout AttributedString
) {
    switch style {
    case .foregroundColor(let hex):
        if let color = ColorParser.parse(hex) {
            #if canImport(UIKit)
            attr[range].uiKit.foregroundColor = color
            #elseif canImport(AppKit)
            attr[range].appKit.foregroundColor = color
            #endif
        }
    case .backgroundColor(let hex):
        if let color = ColorParser.parse(hex) {
            #if canImport(UIKit)
            attr[range].uiKit.backgroundColor = color
            #elseif canImport(AppKit)
            attr[range].appKit.backgroundColor = color
            #endif
        }
    case .fontSize(let size):
        for run in attr[range].runs {
            #if canImport(UIKit)
            if let font = run.uiKit.font {
                let newFont = UIFont(descriptor: font.fontDescriptor, size: CGFloat(size))
                attr[run.range].uiKit.font = newFont
            }
            #elseif canImport(AppKit)
            if let font = run.appKit.font {
                if let newFont = NSFont(descriptor: font.fontDescriptor, size: CGFloat(size)) {
                    attr[run.range].appKit.font = newFont
                }
            }
            #endif
        }
    case .fontStyle(let fontStyle):
        if fontStyle == "italic" {
            applyFontTrait(traitItalic, to: range, in: &attr)
        }
    case .textDecoration(let decoration):
        if decoration == "underline" {
            #if canImport(UIKit)
            attr[range].uiKit.underlineStyle = .single
            #elseif canImport(AppKit)
            attr[range].appKit.underlineStyle = .single
            #endif
        } else if decoration == "line-through" {
            #if canImport(UIKit)
            attr[range].uiKit.strikethroughStyle = .single
            #elseif canImport(AppKit)
            attr[range].appKit.strikethroughStyle = .single
            #endif
        }
    case .fontWeight, .lineHeight, .letterSpacing, .textAlign:
        break  // P2
    }
}
