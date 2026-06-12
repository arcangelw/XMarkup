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
/// 直接操作 NSMutableAttributedString，无需 AttributedString 桥接。
/// inline.range 是 TextRange，通过 .nsRange 桥接到 NSMutableAttributedString 的 range。
///
/// 所有 font 设置通过 `deriveFont` / `makeSyntheticItalicFont` 从当前字体派生，
/// 不使用硬编码系统字体，确保 trait 累积和 matrix 不丢失。
public struct DefaultInlineRenderer: InlineRendering, Sendable {
    public init() {}

    public func apply(inline: MarkupInline, to attributed: NSMutableAttributedString,
                      context: RenderingContext) -> Bool {
        let nsRange = inline.range.nsRange
        guard nsRange.length > 0,
              nsRange.upperBound <= attributed.length else { return true }

        switch inline.kind {
        case .bold:
            applyFontTrait(traitBold, to: nsRange, in: attributed, context: context)
            applyInlineTextTheme(context.theme.bold, to: nsRange, in: attributed, context: context)

        case .italic:
            applyFontTrait(traitItalic, to: nsRange, in: attributed, context: context)
            // 倾斜 matrix 使字形向右延伸，与下个字重叠，在末尾加 positive kern 补偿
            if nsRange.upperBound < attributed.length {
                let overlapKern = context.theme.baseFont.pointSize * 0.08
                attributed.addAttribute(.kern, value: overlapKern,
                                        range: NSRange(location: nsRange.upperBound - 1, length: 1))
            }
            applyInlineTextTheme(context.theme.italic, to: nsRange, in: attributed, context: context)

        case .underline:
            attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            applyInlineTextTheme(context.theme.underline, to: nsRange, in: attributed, context: context)

        case .strikethrough:
            attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: nsRange)
            applyInlineTextTheme(context.theme.strikethrough, to: nsRange, in: attributed, context: context)

        case .code:
            let codeTheme = context.theme.codeInline
            attributed.enumerateAttribute(.font, in: nsRange, options: []) { value, subrange, _ in
                let currentFont = value as? XMFont ?? context.theme.baseFont
                let codeFont: XMFont
                if let themeFont = codeTheme.font {
                    codeFont = themeFont
                } else {
                    let scale = codeTheme.sizeScale
                    if scale != 1.0 {
                        let scaledFont = deriveMonospacedFont(from: currentFont)
                        codeFont = deriveFont(from: scaledFont, size: currentFont.pointSize * scale)
                    } else {
                        codeFont = deriveMonospacedFont(from: currentFont)
                    }
                }
                attributed.addAttribute(.font, value: codeFont, range: subrange)
                // 背景色：只在没有已有 backgroundColor（如 mark/span 背景色）时才设置
                var effectiveRange = NSRange()
                let existing = attributed.attribute(.backgroundColor, at: subrange.location,
                                                    longestEffectiveRange: &effectiveRange, in: subrange)
                if existing == nil, let bg = codeTheme.backgroundColor {
                    attributed.addAttribute(.backgroundColor, value: bg, range: subrange)
                }
            }

        case .mark:
            let markTheme = context.theme.mark
            if let bg = markTheme.backgroundColor {
                attributed.addAttribute(.backgroundColor, value: bg, range: nsRange)
            }
            if let fg = markTheme.textColor {
                attributed.addAttribute(.foregroundColor, value: fg, range: nsRange)
            }

        case .link(let url):
            let linkTheme = context.theme.link
            #if canImport(UIKit)
            attributed.addAttribute(.foregroundColor, value: linkTheme.textColor ?? UIColor.systemBlue, range: nsRange)
            #elseif canImport(AppKit)
            attributed.addAttribute(.foregroundColor, value: linkTheme.textColor ?? NSColor.linkColor, range: nsRange)
            #endif
            if let ul = linkTheme.underlineStyle {
                attributed.addAttribute(.underlineStyle, value: ul.rawValue, range: nsRange)
            }
            if let linkURL = URL(string: url) {
                attributed.addAttribute(.link, value: linkURL, range: nsRange)
            }
            attributed.addAttribute(.xmarkupLinkURL, value: url, range: nsRange)

        case .subscriptText:
            let subTheme = context.theme.subscriptText
            attributed.enumerateAttribute(.font, in: nsRange, options: []) { value, subrange, _ in
                if let font = value as? XMFont {
                    let smallFont = deriveFont(from: font, size: font.pointSize * subTheme.fontScale)
                    attributed.addAttribute(.font, value: smallFont, range: subrange)
                    attributed.addAttribute(.baselineOffset, value: subTheme.baselineOffset, range: subrange)
                }
            }

        case .superscript:
            let supTheme = context.theme.superscript
            attributed.enumerateAttribute(.font, in: nsRange, options: []) { value, subrange, _ in
                if let font = value as? XMFont {
                    let smallFont = deriveFont(from: font, size: font.pointSize * supTheme.fontScale)
                    attributed.addAttribute(.font, value: smallFont, range: subrange)
                    attributed.addAttribute(.baselineOffset, value: supTheme.baselineOffset, range: subrange)
                }
            }

        case .span(let styles):
            for style in styles {
                applyInlineStyle(style, to: nsRange, in: attributed, context: context)
            }

        case .lineBreak:
            break  // <br> 已在文本中为 \n，无需额外样式处理
        }

