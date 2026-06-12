import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 列表上下文（类型安全的 sharedState 替代）
///
/// - Note: `@unchecked Sendable` 因持有 `NSTextList`（非 Sendable 引用类型），
///   值语义保证每个块渲染迭代创建独立副本。
public struct ListContext: @unchecked Sendable, Equatable {
    /// 共享的 NSTextList 实例（同一组列表项自动编号）
    public var textLists: [NSTextList]
    /// 是否为列表组第一项（控制段落间距）
    public var isFirstInGroup: Bool
    /// 是否为列表组最后一项（控制段落间距）
    public var isLastInGroup: Bool
    /// 有序列表项在组内的序号（1-based），非 nil 时使用手动标记渲染
    public var orderedItemIndex: Int?

    public init(textLists: [NSTextList], isFirstInGroup: Bool = false, isLastInGroup: Bool = false, orderedItemIndex: Int? = nil) {
        self.textLists = textLists
        self.isFirstInGroup = isFirstInGroup
        self.isLastInGroup = isLastInGroup
        self.orderedItemIndex = orderedItemIndex
    }
}

/// 渲染上下文 — 在整个渲染管线中传递
///
/// 携带当前渲染所需的所有上下文信息，供 Theme resolve 闭包和 Renderer 插件使用。
///
/// - Note: `@unchecked Sendable` 因为 `sharedState` 使用 `[String: Any]` 类型（编译器无法推断 Sendable）。
///   实际存储的值包括 `NSTextList`（引用类型），通过结构体值语义在每个块渲染迭代中创建独立副本，并发访问安全。
///   `listContext` 字段是类型安全的替代，优先使用。
public struct RenderingContext: @unchecked Sendable {
    /// 当前主题配置
    public let theme: MarkupTheme
    /// 当前块在文档中的位置（0-based）
    ///
    /// - Note: enhancer 阶段（Phase 3）传入 `-1`，表示全局上下文而非单块渲染。
    public let blockIndex: Int
    /// 文档总块数
    public let totalBlocks: Int
    /// 列表上下文（类型安全，优先使用）
    public var listContext: ListContext?
    /// 插件间共享状态（[String: Any]，仅用于自定义插件间通信）
    public var sharedState: [String: Any]
    /// 块渲染器在文本前插入的标记前缀 UTF-16 长度（如 "1.\t" = 3）
    /// 管线据此自动偏移 inline 范围，无需启发式检测
    public var textPrefixLength: Int = 0

    public init(theme: MarkupTheme, blockIndex: Int = 0, totalBlocks: Int = 0) {
        self.theme = theme
        self.blockIndex = blockIndex
        self.totalBlocks = totalBlocks
        self.listContext = nil
        self.sharedState = [:]
    }
}
