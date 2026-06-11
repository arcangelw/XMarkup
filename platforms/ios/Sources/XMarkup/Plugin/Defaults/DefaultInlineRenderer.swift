import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 默认内联渲染器 — 处理所有 InlineKind 的样式应用
///
/// 由 RenderPipeline 在 block 渲染完成后调度。
/// 每个 block 的 inlines 按注册顺序依次询问 inlineRenderers。
public struct DefaultInlineRenderer: InlineRendering, Sendable {
    public init() {}

    public func apply(inline: MarkupInline, to attributed: inout AttributedString,
                      blockText: String, context: RenderingContext) -> Bool {
        // inline.range 是 UTF-16 NSRange（相对于块文本起始位置）
        let attrRange: Range<AttributedString.Index>
        do {
            guard let stringRange = Range(inline.range, in: blockText) else { return true }
            let charOffset = blockText.distance(from: blockText.startIndex, to: stringRange.lowerBound)
            let charLength = blockText.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
            guard charLength > 0 else { return true }
            let start = attributed.index(attributed.startIndex, offsetByCharacters: charOffset)
            let end = attributed.index(start, offsetByCharacters: charLength)
            #if DEBUG
            assert(String(attributed[start..<end].characters) == String(blockText[stringRange]),
                   "AttributedString character index 与 String character index 不一致")
            #endif
            attrRange = start..<end
        }

        switch inline.kind {
        case .bold:
            applyFontTrait(traitBold, to: attrRange, in: &attributed)

        case .italic:
            applyFontTrait(traitItalic, to: attrRange, in: &attributed)

        case .underline:
            #if canImport(UIKit)
            attributed[attrRange].uiKit.underlineStyle = .single
            #elseif canImport(AppKit)
            attributed[attrRange].appKit.underlineStyle = .single
            #endif

        case .strikethrough:
            #if canImport(UIKit)
            attributed[attrRange].uiKit.strikethroughStyle = .single
            #elseif canImport(AppKit)
            attributed[attrRange].appKit.strikethroughStyle = .single
            #endif

        case .code:
            #if canImport(UIKit)
            attributed[attrRange].uiKit.font = UIFont.monospacedSystemFont(
                ofSize: context.theme.baseFont.pointSize, weight: .regular
            )
            attributed[attrRange].uiKit.backgroundColor = UIColor.systemGray6
            #elseif canImport(AppKit)
            attributed[attrRange].appKit.font = NSFont.monospacedSystemFont(
                ofSize: context.theme.baseFont.pointSize, weight: .regular
            )
            attributed[attrRange].appKit.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2)
            #endif

        case .mark:
            #if canImport(UIKit)
            attributed[attrRange].uiKit.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
            #elseif canImport(AppKit)
            attributed[attrRange].appKit.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.3)
            #endif

        case .link(let url):
            #if canImport(UIKit)
            attributed[attrRange].uiKit.foregroundColor = .systemBlue
            #elseif canImport(AppKit)
            attributed[attrRange].appKit.foregroundColor = .linkColor
            #endif
            attributed[attrRange].link = URL(string: url)
            attributed[attrRange][XMarkupLinkURLKey.self] = url

        case .subscriptText:
            for run in attributed[attrRange].runs {
                #if canImport(UIKit)
                if let font = run.uiKit.font {
                    let smallFont = UIFont(descriptor: font.fontDescriptor, size: font.pointSize * 0.65)
                    attributed[run.range].uiKit.font = smallFont
                    attributed[run.range].uiKit.baselineOffset = -font.pointSize * 0.2
                }
                #elseif canImport(AppKit)
                let font = run.appKit.font ?? NSFont.systemFont(ofSize: 12)
                let smallFont = NSFont(descriptor: font.fontDescriptor, size: font.pointSize * 0.65)
                if let sf = smallFont { attributed[run.range].appKit.font = sf }
                attributed[run.range].appKit.baselineOffset = -font.pointSize * 0.2
                #endif
            }

        case .superscript:
            for run in attributed[attrRange].runs {
                #if canImport(UIKit)
                if let font = run.uiKit.font {
                    let smallFont = UIFont(descriptor: font.fontDescriptor, size: font.pointSize * 0.65)
                    attributed[run.range].uiKit.font = smallFont
                    attributed[run.range].uiKit.baselineOffset = font.pointSize * 0.35
                }
                #elseif canImport(AppKit)
                let font = run.appKit.font ?? NSFont.systemFont(ofSize: 12)
                let smallFont = NSFont(descriptor: font.fontDescriptor, size: font.pointSize * 0.65)
                if let sf = smallFont { attributed[run.range].appKit.font = sf }
                attributed[run.range].appKit.baselineOffset = font.pointSize * 0.35
                #endif
            }

