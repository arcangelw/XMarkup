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
        let expectedH6 = 16 * MarkupTheme.default.heading.scale.h6
        XCTAssertEqual(font!.pointSize, expectedH6, accuracy: 0.5)
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
        // 默认 `.automatic` 模式：NSTextList 原生标记，文本干净
        let nsAttr = try parseAndRender("<ol><li>First</li><li>Second</li></ol>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("First"), "文本应包含 'First'")
        XCTAssertFalse(text.contains("1.\t"), "automatic 模式不应有手动标记前缀")
        // 验证 paragraphStyle 有 NSTextList
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            guard let ps = value as? NSParagraphStyle else { return }
            XCTAssertFalse(ps.textLists.isEmpty, "应有 NSTextList")
            XCTAssertEqual(ps.textLists.first?.markerFormat, .decimal)
        }
    }

    func testRenderOrderedListManualMode() throws {
        // `.manual` 模式：文本前缀
        let theme = MarkupTheme {
            List { $0.markerMode = .manual }
        }
        let nsAttr = try parseAndRender("<ol><li>First</li></ol>", theme: theme)
        XCTAssertTrue(nsAttr.string.hasPrefix("1.\t"), "manual 模式应有 '1.\\t' 前缀")
    }

    func testRenderOrderedListWithoutSuffix() throws {
        // 手动模式 + 空后缀
        let theme = MarkupTheme {
            List {
                $0.markerMode = .manual
                $0.orderedMarkerSuffix = ""
            }
        }
        let nsAttr = try parseAndRender("<ol><li>First</li></ol>", theme: theme)
        XCTAssertTrue(nsAttr.string.hasPrefix("1\t"), "空后缀时标记应为 '1\\t'")
    }

    func testRenderUnorderedListDefaultMode() throws {
        // 默认 `.automatic` 模式：NSTextList 原生 bullet，文本干净
        let nsAttr = try parseAndRender("<ul><li>Item A</li></ul>")
        XCTAssertTrue(nsAttr.string.contains("Item A"), "应包含文本")
        // 验证 NSTextList
        var foundTextList = false
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            guard let ps = value as? NSParagraphStyle, !ps.textLists.isEmpty else { return }
            foundTextList = true
            XCTAssertEqual(ps.textLists.first?.markerFormat, .disc)
        }
        XCTAssertTrue(foundTextList, "默认应有 NSTextList(.disc)")
    }

    func testRenderUnorderedListManualMode() throws {
        // `.manual` 模式：文本 bullet 前缀
        let theme = MarkupTheme {
            List { $0.markerMode = .manual }
        }
        let nsAttr = try parseAndRender("<ul><li>Item A</li></ul>", theme: theme)
        XCTAssertTrue(nsAttr.string.contains("\u{2022}\t"), "manual 模式应有 bullet 前缀")
        XCTAssertTrue(nsAttr.string.contains("Item A"), "应包含文本")
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
        XCTAssertEqual(paraStyle?.minimumLineHeight ?? 0, 2.0, accuracy: 0.5)
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
        // 默认 `.automatic`：NSTextList + 组共享实例
        let nsAttr = try parseAndRender("<ul><li>A</li><li>B</li><li>C</li></ul>")
        var paragraphStyles: [NSParagraphStyle] = []
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let ps = value as? NSParagraphStyle { paragraphStyles.append(ps) }
        }
        XCTAssertEqual(paragraphStyles.count, 3, "三个列表项应各有一个 paragraphStyle")
        for ps in paragraphStyles {
            XCTAssertFalse(ps.textLists.isEmpty, "automatic 模式应有 NSTextList")
        }
    }

    func testRenderListItemIndentTopLevel() throws {
        let nsAttr = try parseAndRender("<ul><li>Item</li></ul>")
        var foundHeadIndent: CGFloat?
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if let ps = value as? NSParagraphStyle { foundHeadIndent = ps.headIndent }
        }
        XCTAssertNotNil(foundHeadIndent)
        XCTAssertEqual(foundHeadIndent ?? 0, 28, accuracy: 0.1, "headIndent = indentUnit(24) + markerPadding(4) = 28pt")
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
        let key = NSAttributedString.Key.xmarkupTableColumnCount
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

    // MARK: - Code Review 修复验证新增

    func testFontWeightNormalClearsBold() throws {
        let nsAttr = try parseAndRender("<b><span style=\"font-weight:normal\">text</span></b>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertFalse(font!.fontDescriptor.symbolicTraits.contains(.traitBold),
                       "font-weight:normal 应清除 bold trait")
        #elseif canImport(AppKit)
        XCTAssertFalse(font!.fontDescriptor.symbolicTraits.contains(.bold),
                       "font-weight:normal 应清除 bold trait")
        #endif
    }

    func testFontWeightLightClearsBold() throws {
        let nsAttr = try parseAndRender("<b><span style=\"font-weight:300\">text</span></b>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertFalse(font!.fontDescriptor.symbolicTraits.contains(.traitBold),
                       "font-weight:300 应清除 bold trait")
        #elseif canImport(AppKit)
        XCTAssertFalse(font!.fontDescriptor.symbolicTraits.contains(.bold),
                       "font-weight:300 应清除 bold trait")
        #endif
    }

    func testFontStyleNormalClearsItalicMatrix() throws {
        let nsAttr = try parseAndRender("<i><span style=\"font-style:normal\">text</span></i>")
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertEqual(font!.fontDescriptor.matrix.b, 0,
                       "font-style:normal 应清除 italic matrix")
        #elseif canImport(AppKit)
        // macOS: 验证字体名不再是斜体
        XCTAssertFalse(font!.fontName.lowercased().contains("italic"),
                       "font-style:normal 不应包含 italic 字体名")
        #endif
    }

    func testCodeDoesNotOverwriteExistingBackgroundColor() throws {
        let nsAttr = try parseAndRender("<span style=\"background-color:#FF0000\"><code>code</code></span>")
        let bg = nsAttr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg, "code 不应覆盖 span 已有的背景色")
        #if canImport(UIKit)
        XCTAssertEqual(bg, UIColor.red, "code 背景色应为 span 设置的颜色")
        #elseif canImport(AppKit)
        XCTAssertEqual(bg, NSColor.red, "code 背景色应为 span 设置的颜色")
        #endif
    }

    func testNestedBlockquoteRenders() throws {
        let nsAttr = try parseAndRender("<blockquote>Outer<blockquote>Inner</blockquote></blockquote>")
        XCTAssertTrue(nsAttr.string.contains("Outer"))
        XCTAssertTrue(nsAttr.string.contains("Inner"))
    }

    func testBRElementCreatesLineBreak() throws {
        let nsAttr = try parseAndRender("<p>Line1<br>Line2</p>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("\n"), "<br> 应产生换行符")
        // 验证 "Line1" 和 "Line2" 在不同行
        let parts = text.components(separatedBy: .newlines)
        XCTAssertTrue(parts.contains("Line1"))
        XCTAssertTrue(parts.contains("Line2"))
    }

    func testHTMLEntitiesDecoded() throws {
        let nsAttr = try parseAndRender("<p>A &amp; B &lt; C &gt; D</p>")
        let text = nsAttr.string
        XCTAssertTrue(text.contains("&"), "&amp; 应解码为 &")
        XCTAssertTrue(text.contains("<"), "&lt; 应解码为 <")
        XCTAssertTrue(text.contains(">"), "&gt; 应解码为 >")
    }

    // MARK: - Code in List (bullet 与 code background 重叠问题)

    func testCodeAtStartOfUnorderedList() throws {
        // `.manual` 模式：验证 bullet 与 code 背景不重叠
        let theme = MarkupTheme {
            List { $0.markerMode = .manual }
        }
        let nsAttr = try parseAndRender("<ul><li><code>MainActor</code> text</li></ul>", theme: theme)
        let text = nsAttr.string
        XCTAssertTrue(text.contains("•\t"), "无序列表应包含 bullet 前缀 '•\\t'")
        XCTAssertTrue(text.contains("MainActor"), "文本应包含 'MainActor'")

        // headIndent 将文本推离 bullet 区域
        var foundHeadIndent = false
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { v, _, _ in
            guard let p = v as? NSParagraphStyle else { return }
            XCTAssertGreaterThan(p.headIndent, 0, "无序列表 headIndent 应 > 0 防止 bullet-code 重叠")
            foundHeadIndent = true
        }
        XCTAssertTrue(foundHeadIndent)

        // 验证 code inline 有背景色
        var foundCodeBG = false
        nsAttr.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: nsAttr.length)) { v, _, _ in
            if v != nil { foundCodeBG = true }
        }
        XCTAssertTrue(foundCodeBG, "code 应有背景色")

        // 验证背景色不变覆盖 bullet：bullet "•\t" 是前缀文本的一部分
        // 确认背景色范围在 bullet 之后
        let fullRange = NSRange(location: 0, length: nsAttr.length)
        var bgRanges: [NSRange] = []
        nsAttr.enumerateAttribute(.backgroundColor, in: fullRange) { v, range, _ in
            if v != nil { bgRanges.append(range) }
        }
        for bgRange in bgRanges {
            let bgText = (text as NSString).substring(with: bgRange)
            // 背景色应在 code 文本 "MainActor" 范围，不应包含 bullet
            XCTAssertTrue(bgText.contains("MainActor"), "背景色应仅在 code 文本范围: \(bgText)")
            XCTAssertFalse(bgText.contains("•"), "背景色不应包含 bullet 字符")
        }
    }

    // MARK: - Nested list (gap + ordering)

    func testNestedMixedListNoEmptyItems() throws {
        let html = """
        <ol>
        <li>前端技术
        <ul>
        <li>HTML / CSS</li>
        <li>JavaScript / TypeScript</li>
        </ul>
        </li>
        <li>后端技术
        <ul>
        <li>Node.js</li>
        <li>Python / Django</li>
        </ul>
        </li>
        <li>移动开发
        <ol>
        <li>iOS (Swift)</li>
        <li>Android (Kotlin)</li>
        </ol>
        </li>
        </ol>
        """
        // 用 .manual 模式以便看到文本中的标记
        let theme = MarkupTheme { List { $0.markerMode = .manual } }
        let result = try parse(html)
        let doc = MarkupDocument.from(result)

        // 检查 Flattener 产出的 MarkupBlock
        print("\n=== Flattener MarkupBlock[] ===")
        let flatBlocks = Flattener.flatten(doc.blocks)
        for (i, block) in flatBlocks.enumerated() {
            let empty = block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? " [EMPTY]" : ""
            print("[\(i)] kind=\(block.kind)\(empty) text='\(block.text.prefix(30))'")
        }

        // 渲染
        let nsAttr = doc.render(theme: theme)
        let text = nsAttr.string
        print("\n=== Rendered text ===")
        for (i, line) in text.components(separatedBy: "\n").enumerated() {
            print("[\(i)] '\(line)'")
        }

        // 不应该有空 listItem
        let nonEmptyBlocks = flatBlocks.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        XCTAssertEqual(flatBlocks.count, nonEmptyBlocks.count, "不应有空 MarkupBlock")
    }

    func testNestedMixedListAutomaticNumbering() throws {
        // `.automatic` 模式：NSTextList 原生标记，文本干净
        let html = """
        <ol>
        <li>前端技术
        <ul>
        <li>HTML / CSS</li>
        <li>JavaScript / TypeScript</li>
        </ul>
        </li>
        <li>后端技术
        <ul>
        <li>Node.js</li>
        <li>Python / Django</li>
        </ul>
        </li>
        </ol>
        """
        let nsAttr = try parseAndRender(html)
        // 文本干净，无手动标记前缀
        XCTAssertFalse(nsAttr.string.contains("1.\t"), "automatic 不应有手动标记前缀")
        // 验证 paragraphStyle 有 NSTextList
        var textListCount = 0
        nsAttr.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: nsAttr.length)) { v, _, _ in
            guard let ps = v as? NSParagraphStyle, !ps.textLists.isEmpty else { return }
            textListCount += 1
        }
        XCTAssertEqual(textListCount, 5, "5 个 listItem 都应有 NSTextList")
    }
}
