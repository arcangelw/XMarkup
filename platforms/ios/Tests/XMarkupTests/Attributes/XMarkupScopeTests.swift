import XCTest
@testable import XMarkup

final class XMarkupScopeTests: XCTestCase {

    // MARK: - NSAttributedString.Key 扩展存在性

    func testNSAttributedStringKeyExtensionsExist() {
        XCTAssertEqual(NSAttributedString.Key.xmarkupTag.rawValue, "XMarkup.Tag")
        XCTAssertEqual(NSAttributedString.Key.xmarkupBlockKind.rawValue, "XMarkup.BlockKind")
        XCTAssertEqual(NSAttributedString.Key.xmarkupLinkURL.rawValue, "XMarkup.LinkURL")
        XCTAssertEqual(NSAttributedString.Key.xmarkupHeadingLevel.rawValue, "XMarkup.HeadingLevel")
        XCTAssertEqual(NSAttributedString.Key.xmarkupListItemInfo.rawValue, "XMarkup.ListItemInfo")
        XCTAssertEqual(NSAttributedString.Key.xmarkupAttachmentRef.rawValue, "XMarkup.AttachmentRef")
    }

    // MARK: - NSAttributedString 上设置/读取自定义 key

    func testCustomKeyOnNSAttributedString() {
        let nsAttr = NSMutableAttributedString(string: "Hello")
        nsAttr.addAttribute(.xmarkupTag, value: "bold", range: NSRange(location: 0, length: 5))

        let value = nsAttr.attribute(.xmarkupTag, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(value, "bold")
    }

    func testMultipleCustomKeysOnNSAttributedString() {
        let nsAttr = NSMutableAttributedString(string: "Title")
        let fullRange = NSRange(location: 0, length: 5)
        nsAttr.addAttribute(.xmarkupTag, value: "heading", range: fullRange)
        nsAttr.addAttribute(.xmarkupBlockKind, value: "heading", range: fullRange)
        nsAttr.addAttribute(.xmarkupHeadingLevel, value: 1, range: fullRange)

        XCTAssertEqual(nsAttr.attribute(.xmarkupTag, at: 0, effectiveRange: nil) as? String, "heading")
        XCTAssertEqual(nsAttr.attribute(.xmarkupBlockKind, at: 0, effectiveRange: nil) as? String, "heading")
        XCTAssertEqual(nsAttr.attribute(.xmarkupHeadingLevel, at: 0, effectiveRange: nil) as? Int, 1)
    }

    func testCustomKeyWithUIKitAttributes() throws {
        let nsAttr = NSMutableAttributedString(string: "Colored")
        let fullRange = NSRange(location: 0, length: 7)
        nsAttr.addAttribute(.xmarkupTag, value: "span", range: fullRange)
        nsAttr.addAttribute(.foregroundColor, value: XMColor.red, range: fullRange)
        nsAttr.addAttribute(.font, value: XMFont.systemFont(ofSize: 16), range: fullRange)

        XCTAssertEqual(nsAttr.attribute(.xmarkupTag, at: 0, effectiveRange: nil) as? String, "span")
        let color = nsAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        #if canImport(UIKit)
        XCTAssertEqual(color, UIColor.red)
        #elseif canImport(AppKit)
        XCTAssertEqual(color, NSColor.red)
        #endif
    }

    func testListItemInfoKey() {
        let nsAttr = NSMutableAttributedString(string: "Item 1")
        nsAttr.addAttribute(.xmarkupListItemInfo, value: "ordered:0", range: NSRange(location: 0, length: 6))
        let value = nsAttr.attribute(.xmarkupListItemInfo, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(value, "ordered:0")
    }

    func testAttachmentRefKey() {
        let nsAttr = NSMutableAttributedString(string: "\u{FFFC}")
        nsAttr.addAttribute(.xmarkupAttachmentRef, value: "img-0", range: NSRange(location: 0, length: 1))
        let value = nsAttr.attribute(.xmarkupAttachmentRef, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(value, "img-0")
    }

    // MARK: - renderAttributed() 包装（标准属性可通过 AttributedString API 访问）

    func testRenderAttributedWrapsStandardAttributes() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<b>Bold</b>")
        let doc = MarkupDocument.from(result)
        let attr = doc.renderAttributed()

        var foundFont = false
        for run in attr.runs {
            #if canImport(UIKit)
            if let font = run.uiKit.font {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    foundFont = true
                }
            }
            #elseif canImport(AppKit)
            if let font = run.appKit.font {
                if font.fontDescriptor.symbolicTraits.contains(.bold) {
                    foundFont = true
                }
            }
            #endif
        }
        XCTAssertTrue(foundFont, "bold 字体的 trait 应通过 AttributedString wrapping 可读")
    }

    // MARK: - NSAttributedString 通过 enumerateAttribute 读取自定义 key

    func testCustomKeyAccessibleViaEnumeration() {
        let nsAttr = NSMutableAttributedString(string: "Hello World")
        let helloRange = (nsAttr.string as NSString).range(of: "Hello")
        nsAttr.addAttribute(.xmarkupTag, value: "bold", range: helloRange)

        var foundBold = false
        nsAttr.enumerateAttribute(.xmarkupTag, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let tag = value as? String, tag == "bold" {
                foundBold = true
            }
        }
        XCTAssertTrue(foundBold, "自定义 key 应通过 enumerateAttribute 可访问")
    }
}
