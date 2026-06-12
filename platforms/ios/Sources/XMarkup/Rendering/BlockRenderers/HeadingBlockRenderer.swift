import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 标题块渲染器 — 处理 h1~h6 的字体、字号、间距
///
/// 通过 `theme.heading.resolved()` 消费三级精度配置：
/// base → per-level override → 动态 resolve 闭包。
public struct HeadingBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> NSMutableAttributedString? {
        guard case .heading(let level) = block.kind else { return nil }

        let theme = context.theme
        let baseFont = theme.baseFont

        // 标题间距：按级别递增（h1 间距最大，h6 最小）
        let spacingScale: CGFloat
        switch level {
        case .h1: spacingScale = 0.50
        case .h2: spacingScale = 0.60
        case .h3: spacingScale = 0.70
        case .h4: spacingScale = 0.80
        case .h5: spacingScale = 0.90
        case .h6: spacingScale = 1.00
        }
        let paragraphStyle = NSMutableParagraphStyle()
        let headingSpacing = baseFont.pointSize * spacingScale
        paragraphStyle.paragraphSpacingBefore = headingSpacing
        paragraphStyle.paragraphSpacing = headingSpacing * 0.5

        var attributes: [NSAttributedString.Key: Any] = [:]
        if let resolved = theme.heading.resolved(for: block, baseFont: baseFont, context: context) {
            let fontSize = resolved.fontSize
            if resolved.bold {
                attributes[.font] = deriveFont(from: baseFont, addTraits: traitBold, size: fontSize)
            } else {
                attributes[.font] = baseFont.withSize(fontSize)
            }
            if let textColor = resolved.textColor {
                attributes[.foregroundColor] = textColor
            }
        } else {
            // 兜底：resolved 返回 nil 时仍需设置 font，避免回退到系统 12pt 默认字体
            attributes[.font] = deriveFont(from: baseFont, addTraits: traitBold)
        }
        attributes[.paragraphStyle] = paragraphStyle

        // 自定义 key
        let blockKindName = blockKindName(for: block.kind)
        attributes[.xmarkupTag] = blockKindName
        attributes[.xmarkupBlockKind] = blockKindName
        attributes[.xmarkupHeadingLevel] = level.rawValue

        return NSMutableAttributedString(string: block.text, attributes: attributes)
    }
}
