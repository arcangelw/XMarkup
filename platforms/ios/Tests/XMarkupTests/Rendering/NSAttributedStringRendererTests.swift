import XCTest
@testable import XMarkup

final class NSAttributedStringRendererTests: XCTestCase {

    func testRenderAttributedString() {
        var attr = AttributedString("Hello World")
        #if canImport(UIKit)
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif

        let renderer = NSAttributedStringRenderer()
        let result = renderer.render(attr)
        XCTAssertEqual(result.string, "Hello World")
    }

    func testRenderPreservesStandardAttributes() {
        var attr = AttributedString("Hello")
        #if canImport(UIKit)
        attr.uiKit.font = .boldSystemFont(ofSize: 20)
        attr.uiKit.foregroundColor = .red
        #elseif canImport(AppKit)
        attr.appKit.font = .boldSystemFont(ofSize: 20)
        attr.appKit.foregroundColor = .red
        #endif

        let renderer = NSAttributedStringRenderer()
        let result = renderer.render(attr)

        // UIKit/AppKit 标准属性保留
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 20)
    }

    func testKeyTransferViaPipeline() {
        var attr = AttributedString("Hello")
        attr[XMarkupTagKey.self] = "bold"

        // 通过 Pipeline 完整流程：标准转换 + key 转移
        let nsAttr = NSMutableAttributedString(attributedString: NSAttributedStringRenderer().render(attr))
        let transfer = XMarkupKeyTransfer()
        let ctx = RenderingContext(theme: .default, blockIndex: 0, totalBlocks: 1)
        transfer.transfer(from: attr, to: nsAttr, context: ctx)

        let tagValue = nsAttr.attribute(NSAttributedString.Key(XMarkupTagKey.name), at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(tagValue, "bold")
    }

    func testMeasureReturnsNonZeroSize() {
        var attr = AttributedString("Hello World with some text")
        #if canImport(UIKit)
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif

        let renderer = NSAttributedStringRenderer()
        let size = renderer.measure(attr, constrainedTo: 320)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
    }

    func testMeasureRespectsWidth() {
        var attr = AttributedString("A very long text that should wrap to multiple lines when constrained to a narrow width")
        #if canImport(UIKit)
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif

        let renderer = NSAttributedStringRenderer()
        let size = renderer.measure(attr, constrainedTo: 100)
        XCTAssertLessThanOrEqual(size.width, 100)
    }
}