        case .span(let styles):
            for style in styles {
                applyInlineStyle(style, to: attrRange, in: &attributed)
            }

        case .lineBreak:
            break  // <br> 已在文本中为 \n，无需额外样式处理
        }

        // 为所有内联元素设置自定义 tag
        let tagName = inlineKindName(for: inline.kind)
        attributed[attrRange][XMarkupTagKey.self] = tagName

        // 设置 inlinePresentationIntent 语义标注
        switch inline.kind {
        case .bold:
            attributed[attrRange].inlinePresentationIntent = .stronglyEmphasized
        case .italic:
            attributed[attrRange].inlinePresentationIntent = .emphasized
        case .code:
            attributed[attrRange].inlinePresentationIntent = .code
        case .strikethrough:
            attributed[attrRange].inlinePresentationIntent = .strikethrough
        default:
            break
        }

        return true
    }

    // MARK: - Font Trait

    private func applyFontTrait(
        _ trait: XMFontDescriptor.SymbolicTraits,
        to range: Range<AttributedString.Index>,
        in attributed: inout AttributedString
    ) {
        for run in attributed[range].runs {
            #if canImport(UIKit)
            if let font = run.uiKit.font {
                if trait == traitItalic {
                    var traits = font.fontDescriptor.symbolicTraits
                    traits.insert(traitItalic)
                    if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                        let italicFont = UIFont(descriptor: descriptor, size: font.pointSize)
                        if italicFont.fontDescriptor.symbolicTraits.contains(traitItalic),
                           italicFont.fontName != font.fontName {
                            attributed[run.range].uiKit.font = italicFont
                        } else {
                            attributed[run.range].uiKit.obliqueness = 0.25
                        }
                    } else {
                        attributed[run.range].uiKit.obliqueness = 0.25
                    }
                } else {
                    var traits = font.fontDescriptor.symbolicTraits
                    traits.insert(trait)
                    if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                        attributed[run.range].uiKit.font = UIFont(descriptor: descriptor, size: font.pointSize)
                    } else if trait == traitBold {
                        attributed[run.range].uiKit.font = UIFont.systemFont(ofSize: font.pointSize, weight: .bold)
                    }
                }
            } else if trait == traitItalic {
                attributed[run.range].uiKit.obliqueness = 0.25
            }
            #elseif canImport(AppKit)
            if let font = run.appKit.font {
                if trait == traitItalic {
                    var traits = font.fontDescriptor.symbolicTraits
                    traits.insert(traitItalic)
                    let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                    if let italicFont = NSFont(descriptor: descriptor, size: font.pointSize),
                       italicFont.fontDescriptor.symbolicTraits.contains(traitItalic),
                       italicFont.fontName != font.fontName {
                        attributed[run.range].appKit.font = italicFont
                    } else {
                        attributed[run.range].appKit.obliqueness = 0.25
                    }
                } else {
                    var traits = font.fontDescriptor.symbolicTraits
                    traits.insert(trait)
                    let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                    if let newFont = NSFont(descriptor: descriptor, size: font.pointSize) {
                        attributed[run.range].appKit.font = newFont
                    } else if trait == traitBold {
                        attributed[run.range].appKit.font = NSFont.boldSystemFont(ofSize: font.pointSize)
                    }
                }
            } else if trait == traitItalic {
                attributed[run.range].appKit.obliqueness = 0.25
            }
            #endif
        }
    }

    // MARK: - CSS Inline Styles

    private func applyInlineStyle(
        _ style: InlineStyle,
        to range: Range<AttributedString.Index>,
        in attributed: inout AttributedString
    ) {
        switch style {
        case .foregroundColor(let hex):
            if let color = ColorParser.parse(hex) {
                #if canImport(UIKit)
                attributed[range].uiKit.foregroundColor = color
                #elseif canImport(AppKit)
                attributed[range].appKit.foregroundColor = color
                #endif
            }
        case .backgroundColor(let hex):
            if let color = ColorParser.parse(hex) {
                #if canImport(UIKit)
                attributed[range].uiKit.backgroundColor = color
                #elseif canImport(AppKit)
                attributed[range].appKit.backgroundColor = color
                #endif
            }
        case .fontSize(let size):
            for run in attributed[range].runs {
                #if canImport(UIKit)
                if let font = run.uiKit.font {
                    let newFont = UIFont(descriptor: font.fontDescriptor, size: CGFloat(size))
                    attributed[run.range].uiKit.font = newFont
                }
                #elseif canImport(AppKit)
                if let font = run.appKit.font {
                    if let newFont = NSFont(descriptor: font.fontDescriptor, size: CGFloat(size)) {
                        attributed[run.range].appKit.font = newFont
                    }
                }
                #endif
            }
        case .fontStyle(let fontStyle):
            if fontStyle == "italic" {
                applyFontTrait(traitItalic, to: range, in: &attributed)
            }
        case .textDecoration(let decoration):
            if decoration == "underline" {
                #if canImport(UIKit)
                attributed[range].uiKit.underlineStyle = .single
                #elseif canImport(AppKit)
                attributed[range].appKit.underlineStyle = .single
                #endif
            } else if decoration == "line-through" {
                #if canImport(UIKit)
                attributed[range].uiKit.strikethroughStyle = .single
                #elseif canImport(AppKit)
                attributed[range].appKit.strikethroughStyle = .single
                #endif
            }
        case .fontWeight(let weight):
            for run in attributed[range].runs {
                #if canImport(UIKit)
                let currentFont = run.uiKit.font ?? UIFont.systemFont(ofSize: 16)
                if weight == "bold" || weight == "700" {
                    attributed[run.range].uiKit.font = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .bold)
                } else if weight == "normal" || weight == "400" {
                    attributed[run.range].uiKit.font = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .regular)
                } else if let w = Float(weight), w >= 600 {
                    attributed[run.range].uiKit.font = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .bold)
                } else if let w = Float(weight), w <= 300 {
                    attributed[run.range].uiKit.font = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .light)
                }
                #elseif canImport(AppKit)
                let currentFont = run.appKit.font ?? NSFont.systemFont(ofSize: 16)
                if weight == "bold" || weight == "700" {
                    attributed[run.range].appKit.font = NSFont.boldSystemFont(ofSize: currentFont.pointSize)
                } else if weight == "normal" || weight == "400" {
                    attributed[run.range].appKit.font = NSFont.systemFont(ofSize: currentFont.pointSize, weight: .regular)
                } else if let w = Float(weight), w >= 600 {
                    attributed[run.range].appKit.font = NSFont.boldSystemFont(ofSize: currentFont.pointSize)
                } else if let w = Float(weight), w <= 300 {
                    attributed[run.range].appKit.font = NSFont.systemFont(ofSize: currentFont.pointSize, weight: .light)
                }
                #endif
            }
        case .lineHeight(let height):
            for run in attributed[range].runs {
                #if canImport(UIKit)
                let paraStyle: NSMutableParagraphStyle
                if let existing = run.uiKit.paragraphStyle {
                    paraStyle = existing.mutableCopy() as! NSMutableParagraphStyle
                } else {
                    paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                }
                paraStyle.minimumLineHeight = CGFloat(height)
                attributed[run.range].uiKit.paragraphStyle = paraStyle
                #elseif canImport(AppKit)
                let paraStyle: NSMutableParagraphStyle
                if let existing = run.appKit.paragraphStyle {
                    paraStyle = existing.mutableCopy() as! NSMutableParagraphStyle
                } else {
                    paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                }
                paraStyle.minimumLineHeight = CGFloat(height)
                attributed[run.range].appKit.paragraphStyle = paraStyle
                #endif
            }
        case .letterSpacing(let spacing):
            #if canImport(UIKit)
            attributed[range].uiKit.kern = CGFloat(spacing)
            #elseif canImport(AppKit)
            attributed[range].appKit.kern = CGFloat(spacing)
            #endif
        case .textAlign(let alignment):
            for run in attributed[range].runs {
                #if canImport(UIKit)
                let paraStyle: NSMutableParagraphStyle
                if let existing = run.uiKit.paragraphStyle {
                    paraStyle = existing.mutableCopy() as! NSMutableParagraphStyle
                } else {
                    paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                }
                switch alignment {
                case "center": paraStyle.alignment = .center
                case "right": paraStyle.alignment = .right
                case "justify": paraStyle.alignment = .justified
                default: paraStyle.alignment = .left
                }
                attributed[run.range].uiKit.paragraphStyle = paraStyle
                #elseif canImport(AppKit)
                let paraStyle: NSMutableParagraphStyle
                if let existing = run.appKit.paragraphStyle {
                    paraStyle = existing.mutableCopy() as! NSMutableParagraphStyle
                } else {
                    paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                }
                switch alignment {
                case "center": paraStyle.alignment = .center
                case "right": paraStyle.alignment = .right
                case "justify": paraStyle.alignment = .justified
                default: paraStyle.alignment = .left
                }
                attributed[run.range].appKit.paragraphStyle = paraStyle
                #endif
            }
        }
    }
}
