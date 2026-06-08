import XCTest
@testable import XMarkup

final class MarkupInlineTests: XCTestCase {

    // MARK: - InlineKind

    func testInlineKindBoldIsEqual() {
        XCTAssertEqual(InlineKind.bold, InlineKind.bold)
    }

    func testInlineKindLinkCarriesURL() {
        let link = InlineKind.link(url: "https://example.com")
        if case let .link(url) = link {
            XCTAssertEqual(url, "https://example.com")
        } else {
            XCTFail("Expected .link(url:)")
        }
    }

    func testInlineKindSpanCarriesStyles() {
        let styles: [InlineStyle] = [.foregroundColor("#FF0000"), .fontSize(14)]
        let span = InlineKind.span(styles: styles)
        if case let .span(s) = span {
            XCTAssertEqual(s.count, 2)
            XCTAssertEqual(s[0], .foregroundColor("#FF0000"))
            XCTAssertEqual(s[1], .fontSize(14))
        } else {
            XCTFail("Expected .span(styles:)")
        }
    }

    // MARK: - InlineStyle

    func testInlineStyleEquality() {
        XCTAssertEqual(InlineStyle.foregroundColor("#FF0000"), InlineStyle.foregroundColor("#FF0000"))
        XCTAssertNotEqual(InlineStyle.foregroundColor("#FF0000"), InlineStyle.foregroundColor("#00FF00"))
        XCTAssertEqual(InlineStyle.fontSize(14.5), InlineStyle.fontSize(14.5))
    }

    func testInlineStyleAllCases() {
        // 确保所有 case 都可以构造且 Sendable
        let styles: [InlineStyle] = [
            .foregroundColor("#000"),
            .backgroundColor("#FFF"),
            .fontSize(16),
            .fontWeight("bold"),
            .fontStyle("italic"),
            .textDecoration("underline"),
            .lineHeight(1.5),
            .letterSpacing(0.5),
        ]
        XCTAssertEqual(styles.count, 8)
    }

    // MARK: - MarkupInline

    func testMarkupInlineCreation() {
        let text = "Hello World"
        let start = text.startIndex
        let end = text.index(start, offsetBy: 5)
        let inline = MarkupInline(range: start..<end, kind: .bold)
        XCTAssertEqual(inline.kind, .bold)
        XCTAssertEqual(text[inline.range], "Hello")
    }

    func testMarkupInlineEquality() {
        let text = "Test"
        let range = text.startIndex..<text.endIndex
        let a = MarkupInline(range: range, kind: .bold)
        let b = MarkupInline(range: range, kind: .bold)
        XCTAssertEqual(a, b)
    }
}