        // xmarkupTag 语义：重叠 inline 场景下保留最内层（最后应用的）inline 类型。
        // 如需保留完整嵌套信息，使用 .inlinePresentationIntent（OptionSet 合并模式）。
        attributed.addAttribute(.xmarkupTag, value: inlineKindName(for: inline.kind), range: nsRange)

        // 设置 inlinePresentationIntent 语义标注（合并模式，支持 bold+italic 等重叠场景）
        if let intent = inlinePresentationIntent(for: inline.kind) {
            mergeInlinePresentationIntent(intent, into: nsRange, in: attributed)
        }

        return true
    }

    // MARK: - InlineTextTheme 应用

    /// 将 InlineTextTheme 的 textColor / backgroundColor / font / sizeScale 应用到 range
    ///
    /// 仅当各自属性非 nil / 非默认时才设置，避免覆盖已有属性。
    private func applyInlineTextTheme(
        _ theme: InlineTextTheme,
        to range: NSRange,
        in attributed: NSMutableAttributedString,
        context: RenderingContext
    ) {
        if let fg = theme.textColor {
            attributed.addAttribute(.foregroundColor, value: fg, range: range)
        }
        if let bg = theme.backgroundColor {
            // 只在没有已有背景色时才设置，避免覆盖嵌套内联的背景
            var effectiveRange = NSRange()
            let existing = attributed.attribute(.backgroundColor, at: range.location,
                                                longestEffectiveRange: &effectiveRange, in: range)
            if existing == nil {
                attributed.addAttribute(.backgroundColor, value: bg, range: range)
            }
        }
        if theme.sizeScale != 1.0 {
            attributed.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let currentFont = value as? XMFont ?? context.theme.baseFont
                attributed.addAttribute(.font,
                    value: deriveFont(from: currentFont, size: currentFont.pointSize * theme.sizeScale),
                    range: subrange)
            }
        }
        if let font = theme.font {
            attributed.addAttribute(.font, value: font, range: range)
        }
    }

    // MARK: - Font Trait

    /// 对指定 range 应用字体 trait（bold/italic）
    ///
    /// 始终从当前 font 的 descriptor 派生，保留 matrix/family/已有 traits 不丢失。
    /// italic 使用 makeSyntheticItalicFont（matrix 矩阵倾斜），中英文统一处理。
    ///
    /// - Note: makeSyntheticItalicFont 通过 CTFontCreateWithFontDescriptor 创建字体，
    ///   matrix 是渲染级参数，不存储在 fontDescriptor 中。后续 deriveFont 读取 descriptor.matrix
    ///   时得到 identity（b=0），会丢失斜体。此处非 italic 分支主动检测 CTFont 渲染级矩阵 并恢复。
    private func applyFontTrait(
        _ trait: XMFontDescriptor.SymbolicTraits,
        to range: NSRange,
        in attributed: NSMutableAttributedString,
        context: RenderingContext
    ) {
        let baseFont = context.theme.baseFont
        attributed.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let font = value as? XMFont ?? baseFont
            if trait == traitItalic {
                attributed.addAttribute(.font, value: makeSyntheticItalicFont(from: font), range: subrange)
            } else {
                attributed.addAttribute(.font, value: deriveFont(from: font, addTraits: trait), range: subrange)
            }
        }
    }

    // MARK: - CSS Inline Styles

    private func applyInlineStyle(
        _ style: InlineStyle,
        to range: NSRange,
        in attributed: NSMutableAttributedString,
        context: RenderingContext
    ) {
        let baseFont = context.theme.baseFont
        switch style {
        case .foregroundColor(let hex):
            if let color = ColorParser.parse(hex) {
                attributed.addAttribute(.foregroundColor, value: color, range: range)
            }

        case .backgroundColor(let hex):
            if let color = ColorParser.parse(hex) {
                attributed.addAttribute(.backgroundColor, value: color, range: range)
            }

        case .fontSize(let size):
            attributed.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let font = value as? XMFont ?? baseFont
                attributed.addAttribute(.font, value: deriveFont(from: font, size: CGFloat(size)), range: subrange)
            }

        case .fontStyle(let fontStyle):
            if fontStyle == "italic" {
                applyFontTrait(traitItalic, to: range, in: attributed, context: context)
                mergeInlinePresentationIntent(.emphasized, into: range, in: attributed)
            } else if fontStyle == "normal" {
                // 清除 italic matrix 倾斜
                attributed.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                    let currentFont = value as? XMFont ?? baseFont
                    attributed.addAttribute(.font, value: deriveFont(from: currentFont, clearMatrix: true), range: subrange)
                }
            }

        case .textDecoration(let decoration):
            if decoration == "underline" {
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else if decoration == "line-through" {
                attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                mergeInlinePresentationIntent(.strikethrough, into: range, in: attributed)
            }

        case .fontWeight(let weight):
            attributed.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let currentFont = value as? XMFont ?? baseFont
                let newFont: XMFont
                if weight == "bold" || weight == "700" {
                    newFont = deriveFont(from: currentFont, addTraits: traitBold)
                } else if weight == "normal" || weight == "400" {
                    newFont = deriveFont(from: currentFont, removeTraits: traitBold, weight: .regular)
                } else if let w = Float(weight), w >= 600 {
                    newFont = deriveFont(from: currentFont, addTraits: traitBold)
                } else if let w = Float(weight), w <= 300 {
                    newFont = deriveFont(from: currentFont, removeTraits: traitBold, weight: .light)
                } else {
                    return
                }
                attributed.addAttribute(.font, value: newFont, range: subrange)
            }
            // CSS fontWeight bold → 语义标注
            if weight == "bold" || weight == "700" || (Float(weight).map { $0 >= 600 } ?? false) {
                mergeInlinePresentationIntent(.stronglyEmphasized, into: range, in: attributed)
            }

        case .lineHeight(let height):
            attributed.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, subrange, _ in
                let paraStyle: NSMutableParagraphStyle
                if let existing = value as? NSParagraphStyle {
                    paraStyle = existing.mutableCopy() as! NSMutableParagraphStyle
                } else {
                    paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                }
                paraStyle.minimumLineHeight = CGFloat(height)
                attributed.addAttribute(.paragraphStyle, value: paraStyle, range: subrange)
            }

        case .letterSpacing(let spacing):
            attributed.addAttribute(.kern, value: CGFloat(spacing), range: range)

        case .textAlign(let alignment):
            attributed.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, subrange, _ in
                let paraStyle: NSMutableParagraphStyle
                if let existing = value as? NSParagraphStyle {
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
                attributed.addAttribute(.paragraphStyle, value: paraStyle, range: subrange)
            }
        }
    }

    // MARK: - InlinePresentationIntent Helpers

    /// 将 InlineKind 映射到 InlinePresentationIntent 语义标注
    ///
    /// 所有 case 显式列出，新增 InlineKind 时编译器会提醒补全。
    /// 无直接对应的 case（underline/mark/link/subscriptText/superscript）返回 nil，
    /// span 的语义标注在 applyInlineStyle 中按 CSS 属性单独处理。
    private func inlinePresentationIntent(for kind: InlineKind) -> InlinePresentationIntent? {
        switch kind {
        case .bold:           return .stronglyEmphasized
        case .italic:         return .emphasized
        case .underline:      return nil   // 无直接对应（Apple 未提供 underline intent）
        case .strikethrough:  return .strikethrough
        case .code:           return .code
        case .mark:           return nil   // 无直接对应
        case .link:           return nil   // 链接语义通过 attributed[range].link 属性表达
        case .subscriptText:  return nil   // 无直接对应
        case .superscript:    return nil   // 无直接对应
        case .span:           return nil   // 语义标注在 applyInlineStyle 中按 CSS 属性单独合并
        case .lineBreak:      return .lineBreak
        }
    }

    /// 合并 InlinePresentationIntent（支持 bold+italic 等重叠场景）
    ///
    /// 读取 range 内每个 run 的现有 intent，用 OptionSet 合并后写回，
    /// 避免直接赋值覆盖之前 inline 已设置的语义标注。
    private func mergeInlinePresentationIntent(
        _ newIntent: InlinePresentationIntent,
        into range: NSRange,
        in attributed: NSMutableAttributedString
    ) {
        attributed.enumerateAttribute(.inlinePresentationIntent, in: range, options: []) { value, subrange, _ in
            let existing = value as? InlinePresentationIntent ?? []
            attributed.addAttribute(.inlinePresentationIntent, value: existing.union(newIntent), range: subrange)
        }
    }
}
