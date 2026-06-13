import CXMarkup
import XCTest
@testable import XMarkup

/// XMarkupError ↔ C XMError 映射测试
final class XMarkupErrorTests: XCTestCase {

    func testInputTooLargeMapping() {
        // 对齐 C 核心 XM_ERR_INPUT_TOO_LARGE（2026-06-13 新增）
        XCTAssertEqual(XMarkupError(cError: XM_ERR_INPUT_TOO_LARGE), .inputTooLarge)
    }

    func testInputTooLargeDescription() {
        // description 经 xmarkup_error_string 回到 C 引擎的可读字符串
        XCTAssertEqual(XMarkupError.inputTooLarge.description, "Input too large (>4GiB)")
    }

    func testKnownErrorsMap() {
        // 已知错误码全部映射到对应 case，不走 .unknown
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_PARSER), .nullParser)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_INPUT), .nullInput)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NESTING_OVERFLOW), .nestingOverflow)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_ALLOC_FAILED), .allocationFailed)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_INPUT_TOO_LARGE), .inputTooLarge)
    }

    func testUnknownCodeFallback() {
        // 未知错误码回落到 .unknown(code:)，保留原始值
        if case let .unknown(code) = XMarkupError(cError: XMError(rawValue: -999)) {
            XCTAssertEqual(code, -999)
        } else {
            XCTFail("未知错误码应回落到 .unknown")
        }
    }
}
