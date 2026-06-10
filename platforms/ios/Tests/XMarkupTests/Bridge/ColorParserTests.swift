import XCTest
@testable import XMarkup

final class ColorParserTests: XCTestCase {
    func testRed() {
        let color = ColorParser.parse("#FF0000")
        XCTAssertNotNil(color)
    }

    func testGreen() {
        let color = ColorParser.parse("#00FF00")
        XCTAssertNotNil(color)
    }

    func testBlue() {
        let color = ColorParser.parse("#0000FF")
        XCTAssertNotNil(color)
    }

    func testBlack() {
        let color = ColorParser.parse("#000000")
        XCTAssertNotNil(color)
    }

    func testLowercase() {
        let color = ColorParser.parse("#ff0000")
        XCTAssertNotNil(color)
    }

    func testNilInput() {
        let color = ColorParser.parse(nil)
        XCTAssertNil(color)
    }

    func testEmptyInput() {
        let color = ColorParser.parse("")
        XCTAssertNil(color)
    }

    func testInvalidFormat() {
        let color = ColorParser.parse("not-a-color")
        XCTAssertNil(color)
    }

    func testShortHex() {
        // #RGB 短格式不被 C 引擎输出，容错返回 nil
        let color = ColorParser.parse("#F00")
        XCTAssertNil(color)
    }

    func testUppercaseHex() {
        let color = ColorParser.parse("#FF00FF")
        XCTAssertNotNil(color, "大写 hex 应被解析")
    }

    func testColorValueCorrectness() {
        let color = ColorParser.parse("#FF0000")
        XCTAssertNotNil(color)
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color!.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01, "#FF0000 -> R=1.0")
        XCTAssertEqual(g, 0.0, accuracy: 0.01, "#FF0000 -> G=0.0")
        XCTAssertEqual(b, 0.0, accuracy: 0.01, "#FF0000 -> B=0.0")
        #endif
    }
}
