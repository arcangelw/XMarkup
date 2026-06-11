import Foundation

/// 渲染上下文 — 在整个渲染管线中传递
///
/// 携带当前渲染所需的所有上下文信息，供 Theme resolve 闭包和 Renderer 插件使用。
public struct RenderingContext: @unchecked Sendable {
    /// 当前主题配置
    public let theme: MarkupTheme
    /// 当前块在文档中的位置（0-based）
    public let blockIndex: Int
    /// 文档总块数
    public let totalBlocks: Int
    /// 插件间共享状态（如 NSTextList 实例等）
    public var sharedState: [String: Any]

    public init(theme: MarkupTheme, blockIndex: Int = 0, totalBlocks: Int = 0) {
        self.theme = theme
        self.blockIndex = blockIndex
        self.totalBlocks = totalBlocks
        self.sharedState = [:]
    }
}
