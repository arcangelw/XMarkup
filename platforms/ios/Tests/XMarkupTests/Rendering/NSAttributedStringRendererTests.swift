import XCTest
@testable import XMarkup

final class NSConversionTests: XCTestCase {

    // MARK: - AttributedString → NSAttributedString（标准 API）

    func testAttributedStringToNSAttributedString() {
        var attr = AttributedString("Hello World")
        #if canImport(UIKit)
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif

        let result = NSAttributedString(attr)
        XCTAssertEqual(result.string, "Hello World")
    }

    func testStandardAttributesPreserved() {
        var attr = AttributedString("Hello")
        #if canImport(UIKit)
        attr.uiKit.font = .boldSystemFont(ofSize: 20)
        attr.uiKit.foregroundColor = .red
        #elseif canImport(AppKit)
        attr.appKit.font = .boldSystemFont(ofSize: 20)
        attr.appKit.foregroundColor = .red
        #endif

        let result = NSAttributedString(attr)

        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 20)
    }

    // MARK: - NSAttributedString → AttributedString（renderAttributed 包装）

    func testRenderAttributedWrapsStandardKeys() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<b>bold</b>")
        let doc = MarkupDocument.from(result)
        let attr = doc.renderAttributed()

        #if canImport(UIKit)
        let hasBold = attr.runs.contains { run in
            guard let font = run.uiKit.font else { return false }
            return font.fontDescriptor.symbolicTraits.contains(.traitBold)
        }
        #elseif canImport(AppKit)
        let hasBold = attr.runs.contains { run in
            guard let font = run.appKit.font else { return false }
            return font.fontDescriptor.symbolicTraits.contains(.bold)
        }
        #endif
        XCTAssertTrue(hasBold, "renderAttributed 返回的 AttributedString 应携带标准字体属性")
    }

    func testMeasureReturnsNonZeroSize() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<p>Hello World with some text</p>")
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let size = nsAttr.boundingRect(
            with: CGSize(width: 320, height: 1e9),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        XCTAssertGreaterThan(ceil(size.width), 0)
        XCTAssertGreaterThan(ceil(size.height), 0)
    }

    func testMeasureRespectsWidth() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<p>A very long text that should wrap to multiple lines</p>")
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let size = nsAttr.boundingRect(
            with: CGSize(width: 100, height: 1e9),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        XCTAssertLessThanOrEqual(ceil(size.width), 100)
    }
}
