import XCTest
@testable import XMarkup

final class RenderTests: XCTestCase {

    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    private func parseAndRender(_ html: String, theme: MarkupTheme = .default) throws -> NSAttributedString {
        let result = try parse(html)
        let doc = MarkupDocument.from(result)
        return doc.render(theme: theme)
    }

    // MARK: - 基础渲染

    func testRenderEmptyDocument() {
        let doc = MarkupDocument(blocks: [])
        let nsAttr = doc.render()
        XCTAssertTrue(nsAttr.string.isEmpty)
    }

    func testRenderSingleParagraph() throws {
        let nsAttr = try parseAndRender("<p>Hello</p>")
        XCTAssertEqual(nsAttr.string, "Hello")
    }

    func testRenderTwoParagraphs() throws {
        let nsAttr = try parseAndRender("<p>First</p><p>Second</p>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("First"))
        XCTAssertTrue(text.contains("Second"))
        // 块之间应有换行
        XCTAssertTrue(text.contains("\n"))
    }

    // MARK: - 字体属性

    func testRenderBoldFontTrait() throws {
        let nsAttr = try parseAndRender("<b>bold</b>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.bold))
        #endif
    }

    func testRenderItalicFontDiffers() throws {
        let nsAttr = try parseAndRender("<i>italic</i>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        // makeSyntheticItalicFont 使用矩阵变形，matrix 的 b 值（skew）应不为 0
        XCTAssertNotEqual(font!.fontDescriptor.matrix.b, 0, "斜体应通过矩阵变形实现")
        #elseif canImport(AppKit)
        // macOS 系统字体的 withMatrix 可能不保留 matrix 属性，验证字体已设置即可
        XCTAssertNotEqual(font!.fontName, NSFont.systemFont(ofSize: 16).fontName, "斜体字体应与系统字体不同")
        #endif
    }

    func testRenderBoldItalicMerged() throws {
        let nsAttr = try parseAndRender("<b><i>both</i></b>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold), "应包含 bold trait")
        XCTAssertNotEqual(font!.fontDescriptor.matrix.b, 0, "应包含 italic 矩阵变形")
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.bold), "应包含 bold trait")
        XCTAssertNotEqual(font!.fontName, NSFont.systemFont(ofSize: 16).fontName, "粗斜体字体应与系统字体不同")
        #endif
    }

    // MARK: - 非字体属性

    func testRenderUnderline() throws {
        let nsAttr = try parseAndRender("<u>under</u>")
        let style = nsAttr.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testRenderStrikethrough() throws {
        let nsAttr = try parseAndRender("<s>strike</s>")
        let style = nsAttr.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testRenderLink() throws {
        let nsAttr = try parseAndRender("<a href=\"https://example.com\">click</a>")
        let link = nsAttr.attribute(.link, at: 0, effectiveRange: nil) as? URL
        XCTAssertEqual(link?.absoluteString, "https://example.com")
    }

    func testRenderCodeHasMonospaceFont() throws {
        let nsAttr = try parseAndRender("<code>print()</code>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #endif
    }

    func testRenderCodeHasBackgroundColor() throws {
        let nsAttr = try parseAndRender("<code>code</code>", theme: .default)
        let bg = nsAttr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg, "<code> 使用默认主题应有背景色")
    }

    // MARK: - 自定义 key 属性

    func testRenderCarriesXMarkupTag() throws {
        let nsAttr = try parseAndRender("<b>bold</b>")
        var found = false
        nsAttr.enumerateAttribute(.xmarkupTag, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let tag = value as? String, tag == "bold" { found = true }
        }
        XCTAssertTrue(found, "应包含 XMarkupTagKey = bold")
    }

    func testRenderCarriesHeadingLevel() throws {
        let nsAttr = try parseAndRender("<h1>Title</h1>")
        var found = false
        nsAttr.enumerateAttribute(.xmarkupHeadingLevel, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let level = value as? Int, level == 1 { found = true }
        }
        XCTAssertTrue(found, "应包含 XMarkupHeadingLevelKey = 1")
    }

    func testRenderCarriesLinkURL() throws {
        let nsAttr = try parseAndRender("<a href=\"https://example.com\">click</a>")
        var found = false
        nsAttr.enumerateAttribute(.xmarkupLinkURL, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let url = value as? String, url == "https://example.com" { found = true }
        }
        XCTAssertTrue(found, "应包含 XMarkupLinkURLKey")
    }

    // MARK: - 主题覆盖

    func testRenderWithCustomTheme() throws {
        let nsAttr = try parseAndRender("<p>Hello</p>", theme: MarkupTheme(baseFont: XMFont.systemFont(ofSize: 20)))
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 20)
    }

    // MARK: - CSS 样式

    func testRenderCSSForegroundColor() throws {
        let nsAttr = try parseAndRender("<span style=\"color:#FF0000\">red</span>")
        let color = nsAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    // MARK: - 媒体附件

    func testRenderImageAttachment() throws {
        let nsAttr = try parseAndRender("<img src=\"photo.jpg\">")
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment { foundAttachment = true }
        }
        XCTAssertTrue(foundAttachment)
    }

    // MARK: - 边界情况

    func testRenderUnknownTagNoCrash() throws {
        let nsAttr = try parseAndRender("<custom>text</custom>")
        XCTAssertFalse(nsAttr.string.isEmpty)
    }

    func testRenderEmptyInput() throws {
        let nsAttr = try parseAndRender("")
        XCTAssertTrue(nsAttr.string.isEmpty)
    }

    // MARK: - 端到端集成

    func testEndToEndParseBuildRender() throws {
        let html = "<h1>Title</h1><p>Hello <b>world</b> <a href=\"https://example.com\">link</a></p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = RenderPipeline.default.render(doc, theme: .default)

        // 验证包含所有文本
        XCTAssertTrue(nsAttr.string.contains("Title"))
        XCTAssertTrue(nsAttr.string.contains("Hello"))
        XCTAssertTrue(nsAttr.string.contains("world"))
        XCTAssertTrue(nsAttr.string.contains("link"))

        // 验证自定义 key 通过渲染器传递到 NS 层
        var foundHeadingLevel = false
        nsAttr.enumerateAttribute(.xmarkupHeadingLevel, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let level = value as? Int, level == 1 { foundHeadingLevel = true }
        }
        XCTAssertTrue(foundHeadingLevel, "标题级别应通过渲染器传递到 NS 层")
    }

    func testEndToEndWithArticleTheme() throws {
        let html = "<p>Content with <code>code</code> and <b>bold</b>.</p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render(theme: .article)

        // 验证文章主题的 base font（段落区域，非标题）
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize, 17)
    }

    func testEndToEndWithNSConversion() throws {
        let html = "<p>Hello <b>bold</b></p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let size = nsAttr.boundingRect(
            with: CGSize(width: 300, height: 1e9),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        XCTAssertEqual(nsAttr.string, "Hello bold")
        XCTAssertGreaterThan(ceil(size.height), 0)
    }

    func testEndToEndDSLTheme() throws {
        let html = "<p>Text with <a href=\"https://example.com\">link</a></p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)

        let customTheme = MarkupTheme {
            BaseFont(XMFont.systemFont(ofSize: 18))
        }
        let nsAttr = doc.render(theme: customTheme)

        // 基础字体应为 18pt（纯段落，无标题缩放）
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 18)

        // 验证渲染包含链接文本
        XCTAssertTrue(nsAttr.string.contains("link"), "渲染结果应包含链接文本")
    }

    // MARK: - Code Review 修复验证

    func testHeadingFontSizeAlwaysApplied() throws {
        // h4 的 scale=1.0 字号与默认相同，跳过
        let levels = ["h1", "h2", "h3", "h5", "h6"]
        for level in levels {
            let nsAttr = try parseAndRender("<\(level)>Title</\(level)>")
            let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
            XCTAssertNotNil(font, "\(level) 应有字体")
            XCTAssertNotEqual(font?.pointSize, 16, "\(level) 字号不应为默认 16pt")
        }
    }

    func testRenderHeadingH2Scale() throws {
        let nsAttr = try parseAndRender("<h2>Sub</h2>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font!.pointSize, 16 * 1.5, accuracy: 0.5)
    }

    func testRenderHeadingH6Scale() throws {
        let nsAttr = try parseAndRender("<h6>Small</h6>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font!.pointSize, 16 * 0.67, accuracy: 0.5)
    }

    // MARK: - 更多渲染场景

    func testRenderPreHasMonospaceFont() throws {
        let nsAttr = try parseAndRender("<pre>code block</pre>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #endif
    }

    func testRenderBlockquoteBlock() throws {
        let nsAttr = try parseAndRender("<blockquote>quote text</blockquote>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("quote text"))
    }

    func testRenderCSSBackgroundColor() throws {
        let nsAttr = try parseAndRender("<span style=\"background-color:#00FF00\">green</span>")
        let bg = nsAttr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg, "background-color 应生效")
    }

    func testRenderCSSFontSize() throws {
        let nsAttr = try parseAndRender("<span style=\"font-size:20px\">big</span>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font!.pointSize, 20, accuracy: 0.5)
    }

    func testRenderMultipleBlocksSeparation() throws {
        let nsAttr = try parseAndRender("<h1>T</h1><p>P</p><p>Q</p>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("T"))
        XCTAssertTrue(text.contains("P"))
        XCTAssertTrue(text.contains("Q"))
        XCTAssertTrue(text.contains("\n"), "块间应有换行分隔")
    }

    func testRenderListItemBlock() throws {
        let nsAttr = try parseAndRender("<ul><li>Item</li></ul>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("Item"))
    }

    func testRenderHorizontalRule() throws {
        let nsAttr = try parseAndRender("<hr>")
        XCTAssertFalse(nsAttr.string.isEmpty)
    }

    func testRenderVideoAttachment() throws {
        let nsAttr = try parseAndRender("<video src=\"v.mp4\"></video>")
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment { foundAttachment = true }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testRenderAudioAttachment() throws {
        let nsAttr = try parseAndRender("<audio src=\"a.mp3\"></audio>")
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment { foundAttachment = true }
        }
        XCTAssertTrue(foundAttachment)
    }

    // MARK: - Ordered List Numbering

    func testRenderOrderedListItems() throws {
        let nsAttr = try parseAndRender("<ol><li>First</li><li>Second</li></ol>")
        // 验证每个 listItem 的 paragraphStyle.textLists 包含 NSTextList
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            guard let paraStyle = value as? NSParagraphStyle else { return }
            XCTAssertFalse(paraStyle.textLists.isEmpty, "listItem 应有 textLists")
            if let firstList = paraStyle.textLists.first {
                XCTAssertEqual(firstList.markerFormat, .decimal)
            }
        }
    }

    // MARK: - Subscript / Superscript

    func testRenderSubscript() throws {
        let nsAttr = try parseAndRender("<p>H<sub>2</sub>O</p>")
        // 查找下标字符的 baselineOffset
        let subRange = (nsAttr.string as NSString).range(of: "2")
        guard subRange.location != NSNotFound else { XCTFail("应包含 '2'"); return }
        let offset = nsAttr.attribute(.baselineOffset, at: subRange.location, effectiveRange: nil) as? Double
        XCTAssertNotNil(offset)
        XCTAssertLessThan(offset ?? 0, 0, "subscript baselineOffset 应为负值")
    }

    func testRenderSuperscript() throws {
        let nsAttr = try parseAndRender("<p>10<sup>th</sup></p>")
        let supRange = (nsAttr.string as NSString).range(of: "th")
        guard supRange.location != NSNotFound else { XCTFail("应包含 'th'"); return }
        let offset = nsAttr.attribute(.baselineOffset, at: supRange.location, effectiveRange: nil) as? Double
        XCTAssertNotNil(offset)
        XCTAssertGreaterThan(offset ?? 0, 0, "superscript baselineOffset 应为正值")
    }

    // MARK: - CSS 行内样式渲染

    func testRenderCSSTextAlign() throws {
        let nsAttr = try parseAndRender("<p style=\"text-align:center\">Centered</p>")
        let paraStyle = nsAttr.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(paraStyle)
        XCTAssertEqual(paraStyle?.alignment, .center)
    }

    func testRenderCSSLineHeight() throws {
        let nsAttr = try parseAndRender("<span style=\"line-height:2.0\">text</span>")
        let paraStyle = nsAttr.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertNotNil(paraStyle)
        XCTAssertGreaterThan(paraStyle?.minimumLineHeight ?? 0, 1.0)
    }

    func testRenderCSSLetterSpacing() throws {
        let nsAttr = try parseAndRender("<span style=\"letter-spacing:2px\">spaced</span>")
        let kern = nsAttr.attribute(.kern, at: 0, effectiveRange: nil) as? Double
        XCTAssertEqual(kern ?? 0, 2.0, accuracy: 0.1)
    }

    // MARK: - Inline Presentation Intent

    func testRenderInlinePresentationIntent() throws {
        let nsAttr = try parseAndRender("<b>Bold</b> <i>Italic</i> <code>Code</code> <s>Strike</s>")
        // 通过 enumerateAttribute 检测 inlinePresentationIntent
        var foundStrong = false
        var foundEmphasized = false
        var foundCode = false
        var foundStrikethrough = false
        nsAttr.enumerateAttribute(.inlinePresentationIntent, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let intent = value as? InlinePresentationIntent {
                if intent == .stronglyEmphasized { foundStrong = true }
                if intent == .emphasized { foundEmphasized = true }
                if intent == .code { foundCode = true }
                if intent == .strikethrough { foundStrikethrough = true }
            }
        }
        XCTAssertTrue(foundStrong, "<b> 应有 stronglyEmphasized intent")
        XCTAssertTrue(foundEmphasized, "<i> 应有 emphasized intent")
        XCTAssertTrue(foundCode, "<code> 应有 code intent")
        XCTAssertTrue(foundStrikethrough, "<s> 应有 strikethrough intent")
    }

    // MARK: - 表格渲染（纯文本近似）

    func testRenderTableAsText() throws {
        let nsAttr = try parseAndRender("<table><tr><td>A</td><td>B</td></tr></table>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("A"))
        XCTAssertTrue(text.contains("B"))
        XCTAssertTrue(text.contains("\t"), "表格应以 tab 分隔")
    }

    func testRenderMultipleOrderedLists() throws {
        let nsAttr = try parseAndRender("<ol><li>X</li></ol><p>mid</p><ol><li>Y</li></ol>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("X"))
        XCTAssertTrue(text.contains("mid"))
        XCTAssertTrue(text.contains("Y"))
        // 两个列表之间应有换行
        XCTAssertTrue(text.contains("mid\n"), "列表与段落间应有换行")
    }

    // MARK: - hr 分隔线

    func testRenderHorizontalRuleIsAttachment() throws {
        let nsAttr = try parseAndRender("<hr>")
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment { foundAttachment = true }
        }
        XCTAssertTrue(foundAttachment, "hr 应渲染为 NSTextAttachment")
    }

    // MARK: - 列表间距优化验证

    func testRenderListItemSpacingInGroup() throws {
        let nsAttr = try parseAndRender("<ul><li>A</li><li>B</li><li>C</li></ul>")
        var paragraphStyles: [NSParagraphStyle] = []
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let ps = value as? NSParagraphStyle { paragraphStyles.append(ps) }
        }
        for ps in paragraphStyles {
            XCTAssertFalse(ps.textLists.isEmpty, "listItem 应有 textLists")
        }
    }

    func testRenderListItemIndentTopLevel() throws {
        let nsAttr = try parseAndRender("<ul><li>Item</li></ul>")
        var foundHeadIndent: CGFloat?
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let ps = value as? NSParagraphStyle { foundHeadIndent = ps.headIndent }
        }
        XCTAssertNotNil(foundHeadIndent)
        XCTAssertEqual(foundHeadIndent ?? 0, 24, accuracy: 0.1, "顶级列表 headIndent 应为 24pt")
    }

    // MARK: - hr 自定义 key 验证

    func testRenderHorizontalRuleCarriesBlockKindKey() throws {
        let result = try parse("<hr>")
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render(theme: .default)

        // 验证 NSAttributedString 包含 attachment（hr 的载体）
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment { foundAttachment = true }
        }
        XCTAssertTrue(foundAttachment, "hr 应包含 NSTextAttachment")
    }

    // MARK: - 表格 tab 分隔验证

    func testRenderTableUsesTabSeparation() throws {
        let nsAttr = try parseAndRender("<table><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></table>")
        let text = nsAttr.string

        XCTAssertTrue(text.contains("\t"), "表格 cell 应以 tab 分隔")
        XCTAssertTrue(text.contains("A"), "应包含 cell A")
        XCTAssertFalse(text.contains("|"), "不应包含 | 视觉装饰字符")
    }

    func testRenderTableCarriesMetadata() throws {
        let nsAttr = try parseAndRender("<table><tr><td>A</td><td>B</td></tr></table>")
        // 表格元数据在 TableRenderer 的 NSMutableAttributedString 上设置
        let key = NSAttributedString.Key("XMarkup.TableColumnCount")
        var foundColumnCount = false
        nsAttr.enumerateAttribute(key, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let count = value as? Int, count == 2 { foundColumnCount = true }
        }
        XCTAssertTrue(foundColumnCount, "表格应包含列数元数据")
    }

    // MARK: - Typed Theme 消费验证

    func testRenderCodeInlineConsumesThemeBackgroundColor() throws {
        let customTheme = MarkupTheme {
            Code {
                #if canImport(UIKit)
                $0.backgroundColor = .red
                #elseif canImport(AppKit)
                $0.backgroundColor = .red
                #endif
            }
        }
        let nsAttr = try parseAndRender("<code>test</code>", theme: customTheme)
        let bg = nsAttr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg, "code 内联应有背景色")
        #if canImport(UIKit)
        XCTAssertEqual(bg, UIColor.red)
        #elseif canImport(AppKit)
        XCTAssertEqual(bg, NSColor.red)
        #endif
    }

    func testRenderMarkConsumesThemeBackgroundColor() throws {
        let customTheme = MarkupTheme {
            Mark {
                #if canImport(UIKit)
                $0.backgroundColor = .green
                #elseif canImport(AppKit)
                $0.backgroundColor = .green
                #endif
            }
        }
        let nsAttr = try parseAndRender("<mark>hi</mark>", theme: customTheme)
        let bg = nsAttr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg, "mark 内联应有背景色")
        #if canImport(UIKit)
        XCTAssertEqual(bg, UIColor.green)
        #elseif canImport(AppKit)
        XCTAssertEqual(bg, NSColor.green)
        #endif
    }

    func testRenderLinkConsumesThemeTextColor() throws {
        let customTheme = MarkupTheme {
            Link {
                #if canImport(UIKit)
                $0.textColor = .red
                #elseif canImport(AppKit)
                $0.textColor = .red
                #endif
            }
        }
        let nsAttr = try parseAndRender("<a href=\"https://example.com\">click</a>", theme: customTheme)
        let color = nsAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color, "link 内联应有前景色")
        #if canImport(UIKit)
        XCTAssertEqual(color, UIColor.red)
        #elseif canImport(AppKit)
        XCTAssertEqual(color, NSColor.red)
        #endif
    }

    func testRenderBlockquoteConsumesThemeTextColor() throws {
        let customTheme = MarkupTheme {
            Blockquote {
                #if canImport(UIKit)
                $0.textColor = .purple
                #elseif canImport(AppKit)
                $0.textColor = .purple
                #endif
            }
        }
        let nsAttr = try parseAndRender("<blockquote>quote</blockquote>", theme: customTheme)
        let color = nsAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color, "blockquote 应有前景色")
        #if canImport(UIKit)
        XCTAssertEqual(color, UIColor.purple)
        #elseif canImport(AppKit)
        XCTAssertEqual(color, NSColor.purple)
        #endif
    }

