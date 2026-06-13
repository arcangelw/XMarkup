import XCTest
@testable import XMarkupDemoSwiftUI

/// P0-5 渲染器测试 — 驱动 DemoRenderer（HTML→NSAttributedString）+ WebViewRenderer 接 config
final class DemoRendererTests: XCTestCase {

    func testRenderProducesAttributedString() throws {
        let ex = DemoExample(id: "t", title: "T", summary: "", html: "<b>粗</b>",
                             family: .inlineText, tier: .basic)
        let attr = try DemoRenderer.render(example: ex, config: DemoCanvasConfig())
        XCTAssertGreaterThan(attr.length, 0)
    }

    func testRenderAppliesThemeOverride() throws {
        let ex = DemoExample(id: "t", title: "T", summary: "", html: "hi",
                             family: .theme, tier: .basic, themeOverride: .default)
        let attr = try DemoRenderer.render(example: ex, config: DemoCanvasConfig())
        XCTAssertNotNil(attr.attribute(.font, at: 0, effectiveRange: nil))
    }

    func testRenderVariantsReturnsMultiple() throws {
        let ex = DemoExample(id: "t", title: "T", summary: "", html: "hi",
                             family: .theme, tier: .basic,
                             themeVariants: [.default, .dark])
        let variants = try DemoRenderer.renderVariants(example: ex, config: DemoCanvasConfig())
        XCTAssertEqual(variants.count, 2)
    }

    func testAppendHTMLConcatenates() throws {
        let ex = DemoExample(id: "t", title: "T", summary: "", html: "<p>A</p>",
                             family: .inlineText, tier: .basic, appendHTML: "<p>B</p>")
        let attr = try DemoRenderer.render(example: ex, config: DemoCanvasConfig())
        XCTAssertTrue(attr.string.contains("A"))
        XCTAssertTrue(attr.string.contains("B"))
    }

    func testStyledHTMLInjectsConfigCSS() {
        let styled = WebViewRenderer.styledHTML(from: "<b>x</b>", config: DemoCanvasConfig())
        XCTAssertTrue(styled.contains("line-height: 1.6"), styled)
        XCTAssertTrue(styled.contains("<b>x</b>"))
    }
}
