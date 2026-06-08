import XCTest
@testable import XMarkup

/// 验证跨平台类型别名和基础功能在当前平台上正确工作
final class CrossPlatformTests: XCTestCase {
    func testXMFontTypeExists() {
        let font = XMFont.systemFont(ofSize: 16)
        XCTAssertEqual(font.pointSize, 16)
    }

    func testXMColorTypeExists() {
        #if canImport(UIKit)
            let color = XMColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            XCTAssertNotNil(color)
        #elseif canImport(AppKit)
            let color = XMColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
            XCTAssertNotNil(color)
        #endif
    }

    func testColorParserReturnsXMColor() {
        let color = ColorParser.parse("#FF0000")
        XCTAssertNotNil(color)
    }
}
