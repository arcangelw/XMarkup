import XCTest
@testable import XMarkup

final class StyleConfigTests: XCTestCase {
    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    // MARK: - 预置主题

    func testDefaultThemeMarkStyle() {
        let config = XMarkupStyleConfig.default
        XCTAssertNotNil(config[.mark])
        XCTAssertNotNil(config[.mark]?.backgroundColor)
        XCTAssertNil(config.baseFont) // 使用系统默认 16pt
    }

    func testDarkThemeMarkStyle() {
        let config = XMarkupStyleConfig.dark
        XCTAssertNotNil(config[.mark]?.backgroundColor)
    }

    func testChatThemeBaseFont() {
        let config = XMarkupStyleConfig.chat
        XCTAssertEqual(config.baseFont?.pointSize, 14)
        XCTAssertNotNil(config[.link]?.foregroundColor)
    }

    func testArticleThemeHeadingFonts() {
        let config = XMarkupStyleConfig.article
        XCTAssertEqual(config.baseFont?.pointSize, 17)
        XCTAssertEqual(config[.heading1]?.font?.pointSize, 28)
        XCTAssertEqual(config[.heading2]?.font?.pointSize, 22)
        XCTAssertEqual(config[.heading3]?.font?.pointSize, 19)
        XCTAssertEqual(config.mediaPlaceholderSize, CGSize(width: 300, height: 200))
    }

    // MARK: - 自定义配置

    func testCustomTagStyleOverrides() throws {
        let result = try parse("<u>underline</u>")
        var config = XMarkupStyleConfig.default
        config[.underline] = XMarkupTagStyle(foregroundColor: XMColor.systemRed)
        let attr = result.makeAttributedString(config: config)
        let color = attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    func testSpanTransformerClosure() throws {
        let result = try parse("<b>bold</b>")
        var config = XMarkupStyleConfig.default
        nonisolated(unsafe) var transformedSpanTag: XMarkupTag?
        config.spanTransformer = { span, attrs in
            transformedSpanTag = span.tag
            attrs[.foregroundColor] = XMColor.systemPurple
        }
        let attr = result.makeAttributedString(config: config)
        XCTAssertEqual(transformedSpanTag, .bold)
        let color = attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    func testPostProcessorClosure() throws {
        let result = try parse("<b>bold</b>")
        var config = XMarkupStyleConfig.default
        nonisolated(unsafe) var postProcessed = false
        config.postProcessor = { str in
            postProcessed = true
            str.addAttribute(
                .kern,
                value: NSNumber(value: 1.5),
                range: NSRange(location: 0, length: str.length)
            )
        }
        let attr = result.makeAttributedString(config: config)
        XCTAssertTrue(postProcessed)
        let kern = attr.attribute(.kern, at: 0, effectiveRange: nil) as? NSNumber
        XCTAssertNotNil(kern)
    }

    // MARK: - 媒体渲染

    func testImagePlaceholderAttachment() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let attr = result.makeAttributedString()
        XCTAssertTrue(attr.length > 0)
        var foundAttachment = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testImageWithCustomProvider() throws {
        let result = try parse("<img src=\"custom.png\">")
        var config = XMarkupStyleConfig.default
        nonisolated(unsafe) var providerCalled = false
        config.imageProvider = { src in
            providerCalled = true
            XCTAssertEqual(src, "custom.png")
            return nil // 触发占位图回退
        }
        let _ = result.makeAttributedString(config: config)
        XCTAssertTrue(providerCalled)
    }

    func testVideoPlaceholderAttachment() throws {
        let result = try parse("<video src=\"movie.mp4\"></video>")
        let attr = result.makeAttributedString()
        var foundAttachment = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testAudioPlaceholderAttachment() throws {
        let result = try parse("<audio src=\"song.mp3\"></audio>")
        let attr = result.makeAttributedString()
        var foundAttachment = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testVideoWithSourceChild() throws {
        let result = try parse("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>")
        let attr = result.makeAttributedString()
        var foundAttachment = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testMediaPlaceholderSize() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let customSize = CGSize(width: 100, height: 80)
        var config = XMarkupStyleConfig.default
        config.mediaPlaceholderSize = customSize
        let attr = result.makeAttributedString(config: config)
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if let attachment = value as? NSTextAttachment {
                XCTAssertEqual(attachment.bounds.size, customSize)
            }
        }
    }
}
