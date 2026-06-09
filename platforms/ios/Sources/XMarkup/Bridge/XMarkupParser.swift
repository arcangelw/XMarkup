import CXMarkup
import Foundation

/// XMarkup HTML 解析器
///
/// 将 HTML 转换为纯文本 + 样式区间，供桥接层消费。
///
/// 使用方式：
/// ```swift
/// let parser = try XMarkupParser(baseFontSize: 14.5)
/// let result = try parser.parse("<b>Hello</b> <i>World</i>")
/// let document = MarkupDocument.from(result)
/// let attributed = document.render()
/// ```
///
/// - Note: 线程安全保证与 C 核心引擎一致：不同实例可跨线程并发使用，
///         同一实例不可并发调用。
/// - Warning: 此类标记为 `@unchecked Sendable` 仅因设计上每个 Task 应持有独立实例。
///   **同一实例不可并发调用 `parse(_:)`**，否则产生未定义行为。
///   推荐用法：每个并发 Task 创建自己的 `XMarkupParser` 实例。
public final class XMarkupParser: @unchecked Sendable {
    // MARK: - Public Properties

    /// 当前配置的基准字号（保留 CGFloat 精度，用于 UIFont 渲染）
    public let baseFontSize: CGFloat

    // MARK: - Private Properties

    private let handle: OpaquePointer

    // MARK: - Initialization

    /// 创建解析器
    ///
    /// - Parameters:
    ///   - baseFontSize: 基准字号（pt），用于 CSS em/rem/% 单位换算，默认 16
    ///   - maxNestingDepth: 最大嵌套深度，超出截断，默认 256
    ///   - autocorrect: 是否自动纠错乱序嵌套/未闭合标签，默认 true
    /// - Throws: 内存不足时抛出 `XMarkupError.allocationFailed`
    public init(
        baseFontSize: CGFloat = 16,
        maxNestingDepth: UInt16 = 256,
        autocorrect: Bool = true
    ) throws {
        self.baseFontSize = baseFontSize
        var config = XMConfig()
        config.enable_autocorrect = autocorrect ? 1 : 0
        config.max_nesting_depth = maxNestingDepth
        config.base_font_size = Float(baseFontSize)
        guard let ptr = xmarkup_create(&config) else {
            throw XMarkupError.allocationFailed
        }
        handle = ptr
    }

    deinit {
        xmarkup_destroy(handle)
    }

    // MARK: - Public Methods

    /// 解析 HTML 字符串
    ///
    /// - Parameter html: HTML 输入（UTF-8 编码）
    /// - Returns: 解析结果，包含纯文本和样式区间
    /// - Throws: `XMarkupError` 各种解析错误
    public func parse(_ html: String) throws -> XMarkupResult {
        let cResult = html.withCString { ptr in
            xmarkup_parse(handle, ptr, html.utf8.count)
        }

        guard let cResult else {
            let error = xmarkup_last_error(handle)
            throw XMarkupError(cError: error)
        }
        defer { xmarkup_result_free(cResult) }

        let err = cResult.pointee.error
        guard err == XM_OK else {
            throw XMarkupError(cError: err)
        }

        return XMarkupResult.fromC(cResult)
    }
}
