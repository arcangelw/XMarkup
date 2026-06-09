import XCTest
@testable import XMarkup

final class ParagraphSpacingTests: XCTestCase {

    // MARK: - ParagraphSpacing 结构体

    func testDefaultSpacing() {
        let spacing = ParagraphSpacing.default
        XCTAssertEqual(spacing.spacingBefore, 8)
        XCTAssertEqual(spacing.spacingAfter, 8)
        XCTAssertEqual(spacing.lineSpacing, 0)
    }

    func testCustomSpacing() {
        let spacing = ParagraphSpacing(spacingBefore: 12, spacingAfter: 16, lineSpacing: 4)
        XCTAssertEqual(spacing.spacingBefore, 12)
        XCTAssertEqual(spacing.spacingAfter, 16)
        XCTAssertEqual(spacing.lineSpacing, 4)
    }

    func testEquality() {
        let a = ParagraphSpacing(spacingBefore: 8, spacingAfter: 8, lineSpacing: 0)
        let b = ParagraphSpacing.default
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = ParagraphSpacing(lineSpacing: 4)
        let b = ParagraphSpacing.default
        XCTAssertNotEqual(a, b)
    }

    // MARK: - MarkupTheme 集成

    func testThemeDefaultParagraphSpacing() {
        let theme = MarkupTheme.default
        XCTAssertEqual(theme.paragraphSpacing, .default)
    }

    func testThemeEqualityIncludesParagraphSpacing() {
        var a = MarkupTheme.default
        let b = MarkupTheme.default
        XCTAssertEqual(a, b)
        a.paragraphSpacing = ParagraphSpacing(lineSpacing: 4)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - DSL 组件

    func testParagraphSpacingComponent() {
        let theme = MarkupTheme {
            ParagraphSpacingComponent(ParagraphSpacing(spacingBefore: 10, spacingAfter: 10, lineSpacing: 2))
        }
        XCTAssertEqual(theme.paragraphSpacing.spacingBefore, 10)
        XCTAssertEqual(theme.paragraphSpacing.spacingAfter, 10)
        XCTAssertEqual(theme.paragraphSpacing.lineSpacing, 2)
    }

    func testParagraphSpacingComponentWithDefaults() {
        let theme = MarkupTheme {
            ParagraphSpacingComponent(.default)
        }
        XCTAssertEqual(theme.paragraphSpacing, .default)
    }
}
