import Foundation

/// 可插拔的渲染器协议
///
/// 所有渲染器消费 AttributedString（可能携带自定义 XMarkupScope 属性），
/// 而非自定义类型。第三方库通过 `NSAttributedString(AttributedString)` 桥接后
/// 读取标准属性 + 自定义 XMarkup key。
///
/// 使用方式：
/// ```swift
/// let attributed = document.render()
///
/// // UIKit/AppKit 渲染
/// let nsRenderer = NSAttributedStringRenderer()
/// let nsAttr = nsRenderer.render(attributed)
/// textView.attributedText = nsAttr
///
/// // 测量尺寸
/// let size = nsRenderer.measure(attributed, constrainedTo: 320)
/// ```
public protocol MarkupRenderer<Output>: Sendable {
    associatedtype Output

    /// 渲染
    func render(_ attributed: AttributedString) -> Output

    /// 测量内容尺寸（用于布局计算）
    func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize
}
