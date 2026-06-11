import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 标题主题配置
///
/// 三级精度：
/// 1. 基础默认 — 所有 heading 共用
/// 2. 逐级别覆盖 — h1/h2/... 各级别独有的属性
/// 3. 动态 resolve — 基于 block 内容/上下文运行时精确覆盖
///
/// ```swift
/// Heading {
///     $0.scale = HeadingScale(h1: 2.0, h2: 1.5, h3: 1.17)
///     $0.bold = true
///     $0.h1 = .init(textColor: .primary, spacingBefore: 24)
///     $0.resolve = { block, context, defaults in
///         if block.text.hasPrefix("⚠️") {
///             return defaults.with(\.textColor, .systemRed)
///         }
///         return nil
///     }
/// }
/// ```
public struct HeadingTheme: @unchecked Sendable, @unchecked Equatable {
    // MARK: Level 1 — 基础默认

    /// 标题字号缩放系数
    public var scale: HeadingScale = .default
    /// 是否加粗
    public var bold: Bool = true
    /// 文本颜色（nil = 跟随 baseFont 颜色）
    public var textColor: XMColor?
    /// 段前间距缩放系数（baseFont.pointSize × 此值）
    public var spacingBeforeScale: CGFloat = 0.50
    /// 段后间距缩放系数（baseFont.pointSize × spacingBeforeScale × 此值）
    public var spacingAfterRatio: CGFloat = 0.50

    // MARK: Level 2 — 逐级别覆盖

    /// h1 级别覆盖
    public var h1: LevelOverride? = nil
    /// h2 级别覆盖
    public var h2: LevelOverride? = nil
    /// h3 级别覆盖
    public var h3: LevelOverride? = nil
    /// h4 级别覆盖
    public var h4: LevelOverride? = nil
    /// h5 级别覆盖
    public var h5: LevelOverride? = nil
    /// h6 级别覆盖
    public var h6: LevelOverride? = nil

    // MARK: Level 3 — 动态 resolve

    /// 基于 block 内容/上下文的动态覆盖
    ///
    /// 返回 `nil` 表示不覆盖，使用当前配置。
    /// 返回修改后的 `ResolvedHeadingTheme` 表示覆盖。
    public var resolve: (@Sendable (MarkupBlock, RenderingContext, ResolvedHeadingTheme) -> ResolvedHeadingTheme?)?

    public init() {}

    // MARK: 逐级别覆盖类型

    /// 单个标题级别的覆盖配置
    public struct LevelOverride: Sendable, Equatable {
        /// 直接指定字号（覆盖 scale 计算）
        public var fontSize: CGFloat?
        /// 文本颜色
        public var textColor: XMColor?
        /// 是否加粗（nil = 使用基础默认）
        public var bold: Bool?
        /// 段前间距（pt，覆盖 scale 计算）
        public var spacingBefore: CGFloat?
        /// 段后间距（pt）
        public var spacingAfter: CGFloat?

        public init(
            fontSize: CGFloat? = nil,
            textColor: XMColor? = nil,
            bold: Bool? = nil,
            spacingBefore: CGFloat? = nil,
            spacingAfter: CGFloat? = nil
        ) {
            self.fontSize = fontSize
            self.textColor = textColor
            self.bold = bold
            self.spacingBefore = spacingBefore
            self.spacingAfter = spacingAfter
        }
    }

    // MARK: 解析结果

    /// 最终解析结果 — 渲染器只读这个
    public struct ResolvedHeadingTheme: @unchecked Sendable, Equatable {
        public let level: Level
        public var fontSize: CGFloat
        public var bold: Bool
        public var textColor: XMColor?
        public var spacingBefore: CGFloat
        public var spacingAfter: CGFloat

        /// Key-path 便利修改方法
        public func with<T>(_ keyPath: WritableKeyPath<ResolvedHeadingTheme, T>, _ value: T) -> ResolvedHeadingTheme {
            var copy = self
            copy[keyPath: keyPath] = value
            return copy
        }
    }

    // MARK: 解析方法

    /// 解析为最终的渲染配置
    ///
    /// 执行三级合并：base → per-level → resolve
    public func resolved(for block: MarkupBlock, baseFont: XMFont, context: RenderingContext) -> ResolvedHeadingTheme? {
        guard case .heading(let level) = block.kind else { return nil }

        // Step 1: 基础默认
        let baseSpacing = baseFont.pointSize * spacingBeforeScale
        var result = ResolvedHeadingTheme(
            level: level,
            fontSize: baseFont.pointSize * scaleForLevel(level),
            bold: bold,
            textColor: textColor,
            spacingBefore: baseSpacing,
            spacingAfter: baseSpacing * spacingAfterRatio
        )

        // Step 2: 逐级别覆盖
        if let perLevel = self[level] {
            if let v = perLevel.fontSize      { result.fontSize = v }
            if let v = perLevel.bold          { result.bold = v }
            if let v = perLevel.textColor     { result.textColor = v }
            if let v = perLevel.spacingBefore { result.spacingBefore = v }
            if let v = perLevel.spacingAfter  { result.spacingAfter = v }
        }

        // Step 3: 动态 resolve
        if let resolver = resolve, let override = resolver(block, context, result) {
            result = override
        }

        return result
    }

    // MARK: Private

    private subscript(level: Level) -> LevelOverride? {
        switch level {
        case .h1: return h1
        case .h2: return h2
        case .h3: return h3
        case .h4: return h4
        case .h5: return h5
        case .h6: return h6
        }
    }

    private func scaleForLevel(_ level: Level) -> CGFloat {
        switch level {
        case .h1: scale.h1
        case .h2: scale.h2
        case .h3: scale.h3
        case .h4: scale.h4
        case .h5: scale.h5
        case .h6: scale.h6
        }
    }

    public static let `default` = HeadingTheme()

    // Equatable 排除 resolve（闭包不可比较）
    public static func == (lhs: HeadingTheme, rhs: HeadingTheme) -> Bool {
        lhs.scale == rhs.scale && lhs.bold == rhs.bold && lhs.textColor == rhs.textColor
            && lhs.spacingBeforeScale == rhs.spacingBeforeScale && lhs.spacingAfterRatio == rhs.spacingAfterRatio
            && lhs.h1 == rhs.h1 && lhs.h2 == rhs.h2 && lhs.h3 == rhs.h3
            && lhs.h4 == rhs.h4 && lhs.h5 == rhs.h5 && lhs.h6 == rhs.h6
    }
}
