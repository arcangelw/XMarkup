import XCTest
import XMarkup
@testable import XMarkupUI

@MainActor final class XMarkupTextViewTests: XCTestCase {

    func testTextViewCanBeCreated() {
        let tv = XMarkupTextView()
        XCTAssertNotNil(tv)
    }

    func testLoadSimpleDocument() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        let tv = XMarkupTextView()
        tv.load(doc)
        #if canImport(UIKit) && !os(macOS)
        let text = tv.text ?? ""
        XCTAssertTrue(text.contains("Hello"))
        #else
        let text = tv.textStorage?.string ?? ""
        XCTAssertTrue(text.contains("Hello"))
        #endif
    }

    func testLoadWithBlockquote() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<blockquote>Quote</blockquote>")
        let doc = MarkupDocument.from(result)
        let tv = XMarkupTextView()
        tv.load(doc)
        XCTAssertNotNil(tv.textStorage)
    }

    func testLayoutManagerIsBlockquoteLM() throws {
        let tv = XMarkupTextView()
        let attr = NSAttributedString(string: "test")
        tv.load(nsAttr: attr)
        #if canImport(UIKit) && !os(macOS)
        XCTAssertTrue(tv.layoutManager is BlockquoteLayoutManager,
                      "layoutManager 应被替换为 BlockquoteLayoutManager")
        #else
        XCTAssertNotNil(tv.layoutManager)
        #endif
    }
}
