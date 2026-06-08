import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// NSAttributedString 便利层：span→attribute 映射
extension XMarkupResult {

    /// 将解析结果转换为 NSAttributedString
    ///
    /// 使用方式：
    /// ```swift
    /// let result = try parser.parse("<b>Hello</b> <i style=\"color:#FF0000\">World</i>")
    /// let attributed = result.makeAttributedString(baseFont: UIFont.systemFont(ofSize: 14))
    /// // attributed 可直接用于 UILabel.attributedText / NSTextField.attributedStringValue
    /// ```
    ///
    /// - Parameter baseFont: 基础字体，nil 时使用 systemFont(ofSize: 16)
    /// - Returns: 带样式的 NSAttributedString
    public func makeAttributedString(baseFont: XMFont? = nil) -> NSAttributedString {
        let base = baseFont ?? XMFont.systemFont(ofSize: 16)

        guard !text.isEmpty else {
            return NSAttributedString(string: "")
        }

        let str = NSMutableAttributedString(string: text, attributes: [.font: base])

        // 第一趟：合并字体属性
        for span in spans {
            applyFontAttributes(span, baseFontSize: base.pointSize, to: str)
        }

        // 第二趟：非字体属性
        for span in spans {
            applyNonFontAttributes(span, to: str)
        }

        return NSAttributedString(attributedString: str)
    }

    // MARK: - Private

    /// 第一趟：处理字体相关属性（合并 trait 而非覆盖）
    private func applyFontAttributes(_ span: XMarkupSpan, baseFontSize: CGFloat,
                                     to string: NSMutableAttributedString) {
        let range = span.range

        switch span.tag {
        case .bold:
            addFontTrait(boldTrait, to: range, in: string)
        case .italic:
            addFontTrait(italicTrait, to: range, in: string)
        case .heading1:
            applyHeadingFont(scale: 2.0, to: range, in: string)
        case .heading2:
            applyHeadingFont(scale: 1.5, to: range, in: string)
        case .heading3:
            applyHeadingFont(scale: 1.17, to: range, in: string)
        case .heading4:
            applyHeadingFont(scale: 1.0, to: range, in: string)
        case .heading5:
            applyHeadingFont(scale: 0.83, to: range, in: string)
        case .heading6:
            applyHeadingFont(scale: 0.67, to: range, in: string)
        case .code:
            applyCodeFont(to: range, in: string)
        default:
            break
        }

        // CSS fontSize
        if span.style == .fontSize, let value = span.value, let size = Float(value) {
            applyFontSize(CGFloat(size), to: range, in: string)
        }
    }

    /// 第二趟：处理非字体属性
    private func applyNonFontAttributes(_ span: XMarkupSpan, to string: NSMutableAttributedString) {
        let range = span.range

        switch span.tag {
        case .underline:
            string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .strikethrough:
            string.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .link:
            if let url = span.value {
                string.addAttribute(.link, value: url, range: range)
            }
        default:
            break
        }

        switch span.style {
        case .foregroundColor:
            if let color = ColorParser.parse(span.value) {
                string.addAttribute(.foregroundColor, value: color, range: range)
            }
        case .backgroundColor:
            if let color = ColorParser.parse(span.value) {
                string.addAttribute(.backgroundColor, value: color, range: range)
            }
        default:
            break
        }
    }

    /// 向指定范围追加字体 trait（合并而非覆盖）
    ///
    /// 处理 <b><i>text</i></b> 场景：先应用 BOLD trait，
    /// 再在同一范围应用 ITALIC trait，最终得到 Bold-Italic 字体。
    private func addFontTrait(_ trait: XMFontDescriptor.SymbolicTraits,
                              to range: NSRange,
                              in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            #if canImport(UIKit)
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits),
                  let newFont = XMFont(descriptor: descriptor, size: font.pointSize) else { return }
            #elseif canImport(AppKit)
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            guard let newFont = XMFont(descriptor: descriptor, size: font.pointSize) else { return }
            #endif
            string.addAttribute(.font, value: newFont, range: attrRange)
        }
    }

    /// 应用 heading 字体（放大 + 加粗）
    private func applyHeadingFont(scale: CGFloat, to range: NSRange,
                                  in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            let newSize = font.pointSize * scale
            #if canImport(UIKit)
            guard let desc = font.fontDescriptor.withSymbolicTraits(boldTrait),
                  let newFont = XMFont(descriptor: desc, size: newSize) else { return }
            #elseif canImport(AppKit)
            let desc = font.fontDescriptor.withSymbolicTraits(boldTrait)
            guard let newFont = XMFont(descriptor: desc, size: newSize) else { return }
            #endif
            string.addAttribute(.font, value: newFont, range: attrRange)
        }
    }

    /// 应用等宽字体（用于 <code>）
    private func applyCodeFont(to range: NSRange, in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            #if canImport(UIKit)
            let monoFont = UIFont(name: "Menlo", size: font.pointSize)
                ?? UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            #elseif canImport(AppKit)
            let monoFont = NSFont(name: "Menlo", size: font.pointSize)
                ?? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            #endif
            string.addAttribute(.font, value: monoFont, range: attrRange)
        }
    }

    /// 应用 CSS 指定字号
    private func applyFontSize(_ size: CGFloat, to range: NSRange,
                               in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            let descriptor = font.fontDescriptor
            if let newFont = XMFont(descriptor: descriptor, size: size) {
                string.addAttribute(.font, value: newFont, range: attrRange)
            }
        }
    }
}

// MARK: - 跨平台字体 Trait 常量

#if canImport(UIKit)
private let boldTrait: UIFontDescriptor.SymbolicTraits = .traitBold
private let italicTrait: UIFontDescriptor.SymbolicTraits = .traitItalic
#elseif canImport(AppKit)
private let boldTrait: NSFontDescriptor.SymbolicTraits = .bold
private let italicTrait: NSFontDescriptor.SymbolicTraits = .italic
#endif
