import XCTest
@testable import XMarkup

final class NSAttributedStringTests: XCTestCase {
    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    func testBoldFontTrait() throws {
        let result = try parse("<b>bold</b>")
        let attr = result.makeAttributedString()
        let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertTrue(try XCTUnwrap(font?.fontDescriptor.symbolicTraits.contains(boldTrait)))
    }

    func testItalicFontTrait() throws {
        let result = try parse("<i>italic</i>")
        let attr = result.makeAttributedString()
        let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertTrue(try XCTUnwrap(font?.fontDescriptor.symbolicTraits.contains(italicTrait)))
    }

    func testBoldItalicMerged() throws {
        let result = try parse("<b><i>both</i></b>")
        let attr = result.makeAttributedString()
        let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertTrue(try XCTUnwrap(font?.fontDescriptor.symbolicTraits.contains(boldTrait)))
        XCTAssertTrue(try XCTUnwrap(font?.fontDescriptor.symbolicTraits.contains(italicTrait)))
    }

    func testUnderlineStyle() throws {
        let result = try parse("<u>under</u>")
        let attr = result.makeAttributedString()
        let style = attr.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testStrikethroughStyle() throws {
        let result = try parse("<s>strike</s>")
        let attr = result.makeAttributedString()
        let style = attr.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testLinkAttribute() throws {
        let result = try parse("<a href=\"https://example.com\">click</a>")
        let attr = result.makeAttributedString()
        let link = attr.attribute(.link, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(link, "https://example.com")
    }

    func testCSSForegroundColor() throws {
        let result = try parse("<span style=\"color:#FF0000\">red</span>")
        let attr = result.makeAttributedString()
        let color = attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    func testCSSBackgroundColor() throws {
        let result = try parse("<span style=\"background-color:#0000FF\">bg</span>")
        let attr = result.makeAttributedString()
        let color = attr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    func testCustomBaseFontViaConfig() throws {
        let result = try parse("<b>text</b>")
        #if canImport(UIKit)
            let customFont = UIFont.systemFont(ofSize: 20)
        #elseif canImport(AppKit)
            let customFont = NSFont.systemFont(ofSize: 20)
        #endif
        var config = XMarkupStyleConfig()
        config.baseFont = customFont
        let attr = result.makeAttributedString(config: config)
        let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 20)
    }

    func testUnknownTagNoCrash() throws {
        let result = try parse("<custom>text</custom>")
        let attr = result.makeAttributedString()
        XCTAssertEqual(attr.string, "text")
    }

    func testEmptyInputReturnsEmpty() throws {
        let result = try parse("")
        let attr = result.makeAttributedString()
        XCTAssertEqual(attr.string, "")
    }

    // MARK: - Mark 标签测试

    func testMarkBackgroundColor() throws {
        let result = try parse("<mark>highlighted</mark>")
        let attr = result.makeAttributedString()
        let bg = attr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg)
    }

    func testMarkWithConfigOverride() throws {
        let result = try parse("<mark>highlighted</mark>")
        var config = XMarkupStyleConfig.default
        config[.mark] = XMarkupTagStyle(backgroundColor: XMColor.systemRed.withAlphaComponent(0.5))
        let attr = result.makeAttributedString(config: config)
        let bg = attr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg)
    }

    // MARK: - 默认 config 行为

    func testDefaultConfigMatchesNoArg() throws {
        let result = try parse("<b>bold</b> normal <i>italic</i>")
        let attr = result.makeAttributedString()
        let attrDefault = result.makeAttributedString(config: .default)
        XCTAssertEqual(attr.string, attrDefault.string)
    }
}

// MARK: - 跨平台字体 Trait 常量（测试用）

#if canImport(UIKit)
    private let boldTrait: UIFontDescriptor.SymbolicTraits = .traitBold
    private let italicTrait: UIFontDescriptor.SymbolicTraits = .traitItalic
#elseif canImport(AppKit)
    private let boldTrait: NSFontDescriptor.SymbolicTraits = .bold
    private let italicTrait: NSFontDescriptor.SymbolicTraits = .italic
#endif
