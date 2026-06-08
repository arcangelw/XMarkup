import XCTest
@testable import XMarkup

final class RenderTests: XCTestCase {

    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    private func parseAndRender(_ html: String, theme: MarkupTheme = .default) throws -> AttributedString {
        let result = try parse(html)
        let doc = MarkupDocument.from(result)
        return doc.render(theme: theme)
    }

    // MARK: - 基础渲染

    func testRenderEmptyDocument() {
        let doc = MarkupDocument(blocks: [])
        let attr = doc.render()
        XCTAssertTrue(String(attr.characters).isEmpty)
    }

    func testRenderSingleParagraph() throws {
        let attr = try parseAndRender("<p>Hello</p>")
        XCTAssertEqual(String(attr.characters), "Hello")
    }

    func testRenderTwoParagraphs() throws {
        let attr = try parseAndRender("<p>First</p><p>Second</p>")
        let text = String(attr.characters)
        XCTAssertTrue(text.contains("First"))
        XCTAssertTrue(text.contains("Second"))
        // 块之间应有换行
        XCTAssertTrue(text.contains("\n"))
    }

    // MARK: - 字体属性

    func testRenderBoldFontTrait() throws {
        let attr = try parseAndRender("<b>bold</b>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.bold))
        #endif
    }

    func testRenderItalicFontTrait() throws {
        let attr = try parseAndRender("<i>italic</i>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.italic))
        #endif
    }

    func testRenderBoldItalicMerged() throws {
        let attr = try parseAndRender("<b><i>both</i></b>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.italic))
        #endif
    }

    // MARK: - 非字体属性

    func testRenderUnderline() throws {
        let attr = try parseAndRender("<u>under</u>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let style = nsAttr.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testRenderStrikethrough() throws {
        let attr = try parseAndRender("<s>strike</s>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let style = nsAttr.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testRenderLink() throws {
        let attr = try parseAndRender("<a href=\"https://example.com\">click</a>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let link = nsAttr.attribute(.link, at: 0, effectiveRange: nil) as? URL
        XCTAssertEqual(link?.absoluteString, "https://example.com")
    }

    func testRenderCodeHasMonospaceFont() throws {
        let attr = try parseAndRender("<code>print()</code>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #endif
    }

    func testRenderCodeHasBackgroundColor() throws {
        let attr = try parseAndRender("<code>code</code>", theme: .default)
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let bg = nsAttr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg, "<code> 使用默认主题应有背景色")
    }

    // MARK: - 自定义 XMarkupScope 属性

    func testRenderCarriesXMarkupTag() throws {
        let attr = try parseAndRender("<b>bold</b>")
        // 在 AttributedString 内部检查
        var found = false
        for run in attr.runs {
            if run[XMarkupTagKey.self] == "bold" {
                found = true
            }
        }
        XCTAssertTrue(found, "应包含 XMarkupTagKey = bold")
    }

    func testRenderCarriesHeadingLevel() throws {
        let attr = try parseAndRender("<h1>Title</h1>")
        var found = false
        for run in attr.runs {
            if run[XMarkupHeadingLevelKey.self] == 1 {
                found = true
            }
        }
        XCTAssertTrue(found, "应包含 XMarkupHeadingLevelKey = 1")
    }

    func testRenderCarriesLinkURL() throws {
        let attr = try parseAndRender("<a href=\"https://example.com\">click</a>")
        var found = false
        for run in attr.runs {
            if run[XMarkupLinkURLKey.self] == "https://example.com" {
                found = true
            }
        }
        XCTAssertTrue(found, "应包含 XMarkupLinkURLKey")
    }

    // MARK: - 主题覆盖

    func testRenderWithCustomTheme() throws {
        let attr = try parseAndRender("<p>Hello</p>", theme: MarkupTheme(baseFont: XMFont.systemFont(ofSize: 20)))
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 20)
    }

    // MARK: - CSS 样式

    func testRenderCSSForegroundColor() throws {
        let attr = try parseAndRender("<span style=\"color:#FF0000\">red</span>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let color = nsAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    // MARK: - 媒体附件

    func testRenderImageAttachment() throws {
        let attr = try parseAndRender("<img src=\"photo.jpg\">")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    // MARK: - 边界情况

    func testRenderUnknownTagNoCrash() throws {
        let attr = try parseAndRender("<custom>text</custom>")
        XCTAssertFalse(String(attr.characters).isEmpty)
    }

    func testRenderEmptyInput() throws {
        let attr = try parseAndRender("")
        XCTAssertTrue(String(attr.characters).isEmpty)
    }
}
