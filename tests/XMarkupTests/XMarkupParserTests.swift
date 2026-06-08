import XCTest
@testable import XMarkup

final class XMarkupParserTests: XCTestCase {

    func testCreateWithDefaultConfig() throws {
        let parser = try XMarkupParser()
        XCTAssertEqual(parser.baseFontSize, 16.0)
    }

    func testCreateWithCustomConfig() throws {
        let parser = try XMarkupParser(baseFontSize: 14.5, maxNestingDepth: 128, autocorrect: false)
        XCTAssertEqual(parser.baseFontSize, 14.5)
    }

    func testParseSimpleBold() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<b>bold</b>")
        XCTAssertEqual(result.text, "bold")
        XCTAssertEqual(result.spans.count, 1)
        XCTAssertEqual(result.spans[0].tag, .bold)
        XCTAssertEqual(result.spans[0].range.location, 0)
        XCTAssertEqual(result.spans[0].range.length, 4)
    }

    func testParseEmptyInput() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("")
        XCTAssertEqual(result.text, "")
        XCTAssertEqual(result.spans.count, 0)
    }

    func testParsePureText() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("Hello World")
        XCTAssertEqual(result.text, "Hello World")
        XCTAssertEqual(result.spans.count, 0)
    }

    func testParseNestedBoldItalic() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<b><i>text</i></b>")
        XCTAssertEqual(result.text, "text")
        XCTAssertEqual(result.spans.count, 2)
        XCTAssertEqual(result.spans[0].tag, .bold)
        XCTAssertEqual(result.spans[1].tag, .italic)
    }

    func testParseLinkWithHref() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<a href=\"https://example.com\">click</a>")
        XCTAssertEqual(result.text, "click")
        XCTAssertEqual(result.spans[0].tag, .link)
        XCTAssertEqual(result.spans[0].value, "https://example.com")
    }

    func testConsecutiveParseIndependence() throws {
        let parser = try XMarkupParser()
        let r1 = try parser.parse("<b>first</b>")
        let r2 = try parser.parse("<i>second</i>")
        XCTAssertEqual(r1.text, "first")
        XCTAssertEqual(r2.text, "second")
        XCTAssertEqual(r1.spans[0].tag, .bold)
        XCTAssertEqual(r2.spans[0].tag, .italic)
    }

    func testDeinitReleasesResource() throws {
        // 确保 deinit 不崩溃
        try autoreleasepool {
            let parser = try XMarkupParser()
            _ = try parser.parse("<b>test</b>")
            // parser 离开作用域后 deinit 自动调用 xmarkup_destroy
        }
    }
}
