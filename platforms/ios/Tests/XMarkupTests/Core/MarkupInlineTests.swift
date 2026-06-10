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
            .textAlign("center"),
        ]
        XCTAssertEqual(styles.count, 9)
    }

    func testInlineStyleTextAlign() {
        let align = InlineStyle.textAlign("center")
        XCTAssertEqual(align, InlineStyle.textAlign("center"))
        XCTAssertNotEqual(align, InlineStyle.textAlign("left"))
    }

    // MARK: - MarkupInline

    func testMarkupInlineCreation() {
        let inline = MarkupInline(range: NSRange(location: 0, length: 5), kind: .bold)
        XCTAssertEqual(inline.kind, .bold)
        XCTAssertEqual(inline.range, NSRange(location: 0, length: 5))
    }

    func testMarkupInlineEquality() {
        let a = MarkupInline(range: NSRange(location: 0, length: 4), kind: .bold)
        let b = MarkupInline(range: NSRange(location: 0, length: 4), kind: .bold)
        XCTAssertEqual(a, b)
    }

    // MARK: - Subscript / Superscript

    func testInlineKindSubscript() {
        let sub = InlineKind.subscriptText
        XCTAssertEqual(sub, InlineKind.subscriptText)
        XCTAssertNotEqual(sub, InlineKind.superscript)
    }

    func testInlineKindSuperscript() {
        let sup = InlineKind.superscript
        XCTAssertEqual(sup, InlineKind.superscript)
        XCTAssertNotEqual(sup, InlineKind.subscriptText)
    }

    func testInlineKindAllCasesUpdated() {
        let kinds: [InlineKind] = [
            .bold, .italic, .underline, .strikethrough,
            .code, .mark, .link(url: ""),
            .subscriptText, .superscript,
            .span(styles: []),
        ]
        XCTAssertEqual(kinds.count, 10, "新增 sub/sup 后总数应为 10")
    }
}
