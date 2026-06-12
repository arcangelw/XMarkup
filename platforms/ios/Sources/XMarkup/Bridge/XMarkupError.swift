import CXMarkup
import Foundation

/// XMarkup 解析错误
public enum XMarkupError: Error, Sendable, Equatable {
    /// 解析器指针为 NULL
    case nullParser
    /// 输入 HTML 为 NULL
    case nullInput
    /// 嵌套深度超出限制，已截断
    case nestingOverflow
    /// 内存分配失败
    case allocationFailed
    /// 未知错误，保留原始错误码
    case unknown(code: Int32)

    /// 从 C API 错误码初始化
    init(cError: XMError) {
        switch cError {
        case XM_ERR_NULL_PARSER: self = .nullParser
        case XM_ERR_NULL_INPUT: self = .nullInput
        case XM_ERR_NESTING_OVERFLOW: self = .nestingOverflow
        case XM_ERR_ALLOC_FAILED: self = .allocationFailed
        default: self = .unknown(code: Int32(truncatingIfNeeded: cError.rawValue))
        }
    }

    /// 错误的可读描述（来自 C 引擎）
    public var description: String {
        let cError: XMError
        switch self {
        case .nullParser:      cError = XM_ERR_NULL_PARSER
        case .nullInput:       cError = XM_ERR_NULL_INPUT
        case .nestingOverflow: cError = XM_ERR_NESTING_OVERFLOW
        case .allocationFailed: cError = XM_ERR_ALLOC_FAILED
        case .unknown(let code):
            return "XMarkupError.unknown(code: \(code))"
        }
        let cStr = xmarkup_error_string(cError)
        return cStr.map { String(cString: $0) } ?? "unknown error"
    }
}

extension XMarkupError: CustomStringConvertible {}

extension XMarkupError: LocalizedError {
    public var errorDescription: String? { description }
}
