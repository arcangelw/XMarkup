import Foundation
import XMarkup

#if canImport(UIKit) && !os(macOS)
import UIKit

/// 自定义 NSLayoutManager，在背景绘制 blockquote 左侧竖线
///
/// 在 `drawBackground(forGlyphRange:at:)` 中按段落检测 `XMarkupBlockKindKey = "blockquote"`，
/// 使用 `enumerateLineFragments` 逐行精确绘制连贯竖线。
///
/// - Note: 避免使用新版 SDK 中已被同名属性遮蔽的 `characterRange`/`glyphRange` 方法，
///         改用 `glyphIndexForCharacter(at:)` + `enumerateLineFragments` 实现。
class BlockquoteLayoutManager: NSLayoutManager {
    /// 关联的 UI 配置（XMarkupViewConfig 为值类型，由调用方持有）
    var markupConfig: XMarkupViewConfig?

    override func drawBackground(forGlyphRange glyphRange: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphRange, at: origin)
        guard let config = markupConfig,
              let textStorage else { return }

        let key = NSAttributedString.Key.xmarkupBlockKind
        let fullCharRange = NSRange(location: 0, length: textStorage.length)

        // 逐 blockquote 段落绘制竖线
        textStorage.enumerateAttribute(key, in: fullCharRange) { value, charRange, _ in
            guard (value as? String) == "blockquote" else { return }

            // 精确计算 blockquote 的完整 glyph 范围
            let startGlyph = self.glyphIndexForCharacter(at: charRange.location)
            guard startGlyph != NSNotFound else { return }

            let endGlyph: Int
            if charRange.length > 0 {
                endGlyph = self.glyphIndexForCharacter(at: charRange.location + charRange.length - 1)
                guard endGlyph != NSNotFound else { return }
            } else {
                endGlyph = startGlyph
            }
            guard endGlyph >= startGlyph else { return }

            let bqGlyphRange = NSRange(location: startGlyph, length: endGlyph - startGlyph + 1)

            // 检查 bqGlyphRange 与可视 glyphRange 是否有交集
            // 避免滚动到 blockquote 中间时竖线消失
            let visibleRange = NSIntersectionRange(bqGlyphRange, glyphRange)
            guard visibleRange.length > 0 else { return }

            // 逐行绘制竖线 — 精确匹配每行片段
            config.blockquoteBorderColor.setFill()
            self.enumerateLineFragments(forGlyphRange: bqGlyphRange) { rect, _, _, _, _ in
                let borderX = rect.minX + origin.x + config.blockquoteBorderOffset
                let borderRect = CGRect(
                    x: borderX,
                    y: rect.minY + origin.y,
                    width: config.blockquoteBorderWidth,
                    height: rect.height
                )
                UIRectFill(borderRect)
            }
        }
    }
}

#endif
