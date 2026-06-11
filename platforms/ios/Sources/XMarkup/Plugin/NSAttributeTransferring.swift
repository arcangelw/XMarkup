import Foundation

/// 桥接 key 转移插件 — 将 AttributedString 中的自定义 key 转移到 NSAttributedString
///
/// 在 RenderPipeline 的标准 NS 转换之后、NS 增强之前执行。
/// 默认实现 `XMarkupKeyTransfer` 转移 XMarkup 内置的自定义 key
///（`XMarkupTagKey`、`XMarkupBlockKindKey` 等）。
///
/// 用户可通过 `RenderPipeline.addingKeyTransfers()` 追加自定义转移逻辑：
///
/// ```swift
/// let pipeline = RenderPipeline.default.addingKeyTransfers([MyCustomKeyTransfer()])
/// ```
public protocol NSAttributeTransferring: Sendable {
    /// 将 AttributedString 中的自定义属性转移到 NSMutableAttributedString
    ///
    /// - Parameters:
    ///   - attributed: 原始 AttributedString（含自定义 key）
    ///   - nsAttr: 标准 NS 转换后的 NSMutableAttributedString
    ///   - context: 渲染上下文
    func transfer(
        from attributed: AttributedString,
        to nsAttr: NSMutableAttributedString,
        context: RenderingContext
    )
}
