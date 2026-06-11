import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// AttributedString → NSAttributedString 标准桥接工具
///
/// 提供标准转换和尺寸测量功能。自定义 key 的转移由 Pipeline 的
/// `keyTransfers` 阶段处理（默认使用 `XMarkupKeyTransfer`）。
///
/// - Note: 直接使用此类时不会转移 XMarkup 自定义 key。
///         如需完整渲染流程（含 key 转移），请使用 `RenderPipeline.render()`。
public struct NSAttributedStringRenderer: Sendable {
    public init() {}

    /// 标准转换：AttributedString → NSAttributedString
    ///
    /// - Note: 此方法仅做标准类型转换，不转移自定义 XMarkup key。
    ///         自定义 key 转移由 `XMarkupKeyTransfer` 在 Pipeline 中执行。
    public func render(_ attributed: AttributedString) -> NSAttributedString {
        NSAttributedString(attributed)
    }

    /// 测量 AttributedString 在指定宽度下的渲染尺寸
    ///
    /// 先转换为 NSAttributedString，再使用 `boundingRect` 计算尺寸。
    /// 结果向上取整。
    public func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize {
        let nsAttr = render(attributed)
        let size = nsAttr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}
