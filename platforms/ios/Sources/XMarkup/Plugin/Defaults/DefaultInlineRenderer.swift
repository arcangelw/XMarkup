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
///
/// 所有 font 设置通过 `deriveFont` / `makeSyntheticItalicFont` 从当前字体派生，
/// 不使用硬编码系统字体，确保 trait 累积和 matrix 不丢失。
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
            applyFontTrait(traitBold, to: attrRange, in: &attributed, context: context)

        case .italic:
            applyFontTrait(traitItalic, to: attrRange, in: &attributed, context: context)

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
            // 从 typed theme 读取字体和背景色，fallback 从 baseFont 派生等宽字体
            let codeTheme = context.theme.codeInline
            #if canImport(UIKit)
            attributed[attrRange].uiKit.font = codeTheme.font
                ?? UIFont.monospacedSystemFont(ofSize: context.theme.baseFont.pointSize, weight: .regular)
            attributed[attrRange].uiKit.backgroundColor = codeTheme.backgroundColor ?? UIColor.systemGray6
            #elseif canImport(AppKit)
            attributed[attrRange].appKit.font = codeTheme.font
                ?? NSFont.monospacedSystemFont(ofSize: context.theme.baseFont.pointSize, weight: .regular)
            attributed[attrRange].appKit.backgroundColor = codeTheme.backgroundColor
                ?? NSColor.systemGray.withAlphaComponent(0.2)
            #endif

        case .mark:
            // 从 typed theme 读取背景色，fallback 到系统黄色
            let markTheme = context.theme.mark
            #if canImport(UIKit)
            attributed[attrRange].uiKit.backgroundColor = markTheme.backgroundColor
                ?? UIColor.systemYellow.withAlphaComponent(0.3)
            #elseif canImport(AppKit)
            attributed[attrRange].appKit.backgroundColor = markTheme.backgroundColor
                ?? NSColor.systemYellow.withAlphaComponent(0.3)
            #endif

        case .link(let url):
            // 从 typed theme 读取文字颜色，fallback 到系统链接色
            let linkTheme = context.theme.link
            #if canImport(UIKit)
            attributed[attrRange].uiKit.foregroundColor = linkTheme.textColor ?? .systemBlue
            #elseif canImport(AppKit)
            attributed[attrRange].appKit.foregroundColor = linkTheme.textColor ?? .linkColor
            #endif
            attributed[attrRange].link = URL(string: url)
            attributed[attrRange][XMarkupLinkURLKey.self] = url

        case .subscriptText:
            for run in attributed[attrRange].runs {
                #if canImport(UIKit)
                if let font = run.uiKit.font {
                    let smallFont = deriveFont(from: font, size: font.pointSize * 0.65)
                    attributed[run.range].uiKit.font = smallFont
                    attributed[run.range].uiKit.baselineOffset = -font.pointSize * 0.2
                }
                #elseif canImport(AppKit)
                let font = run.appKit.font ?? context.theme.baseFont
                let smallFont = deriveFont(from: font, size: font.pointSize * 0.65)
                attributed[run.range].appKit.font = smallFont
                attributed[run.range].appKit.baselineOffset = -font.pointSize * 0.2
                #endif
            }

        case .superscript:
            for run in attributed[attrRange].runs {
                #if canImport(UIKit)
                if let font = run.uiKit.font {
                    let smallFont = deriveFont(from: font, size: font.pointSize * 0.65)
                    attributed[run.range].uiKit.font = smallFont
                    attributed[run.range].uiKit.baselineOffset = font.pointSize * 0.35
                }
                #elseif canImport(AppKit)
                let font = run.appKit.font ?? context.theme.baseFont
                let smallFont = deriveFont(from: font, size: font.pointSize * 0.65)
                attributed[run.range].appKit.font = smallFont
                attributed[run.range].appKit.baselineOffset = font.pointSize * 0.35
                #endif
            }

        case .span(let styles):
            for style in styles {
                applyInlineStyle(style, to: attrRange, in: &attributed, context: context)
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

    /// 对指定 range 应用字体 trait（bold/italic）
    ///
    /// 始终从当前 font 的 descriptor 派生，保留 matrix/family/已有 traits 不丢失。
    /// italic 统一使用 makeSyntheticItalicFont（矩阵合成），确保中英文行为一致。
    private func applyFontTrait(
        _ trait: XMFontDescriptor.SymbolicTraits,
        to range: Range<AttributedString.Index>,
        in attributed: inout AttributedString,
        context: RenderingContext
    ) {
        let baseFont = context.theme.baseFont
        for run in attributed[range].runs {
            #if canImport(UIKit)
            let font = run.uiKit.font ?? baseFont
            if trait == traitItalic {
                attributed[run.range].uiKit.font = makeSyntheticItalicFont(from: font)
            } else {
                attributed[run.range].uiKit.font = deriveFont(from: font, addTraits: trait)
            }
            #elseif canImport(AppKit)
            let font = run.appKit.font ?? baseFont
            if trait == traitItalic {
                attributed[run.range].appKit.font = makeSyntheticItalicFont(from: font)
            } else {
                attributed[run.range].appKit.font = deriveFont(from: font, addTraits: trait)
            }
            #endif
        }
    }

    // MARK: - CSS Inline Styles

    private func applyInlineStyle(
        _ style: InlineStyle,
        to range: Range<AttributedString.Index>,
        in attributed: inout AttributedString,
        context: RenderingContext
    ) {
        let baseFont = context.theme.baseFont
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
                let font = run.uiKit.font ?? baseFont
                attributed[run.range].uiKit.font = deriveFont(from: font, size: CGFloat(size))
                #elseif canImport(AppKit)
                let font = run.appKit.font ?? baseFont
                attributed[run.range].appKit.font = deriveFont(from: font, size: CGFloat(size))
                #endif
            }
        case .fontStyle(let fontStyle):
            if fontStyle == "italic" {
                applyFontTrait(traitItalic, to: range, in: &attributed, context: context)
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
                let currentFont = run.uiKit.font ?? baseFont
                #elseif canImport(AppKit)
                let currentFont = run.appKit.font ?? baseFont
                #endif
                let newFont: XMFont
                if weight == "bold" || weight == "700" {
                    newFont = deriveFont(from: currentFont, addTraits: traitBold)
                } else if weight == "normal" || weight == "400" {
                    newFont = deriveFont(from: currentFont, weight: .regular)
                } else if let w = Float(weight), w >= 600 {
                    newFont = deriveFont(from: currentFont, addTraits: traitBold)
                } else if let w = Float(weight), w <= 300 {
                    newFont = deriveFont(from: currentFont, weight: .light)
                } else {
                    continue
                }
                #if canImport(UIKit)
                attributed[run.range].uiKit.font = newFont
                #elseif canImport(AppKit)
                attributed[run.range].appKit.font = newFont
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
