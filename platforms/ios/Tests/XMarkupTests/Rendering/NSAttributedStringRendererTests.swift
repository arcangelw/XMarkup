import XCTest
@testable import XMarkup

final class NSConversionTests: XCTestCase {

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

    func testKeyTransferViaPipeline() {
        var attr = AttributedString("Hello")
        attr[XMarkupTagKey.self] = "bold"

        let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attr))
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

        let nsAttr = NSAttributedString(attr)
        let size = nsAttr.boundingRect(
            with: CGSize(width: 320, height: 1e9),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        XCTAssertGreaterThan(ceil(size.width), 0)
        XCTAssertGreaterThan(ceil(size.height), 0)
    }

    func testMeasureRespectsWidth() {
        var attr = AttributedString("A very long text that should wrap to multiple lines when constrained to a narrow width")
        #if canImport(UIKit)
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif

        let nsAttr = NSAttributedString(attr)
        let size = nsAttr.boundingRect(
            with: CGSize(width: 100, height: 1e9),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        XCTAssertLessThanOrEqual(ceil(size.width), 100)
    }
}
