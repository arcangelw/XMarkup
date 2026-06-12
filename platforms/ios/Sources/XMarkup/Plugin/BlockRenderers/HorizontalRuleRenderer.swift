import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 水平线渲染器 — 处理 hr 的 NSTextAttachment 创建
///
/// 创建 300pt 宽的 1px 线条附件，容器宽度自适应由 UI 层
/// HorizontalRuleUpdater 在布局时完成。
///
/// - Note: 返回长度为 1 的附件字符（\u{FFFC}），与 block.text 长度无关。
///   管线不对 HR 块调度 inline renderer，因此 inline range 越界不存在风险。
public struct HorizontalRuleRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> NSMutableAttributedString? {
        guard case .horizontalRule = block.kind else { return nil }

        let theme = context.theme

        let attachment = NSTextAttachment()
        let lineWidth: CGFloat = 300
        let lineHeight: CGFloat = 1

        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: lineWidth, height: lineHeight))
        let lineColor = theme.horizontalRule.color ?? UIColor.separator
        attachment.image = renderer.image { ctx in
            lineColor.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: lineWidth, height: lineHeight))
        }
        #elseif canImport(AppKit)
        let image = NSImage(size: NSSize(width: lineWidth, height: lineHeight))
        let lineColor = theme.horizontalRule.color ?? NSColor.separatorColor
        image.lockFocus()
        lineColor.setFill()
        NSRect(x: 0, y: 0, width: lineWidth, height: lineHeight).fill()
        image.unlockFocus()
        attachment.image = image
        #endif

        attachment.bounds = CGRect(x: 0, y: 0, width: lineWidth, height: lineHeight)

        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle(),
                            range: NSRange(location: 0, length: result.length))
        result.addAttribute(.xmarkupBlockKind, value: "horizontalRule",
                            range: NSRange(location: 0, length: result.length))
        return result
    }
}
