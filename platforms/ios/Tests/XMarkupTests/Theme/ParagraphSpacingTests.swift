import XCTest
@testable import XMarkup

// MARK: - ParagraphTheme 测试（原 ParagraphSpacing 测试迁移）

final class ParagraphThemeTests: XCTestCase {

    // MARK: - ParagraphTheme 结构体

    func testDefaultValues() {
        let theme = ParagraphTheme.default
        XCTAssertEqual(theme.spacingBefore, 8)
        XCTAssertEqual(theme.spacingAfter, 8)
        XCTAssertEqual(theme.lineSpacing, 0)
    }

    func testCustomValues() {
        let theme = ParagraphTheme(spacingBefore: 12, spacingAfter: 16, lineSpacing: 4)
        XCTAssertEqual(theme.spacingBefore, 12)
        XCTAssertEqual(theme.spacingAfter, 16)
        XCTAssertEqual(theme.lineSpacing, 4)
    }

    func testEquality() {
        let a = ParagraphTheme(spacingBefore: 8, spacingAfter: 8, lineSpacing: 0)
        let b = ParagraphTheme.default
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = ParagraphTheme(lineSpacing: 4)
        let b = ParagraphTheme.default
        XCTAssertNotEqual(a, b)
    }

    // MARK: - MarkupTheme 集成

    func testThemeDefaultParagraphTheme() {
        let theme = MarkupTheme.default
        XCTAssertEqual(theme.paragraph, .default)
    }

    func testThemeEqualityIncludesParagraph() {
        var a = MarkupTheme.default
        let b = MarkupTheme.default
        XCTAssertEqual(a, b)
        a.paragraph = ParagraphTheme(lineSpacing: 4)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - DSL 组件

    func testParagraphComponent() {
        let theme = MarkupTheme {
            Paragraph {
                $0.spacingBefore = 10
                $0.spacingAfter = 10
                $0.lineSpacing = 2
            }
        }
        XCTAssertEqual(theme.paragraph.spacingBefore, 10)
        XCTAssertEqual(theme.paragraph.spacingAfter, 10)
        XCTAssertEqual(theme.paragraph.lineSpacing, 2)
    }

    func testParagraphComponentWithDefaults() {
        let theme = MarkupTheme {
            Paragraph { _ in }
        }
        // Paragraph { _ in } 不修改任何字段，应保持默认
        XCTAssertEqual(theme.paragraph.spacingBefore, 8)
        XCTAssertEqual(theme.paragraph.spacingAfter, 8)
    }

    // MARK: - 渲染管线验证

    func testRenderAppliesParagraphSpacing() throws {
        let theme = MarkupTheme {
            Paragraph {
                $0.spacingBefore = 12
                $0.spacingAfter = 10
                $0.lineSpacing = 4
            }
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
        XCTAssertTrue(foundSpacing, "渲染结果应包含 ParagraphTheme 配置的 NSParagraphStyle")
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
