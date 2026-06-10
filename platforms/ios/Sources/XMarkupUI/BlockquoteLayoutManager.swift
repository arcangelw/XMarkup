import Foundation
import XMarkup

#if canImport(UIKit) && !os(macOS)
import UIKit

/// 自定义 NSLayoutManager，在背景绘制 blockquote 左侧竖线
///
/// 在 `drawBackground(forGlyphRange:at:)` 中按行片段检测 `XMarkupBlockKindKey = "blockquote"`，
/// 在连续 blockquote 段落左侧绘制连贯竖线。
///
/// - Note: 避免使用新版 SDK 中已被同名属性遮蔽的 `characterRange`/`glyphRange` 方法，
///         改用 `enumerateLineFragments` + `glyphIndexForCharacter(at:)` 实现。
class BlockquoteLayoutManager: NSLayoutManager {
    /// 关联的 UI 配置（XMarkupViewConfig 为值类型，由调用方持有）
    var markupConfig: XMarkupViewConfig?

    override func drawBackground(forGlyphRange glyphRange: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphRange, at: origin)
        guard let config = markupConfig,
              let textStorage,
              let container = textContainers.first else { return }

        let key = NSAttributedString.Key(XMarkupBlockKindKey.name)
        let fullCharRange = NSRange(location: 0, length: textStorage.length)

        // 逐 blockquote 段落绘制竖线
        textStorage.enumerateAttribute(key, in: fullCharRange) { value, subrange, _ in
            guard (value as? String) == "blockquote" else { return }

            // 使用 glyphIndexForCharacter 获取起始 glyph
            let startGlyph = self.glyphIndexForCharacter(at: subrange.location)
            guard startGlyph != NSNotFound,
                  NSLocationInRange(startGlyph, glyphRange) else { return }

            // 用 lineFragmentRect 获取首行位置
            let firstLineRect = self.lineFragmentRect(forGlyphAt: startGlyph,
                                                       effectiveRange: nil)
            // 估算段落的完整竖直范围：从首行顶部到末行底部
            // boundingRect 需要合法的 glyph 范围
            let paraEndGlyph = min(startGlyph + subrange.length * 2, glyphRange.upperBound - 1)
            let safeGlyphRange = NSRange(
                location: max(glyphRange.location, startGlyph),
                length: max(1, min(paraEndGlyph - startGlyph,
                                    glyphRange.length - (startGlyph - glyphRange.location)))
            )
            let boundingRect = self.boundingRect(forGlyphRange: safeGlyphRange, in: container)

            let borderX = firstLineRect.minX + origin.x + config.blockquoteBorderOffset
            let borderRect = CGRect(
                x: borderX,
                y: boundingRect.minY + origin.y,
                width: config.blockquoteBorderWidth,
                height: max(boundingRect.height, firstLineRect.height)
            )

            config.blockquoteBorderColor.setFill()
            UIRectFill(borderRect)
        }
    }
}

#endif
