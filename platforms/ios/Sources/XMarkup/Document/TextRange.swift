import Foundation

/// 平台无关的文本范围（跨平台核心模型使用）
///
/// 使用 `start` + `length`（Int）替代 `NSRange`（Foundation 类型），
/// 确保在 Swift/Kotlin/ArkTS 等语言中可用同一结构定义。
///
/// 与 `NSRange` 的编码一致：以 UTF-16 码元为单位。
///
/// ```swift
/// let range = TextRange(start: 6, length: 5)  // "bold" 在 "Hello bold" 中
/// let nsRange = range.nsRange                  // Apple 平台桥接
/// ```
public struct TextRange: Sendable, Equatable {
    /// 起始偏移（UTF-16 码元）
    public let start: Int
    /// 长度（UTF-16 码元）
    public let length: Int

    public init(start: Int, length: Int) {
        self.start = start
        self.length = length
    }
}

// MARK: - Apple 平台桥接

extension TextRange {
    /// 桥接到 NSRange（Apple 平台渲染管线使用）
    public var nsRange: NSRange {
        NSRange(location: start, length: length)
    }
}
