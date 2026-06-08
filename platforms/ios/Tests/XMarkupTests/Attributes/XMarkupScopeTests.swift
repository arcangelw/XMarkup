import XCTest
@testable import XMarkup

final class XMarkupScopeTests: XCTestCase {

    // MARK: - AttributedString 直接使用

    func testCustomKeyInAttributedString() {
        var attr = AttributedString("Hello World")
        attr[XMarkupTagKey.self] = "heading1"
        XCTAssertEqual(attr[XMarkupTagKey.self], "heading1")
    }

    func testCustomKeyInAttributedStringRange() {
        var attr = AttributedString("Hello World")
        let range = attr.range(of: "Hello")!
        attr[range][XMarkupTagKey.self] = "bold"
        XCTAssertEqual(attr[range][XMarkupTagKey.self], "bold")
    }

    func testMultipleCustomKeysCoexist() {
        var attr = AttributedString("Title")
        attr[XMarkupTagKey.self] = "heading"
        attr[XMarkupBlockKindKey.self] = "heading"
        attr[XMarkupHeadingLevelKey.self] = 1
        XCTAssertEqual(attr[XMarkupTagKey.self], "heading")
        XCTAssertEqual(attr[XMarkupBlockKindKey.self], "heading")
        XCTAssertEqual(attr[XMarkupHeadingLevelKey.self], 1)
    }

    func testCustomKeyWithUIKitAttributes() {
        var attr = AttributedString("Colored")
        #if canImport(UIKit)
        attr.uiKit.foregroundColor = .red
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.foregroundColor = .red
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif
        attr[XMarkupTagKey.self] = "span"

        XCTAssertEqual(attr[XMarkupTagKey.self], "span")
        #if canImport(UIKit)
        XCTAssertEqual(attr.uiKit.foregroundColor, .red)
        #elseif canImport(AppKit)
        XCTAssertEqual(attr.appKit.foregroundColor, .red)
        #endif
    }

    func testListItemInfoKey() {
        var attr = AttributedString("Item 1")
        attr[XMarkupListItemInfoKey.self] = "ordered:0"
        XCTAssertEqual(attr[XMarkupListItemInfoKey.self], "ordered:0")
    }

    func testAttachmentRefKey() {
        var attr = AttributedString("\u{FFFC}")
        attr[XMarkupAttachmentRefKey.self] = "img-0"
        XCTAssertEqual(attr[XMarkupAttachmentRefKey.self], "img-0")
    }

    // MARK: - NS 桥接（手动 transfer）

    func testCustomKeyManualNSBridge() {
        var attr = AttributedString("Test")
        attr[XMarkupTagKey.self] = "link"
        attr[XMarkupLinkURLKey.self] = "https://example.com"

        // 通过 NSMutableAttributedString 手动转移自定义 key
        let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attr))
        let fullRange = NSRange(location: 0, length: nsAttr.length)
        // 自定义 key 通过 raw key 名手动添加到 NS 层
        if let tag = attr[XMarkupTagKey.self] {
            nsAttr.addAttribute(NSAttributedString.Key(XMarkupTagKey.name), value: tag, range: fullRange)
        }
        if let url = attr[XMarkupLinkURLKey.self] {
            nsAttr.addAttribute(NSAttributedString.Key(XMarkupLinkURLKey.name), value: url, range: fullRange)
        }

        XCTAssertEqual(nsAttr.attribute(NSAttributedString.Key("XMarkup.Tag"), at: 0, effectiveRange: nil) as? String, "link")
        XCTAssertEqual(nsAttr.attribute(NSAttributedString.Key("XMarkup.LinkURL"), at: 0, effectiveRange: nil) as? String, "https://example.com")
    }

    // MARK: - 通过 runs 遍历自定义 key

    func testCustomKeyAccessibleViaRuns() {
        var attr = AttributedString("Hello World")
        let range = attr.range(of: "Hello")!
        attr[range][XMarkupTagKey.self] = "bold"

        var foundBold = false
        for run in attr.runs {
            if run[XMarkupTagKey.self] == "bold" {
                foundBold = true
            }
        }
        XCTAssertTrue(foundBold, "自定义 key 应通过 runs 遍历可访问")
    }
}
