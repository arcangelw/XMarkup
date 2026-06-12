import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import XMarkup

/// hr 分隔线自适应宽度更新器
///
/// 在布局完成后调用，将 hr 的 NSTextAttachment.bounds.width 更新为容器宽度。
/// 由 XMarkupTextView 的布局周期自动触发，也可手动调用。
enum HorizontalRuleUpdater {

    /// 更新所有 hr attachment 的宽度为容器宽度
    /// - Parameters:
    ///   - textStorage: 文本存储对象（NSTextStorage 或 NSMutableAttributedString）
    ///   - containerWidth: 容器当前宽度
    ///   - minWidth: 最小宽度下限
    static func update(
        in textStorage: NSMutableAttributedString,
        containerWidth: CGFloat,
        minWidth: CGFloat = 100
    ) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let blockKindKey = NSAttributedString.Key.xmarkupBlockKind
        textStorage.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let attachment = value as? NSTextAttachment,
                  let kind = textStorage.attribute(blockKindKey, at: range.location, effectiveRange: nil) as? String,
                  kind == "horizontalRule" else { return }
            attachment.bounds.size.width = max(containerWidth, minWidth)
        }
    }
}
