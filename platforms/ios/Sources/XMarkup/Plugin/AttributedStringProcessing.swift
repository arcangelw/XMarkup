import Foundation

/// AttributedString 后处理器 — 在所有 block 渲染完成后对整体结果做后处理
///
/// 用于全局性的文本变换，如段落间距调整、自定义属性注入等。
/// 按注册顺序依次执行。
public protocol AttributedStringProcessing: Sendable {
    /// 处理完整的 AttributedString
    ///
    /// - Parameters:
    ///   - attributed: 所有块渲染并合并后的 AttributedString
    ///   - context: 渲染上下文
    /// - Returns: 处理后的 AttributedString
    func process(_ attributed: AttributedString, context: RenderingContext) -> AttributedString
}
