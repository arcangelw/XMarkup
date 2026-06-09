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

    // MARK: - 渲染管线验证

    func testRenderAppliesParagraphSpacing() throws {
        let theme = MarkupTheme {
            ParagraphSpacingComponent(ParagraphSpacing(spacingBefore: 12, spacingAfter: 10, lineSpacing: 4))
        }
        let parser = try XMarkupParser()
        let result = try parser.parse("<p>Hello</p><p>World</p>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render(theme: theme)

        // 验证 runs 中存在 paragraphStyle
        var foundSpacing = false
        for run in attr.runs {
            #if canImport(UIKit)
            if let ps = run.uiKit.paragraphStyle {
                if ps.paragraphSpacingBefore == 12 && ps.paragraphSpacing == 10 && ps.lineSpacing == 4 {
                    foundSpacing = true
                }
            }
            #elseif canImport(AppKit)
            if let ps = run.appKit.paragraphStyle {
                if ps.paragraphSpacingBefore == 12 && ps.paragraphSpacing == 10 && ps.lineSpacing == 4 {
                    foundSpacing = true
                }
            }
            #endif
        }
        XCTAssertTrue(foundSpacing, "渲染结果应包含 ParagraphSpacing 配置的 NSParagraphStyle")
    }

    func testRenderDefaultThemeHasParagraphSpacing() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()

        // 默认主题应有 8pt 间距
        var foundSpacing = false
        for run in attr.runs {
            #if canImport(UIKit)
            if let ps = run.uiKit.paragraphStyle {
                if ps.paragraphSpacingBefore == 8 && ps.paragraphSpacing == 8 {
                    foundSpacing = true
                }
            }
            #elseif canImport(AppKit)
            if let ps = run.appKit.paragraphStyle {
                if ps.paragraphSpacingBefore == 8 && ps.paragraphSpacing == 8 {
                    foundSpacing = true
                }
            }
            #endif
        }
        XCTAssertTrue(foundSpacing, "默认主题应包含 8pt 段落间距")
    }
}
