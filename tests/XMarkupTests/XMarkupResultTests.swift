import XCTest
@testable import XMarkup
import CXMarkup

final class XMarkupResultTests: XCTestCase {

    func testTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_BOLD), .bold)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_ITALIC), .italic)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_LINK), .link)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_1), .heading1)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_LINE_BREAK), .lineBreak)
    }

    func testUnknownTag() {
        if case .unknown(let val) = XMarkupTag(cValue: XMTagType(rawValue: 999)) {
            XCTAssertEqual(val, 999)
        } else {
            XCTFail("Expected unknown tag")
        }
    }

    func testStyleMapping() {
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FOREGROUND_COLOR), .foregroundColor)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FONT_SIZE), .fontSize)
    }

    func testErrorMapping() {
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_PARSER), .nullParser)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_INPUT), .nullInput)
        XCTAssertEqual(XMarkupError(cError: XM_OK), .unknown(code: 0))
    }
}
