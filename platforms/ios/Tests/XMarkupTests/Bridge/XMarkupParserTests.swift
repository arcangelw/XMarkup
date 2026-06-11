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

    // MARK: - 解析器错误路径

    func testParseDeeplyNestedHTML() throws {
        let parser = try XMarkupParser()
        // 生成 500 层嵌套 <b><b>...text...</b></b>
        let innerTag = String(repeating: "<b>", count: 500) + "text" + String(repeating: "</b>", count: 500)
        let result = try parser.parse(innerTag)
        // 引擎应处理深层嵌套（兜底截断或保留前 N 层），不应崩溃
        XCTAssertTrue(result.text.contains("text"), "深层嵌套不应崩溃")
    }

    func testParseMalformedHTML() throws {
        let parser = try XMarkupParser()
        // 各种畸形输入——不应崩溃
        let cases = [
            "<b>unclosed",
            "<b><i>crossed</b></i>",
            "<<<>>>",
            "<div><p>mismatched</div>",
            "<a href>missing_value",
            "<img src='img.jpg'>",  // 单引号属性
        ]
        for html in cases {
            // 不应崩溃（parse 抛出即触发 XCTest 失败）
            _ = try parser.parse(html)
        }
    }

    func testParseWithMaxNestingDepthLimit() throws {
        let parser = try XMarkupParser(maxNestingDepth: 5, autocorrect: false)
        // 超过 5 层嵌套
        let html = String(repeating: "<div>", count: 10) + "text" + String(repeating: "</div>", count: 10)
        let result = try parser.parse(html)
        // 不应崩溃，应保留部分文本
        XCTAssertTrue(result.text.contains("text"), "受限嵌套深度不应崩溃")
    }
}
