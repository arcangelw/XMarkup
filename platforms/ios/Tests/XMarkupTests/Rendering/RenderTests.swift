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

    // MARK: - 端到端集成

    func testEndToEndParseBuildRender() throws {
        let html = "<h1>Title</h1><p>Hello <b>world</b> <a href=\"https://example.com\">link</a></p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let attr = doc.render(theme: .default)
        let renderer = NSAttributedStringRenderer()
        let nsAttr = renderer.render(attr)

        // 验证包含所有文本
        XCTAssertTrue(nsAttr.string.contains("Title"))
        XCTAssertTrue(nsAttr.string.contains("Hello"))
        XCTAssertTrue(nsAttr.string.contains("world"))
        XCTAssertTrue(nsAttr.string.contains("link"))

        // 验证自定义 key 通过渲染器传递到 NS 层
        var foundHeadingLevel = false
        nsAttr.enumerateAttribute(NSAttributedString.Key(XMarkupHeadingLevelKey.name), in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let level = value as? Int, level == 1 {
                foundHeadingLevel = true
            }
        }
        XCTAssertTrue(foundHeadingLevel, "标题级别应通过渲染器传递到 NS 层")
    }

    func testEndToEndWithArticleTheme() throws {
        let html = "<p>Content with <code>code</code> and <b>bold</b>.</p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let attr = doc.render(theme: .article)
        let renderer = NSAttributedStringRenderer()
        let nsAttr = renderer.render(attr)

        // 验证文章主题的 base font（段落区域，非标题）
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize, 17)
    }

    func testEndToEndWithNSRenderer() throws {
        let html = "<p>Hello <b>bold</b></p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let attr = doc.render()

        let renderer = NSAttributedStringRenderer()
        let nsAttr = renderer.render(attr)
        let size = renderer.measure(attr, constrainedTo: 300)

        XCTAssertEqual(nsAttr.string, "Hello bold")
        XCTAssertGreaterThan(size.height, 0)
    }

    func testEndToEndDSLTheme() throws {
        let html = "<p>Text with <a href=\"https://example.com\">link</a></p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)

        let customTheme = MarkupTheme {
            BaseFont(XMFont.systemFont(ofSize: 18))
            Tag(.link) { container in
                #if canImport(UIKit)
                container.uiKit.foregroundColor = .systemPurple
                #elseif canImport(AppKit)
                container.appKit.foregroundColor = .systemPurple
                #endif
            }
        }
        let attr = doc.render(theme: customTheme)
        let renderer = NSAttributedStringRenderer()
        let nsAttr = renderer.render(attr)

        // 基础字体应为 18pt（纯段落，无标题缩放）
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 18)

        // 验证 link 颜色被主题覆盖为紫色
        let fullRange = NSRange(location: 0, length: nsAttr.length)
        var foundPurpleLink = false
        nsAttr.enumerateAttribute(.foregroundColor, in: fullRange) { value, _, stop in
            if let color = value as? XMColor {
                #if canImport(UIKit)
                var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                // systemPurple: r≈0.67, g≈0.13, b≈0.70
                if r > 0.4 && b > 0.4 && g < 0.3 {
                    foundPurpleLink = true
                    stop.pointee = true
                }
                #elseif canImport(AppKit)
                if let rgbColor = color.usingColorSpace(.sRGB) {
                    var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
                    rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                    if r > 0.4 && b > 0.4 && g < 0.3 {
                        foundPurpleLink = true
                        stop.pointee = true
                    }
                }
                #endif
            }
        }
        XCTAssertTrue(foundPurpleLink, "链接颜色应被 DSL 主题覆盖为紫色")
    }

    // MARK: - Code Review 修复验证

    func testHeadingFontSizeAlwaysApplied() throws {
        // h4 的 scale=1.0 字号与默认相同，跳过
        let levels = ["h1", "h2", "h3", "h5", "h6"]
        for level in levels {
            let attr = try parseAndRender("<\(level)>Title</\(level)>")
            let nsAttr = NSAttributedStringRenderer().render(attr)
            let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
            XCTAssertNotNil(font, "\(level) 应有字体")
            XCTAssertNotEqual(font?.pointSize, 16, "\(level) 字号不应为默认 16pt")
        }
    }

    func testRenderHeadingH2Scale() throws {
        let attr = try parseAndRender("<h2>Sub</h2>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font!.pointSize, 16 * 1.5, accuracy: 0.5)
    }

    func testRenderHeadingH6Scale() throws {
        let attr = try parseAndRender("<h6>Small</h6>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font!.pointSize, 16 * 0.67, accuracy: 0.5)
    }

    // MARK: - 更多渲染场景

    func testRenderPreHasMonospaceFont() throws {
        let attr = try parseAndRender("<pre>code block</pre>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #endif
    }

    func testRenderBlockquoteBlock() throws {
        let attr = try parseAndRender("<blockquote>quote text</blockquote>")
        let text = String(attr.characters)
        XCTAssertTrue(text.contains("quote text"))
    }

    func testRenderCSSBackgroundColor() throws {
        let attr = try parseAndRender("<span style=\"background-color:#00FF00\">green</span>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let bg = nsAttr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg, "background-color 应生效")
    }

    func testRenderCSSFontSize() throws {
        let attr = try parseAndRender("<span style=\"font-size:20px\">big</span>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font!.pointSize, 20, accuracy: 0.5)
    }

    func testRenderMultipleBlocksSeparation() throws {
        let attr = try parseAndRender("<h1>T</h1><p>P</p><p>Q</p>")
        let text = String(attr.characters)
        XCTAssertTrue(text.contains("T"))
        XCTAssertTrue(text.contains("P"))
        XCTAssertTrue(text.contains("Q"))
        XCTAssertTrue(text.contains("\n"), "块间应有换行分隔")
    }

    func testRenderListItemBlock() throws {
        let attr = try parseAndRender("<ul><li>Item</li></ul>")
        let text = String(attr.characters)
        XCTAssertTrue(text.contains("Item"))
    }

    func testRenderHorizontalRule() throws {
        let attr = try parseAndRender("<hr>")
        XCTAssertFalse(String(attr.characters).isEmpty)
    }

    func testRenderVideoAttachment() throws {
        let attr = try parseAndRender("<video src=\"v.mp4\"></video>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment { foundAttachment = true }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testRenderAudioAttachment() throws {
        let attr = try parseAndRender("<audio src=\"a.mp3\"></audio>")
        let nsAttr = NSAttributedStringRenderer().render(attr)
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment { foundAttachment = true }
        }
        XCTAssertTrue(foundAttachment)
    }
}