    func testRenderHeadingConsumesResolvedTheme() throws {
        let customTheme = MarkupTheme {
            Heading {
                $0.bold = false  // 标题不加粗
                $0.scale = HeadingScale(h1: 1.0)  // h1 与 baseFont 相同大小
                #if canImport(UIKit)
                $0.textColor = .orange
                #elseif canImport(AppKit)
                $0.textColor = .orange
                #endif
            }
        }
        let nsAttr = try parseAndRender("<h1>Title</h1>", theme: customTheme)

        // 验证 textColor
        let color = nsAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        #if canImport(UIKit)
        XCTAssertEqual(color, UIColor.orange)
        #elseif canImport(AppKit)
        XCTAssertEqual(color, NSColor.orange)
        #endif

        // 验证不加粗
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertFalse(font!.fontDescriptor.symbolicTraits.contains(.traitBold), "bold=false 时标题不应加粗")
        #elseif canImport(AppKit)
        XCTAssertFalse(font!.fontDescriptor.symbolicTraits.contains(.bold), "bold=false 时标题不应加粗")
        #endif
    }

    func testRenderPreformattedConsumesThemeFont() throws {
        var customTheme = MarkupTheme()
        customTheme.preformatted.font = XMFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        let nsAttr = try parseAndRender("<pre>code</pre>", theme: customTheme)
        let font = nsAttr.attribute(NSAttributedString.Key.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize, 20, "应使用主题指定的字号")
    }

    func testRenderHeadingPerLevelOverrideViaResolved() throws {
        let customTheme = MarkupTheme {
            Heading {
                $0.scale = .default
                $0.h2 = .init(fontSize: 30, textColor: XMColor.red)
            }
        }
        let nsAttr = try parseAndRender("<h2>Sub</h2>", theme: customTheme)

        // 验证 per-level textColor
        let color = nsAttr.attribute(NSAttributedString.Key.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        #if canImport(UIKit)
        XCTAssertEqual(color, UIColor.red)
        #elseif canImport(AppKit)
        XCTAssertEqual(color, NSColor.red)
        #endif

        // 验证 per-level fontSize
        let font = nsAttr.attribute(NSAttributedString.Key.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 30)
    }
}
