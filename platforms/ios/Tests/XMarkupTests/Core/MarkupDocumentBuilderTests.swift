import XCTest
@testable import XMarkup

final class MarkupDocumentBuilderTests: XCTestCase {

    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    // MARK: - 基础转换

    func testEmptyInput() throws {
        let result = try parse("")
        let doc = MarkupDocument.from(result)
        XCTAssertTrue(doc.blocks.isEmpty)
    }

    func testPureText() throws {
        let result = try parse("Hello World")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .paragraph)
        XCTAssertEqual(doc.blocks[0].text, "Hello World")
    }

    func testSingleParagraph() throws {
        let result = try parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .paragraph)
        XCTAssertEqual(doc.blocks[0].text, "Hello")
    }

    // MARK: - 标题

    func testHeading1() throws {
        let result = try parse("<h1>Title</h1>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        if case let .heading(level) = doc.blocks[0].kind {
            XCTAssertEqual(level, .h1)
        } else {
            XCTFail("Expected .heading(.h1)")
        }
        XCTAssertEqual(doc.blocks[0].text, "Title")
    }

    func testHeading3() throws {
        let result = try parse("<h3>Subtitle</h3>")
        let doc = MarkupDocument.from(result)
        if case let .heading(level) = doc.blocks[0].kind {
            XCTAssertEqual(level, .h3)
        } else {
            XCTFail("Expected .heading(.h3)")
        }
    }

    // MARK: - 内联样式

    func testBoldInline() throws {
        let result = try parse("<b>bold</b>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].inlines.count, 1)
        XCTAssertEqual(doc.blocks[0].inlines[0].kind, .bold)
    }

    func testBoldItalicInlines() throws {
        let result = try parse("<b><i>both</i></b>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].inlines.count, 2)
        let kinds = doc.blocks[0].inlines.map(\.kind)
        XCTAssertTrue(kinds.contains(.bold))
        XCTAssertTrue(kinds.contains(.italic))
    }

    func testLinkInline() throws {
        let result = try parse("<a href=\"https://example.com\">click</a>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].inlines.count, 1)
        if case let .link(url) = doc.blocks[0].inlines[0].kind {
            XCTAssertEqual(url, "https://example.com")
        } else {
            XCTFail("Expected .link(url:)")
        }
    }

    // MARK: - 块级元素

    func testBlockquote() throws {
        let result = try parse("<blockquote>quote</blockquote>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .blockquote)
    }

    func testPreformatted() throws {
        let result = try parse("<pre>code block</pre>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .preformatted)
    }

    func testHorizontalRule() throws {
        let result = try parse("<hr>")
        let doc = MarkupDocument.from(result)
        let hrBlock = doc.blocks.first(where: { $0.kind == .horizontalRule })
        XCTAssertNotNil(hrBlock)
    }

    // MARK: - 多段落

    func testTwoParagraphs() throws {
        let result = try parse("<p>First</p><p>Second</p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 2)
        XCTAssertEqual(doc.blocks[0].text, "First")
        XCTAssertEqual(doc.blocks[1].text, "Second")
    }

    // MARK: - 列表

    func testUnorderedListItem() throws {
        let result = try parse("<ul><li>Item</li></ul>")
        let doc = MarkupDocument.from(result)
        let liBlock = doc.blocks.first(where: {
            if case .listItem = $0.kind { return true }
            return false
        })
        XCTAssertNotNil(liBlock)
        if case let .listItem(isOrdered, indentLevel) = liBlock!.kind {
            XCTAssertFalse(isOrdered)
            XCTAssertEqual(indentLevel, 0)
        }
    }

    func testOrderedListItem() throws {
        let result = try parse("<ol><li>Item</li></ol>")
        let doc = MarkupDocument.from(result)
        let liBlock = doc.blocks.first(where: {
            if case .listItem = $0.kind { return true }
            return false
        })
        XCTAssertNotNil(liBlock)
        if case let .listItem(isOrdered, _) = liBlock!.kind {
            XCTAssertTrue(isOrdered)
        }
    }

    // MARK: - 媒体附件

    func testImageAttachment() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertNotNil(doc.blocks[0].attachment)
        if case let .image(src) = doc.blocks[0].attachment?.content {
            XCTAssertEqual(src, "photo.jpg")
        } else {
            XCTFail("Expected .image(src:)")
        }
    }

    func testVideoAttachment() throws {
        let result = try parse("<video src=\"movie.mp4\"></video>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].attachment)
        if case let .video(src) = doc.blocks[0].attachment?.content {
            XCTAssertEqual(src, "movie.mp4")
        } else {
            XCTFail("Expected .video(src:)")
        }
    }

    func testVideoWithSourceChild() throws {
        let result = try parse("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].attachment)
        if case let .video(src) = doc.blocks[0].attachment?.content {
            XCTAssertEqual(src, "a.mp4")
        } else {
            XCTFail("Expected .video(src:)")
        }
    }

    func testAudioAttachment() throws {
        let result = try parse("<audio src=\"song.mp3\"></audio>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].attachment)
        if case let .audio(src) = doc.blocks[0].attachment?.content {
            XCTAssertEqual(src, "song.mp3")
        } else {
            XCTFail("Expected .audio(src:)")
        }
    }

    // MARK: - CSS 行内样式

    func testCSSForegroundColor() throws {
        let result = try parse("<span style=\"color:#FF0000\">red</span>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].inlines.count, 1)
        if case let .span(styles) = doc.blocks[0].inlines[0].kind {
            XCTAssertTrue(styles.contains(.foregroundColor("#FF0000")))
        } else {
            XCTFail("Expected .span(styles:)")
        }
    }

    func testUnknownTagProducesBlock() throws {
        let result = try parse("<custom>text</custom>")
        let doc = MarkupDocument.from(result)
        XCTAssertFalse(doc.blocks.isEmpty)
        XCTAssertEqual(doc.blocks[0].text, "text")
    }

    // MARK: - 复合场景

    func testHeadingWithInline() throws {
        let result = try parse("<h1><b>Bold</b> Title</h1>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        if case .heading(.h1) = doc.blocks[0].kind {
            // 正确
        } else {
            XCTFail("Expected .heading(.h1)")
        }
        XCTAssertTrue(doc.blocks[0].inlines.contains(where: { $0.kind == .bold }))
    }

    func testParagraphWithMixedInlines() throws {
        let result = try parse("<p><b>bold</b> <i>italic</i> <a href=\"https://example.com\">link</a></p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        let kinds = doc.blocks[0].inlines.map(\.kind)
        XCTAssertTrue(kinds.contains(.bold))
        XCTAssertTrue(kinds.contains(.italic))
        XCTAssertTrue(kinds.contains(where: {
            if case .link = $0 { return true }
            return false
        }))
    }

    // MARK: - 边界修复测试

    func testPartiallyOverlappingInlineNotDropped() throws {
        let result = try parse("<p><b>bold</b> text</p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].inlines.count, 1)
        XCTAssertEqual(doc.blocks[0].inlines[0].kind, .bold)
    }

    func testInlineRangeRelativeToBlock() throws {
        // 验证 inline range 是相对于块起始位置的偏移
        let result = try parse("<p>Hello <b>bold</b></p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        guard let inline = doc.blocks[0].inlines.first else {
            XCTFail("Expected inline")
            return
        }
        // "Hello bold" → "bold" 从 index 6 开始，长度 4
        XCTAssertEqual(inline.range.location, 6)
        XCTAssertEqual(inline.range.length, 4)
    }

    // MARK: - Code Review 修复验证

    func testArticleSectionBlock() throws {
        // article/section 是语义容器，不产生独立 block
        // 内部没有子块级元素时，整段文本退化为一个 paragraph
        let result = try parse("<article>A</article><section>B</section>")
        let doc = MarkupDocument.from(result)
        XCTAssertFalse(doc.blocks.isEmpty)
        let allText = doc.blocks.map(\.text).joined()
        XCTAssertTrue(allText.contains("A"))
        XCTAssertTrue(allText.contains("B"))
        // 关键：不应重复
        let countA = doc.blocks.filter { $0.text.contains("A") }.count
        XCTAssertEqual(countA, 1, "A 不应重复出现在多个 block 中")
    }

    func testLeadingNewlinePreserved() throws {
        // 验证 trimmingTrailingNewlines 只修剪尾部，不影响前导字符
        let input = "\nHello\n"
        let trimmed = input.trimmingTrailingNewlines
        XCTAssertTrue(trimmed.hasPrefix("\n"), "前导换行应保留")
        XCTAssertFalse(trimmed.hasSuffix("\n"), "尾部换行应被裁剪")
        XCTAssertEqual(trimmed, "\nHello")
    }

    func testNestedListIsOrderedUsesNearestAncestor() throws {
        let result = try parse("<ol><li>outer<ul><li>inner</li></ul></li></ol>")
        let doc = MarkupDocument.from(result)
        let listItems = doc.blocks.filter {
            if case .listItem = $0.kind { return true }
            return false
        }
        XCTAssertGreaterThanOrEqual(listItems.count, 2)
        let innerItem = listItems.last!
        if case let .listItem(isOrdered, _) = innerItem.kind {
            XCTAssertFalse(isOrdered, "内层 <ul><li> 应为无序")
        }
    }

    func testCSSTextAlignInline() throws {
        let result = try parse("<p style=\"text-align:center\">centered</p>")
        let doc = MarkupDocument.from(result)
        let inlines = doc.blocks.flatMap(\.inlines)
        let hasTextAlign = inlines.contains {
            if case .span(let styles) = $0.kind {
                return styles.contains(.textAlign("center"))
            }
            return false
        }
        XCTAssertTrue(hasTextAlign, "应产出 textAlign 内联样式")
    }

    // MARK: - CSS 样式完整性

    func testCSSBackgroundColor() throws {
        let result = try parse("<span style=\"background-color:#00FF00\">green</span>")
        let doc = MarkupDocument.from(result)
        let hasStyle = doc.blocks.flatMap(\.inlines).contains {
            if case .span(let styles) = $0.kind {
                return styles.contains(.backgroundColor("#00FF00"))
            }
            return false
        }
        XCTAssertTrue(hasStyle)
    }

    func testCSSFontSize() throws {
        let result = try parse("<span style=\"font-size:20px\">big</span>")
        let doc = MarkupDocument.from(result)
        let hasStyle = doc.blocks.flatMap(\.inlines).contains {
            if case .span(let styles) = $0.kind {
                return styles.contains(.fontSize(20))
            }
            return false
        }
        XCTAssertTrue(hasStyle)
    }

    func testCSSFontWeight() throws {
        let result = try parse("<span style=\"font-weight:bold\">bold</span>")
        let doc = MarkupDocument.from(result)
        let hasStyle = doc.blocks.flatMap(\.inlines).contains {
            if case .span(let styles) = $0.kind {
                return styles.contains(.fontWeight("bold"))
            }
            return false
        }
        XCTAssertTrue(hasStyle)
    }

    func testCSSFontStyle() throws {
        let result = try parse("<span style=\"font-style:italic\">italic</span>")
        let doc = MarkupDocument.from(result)
        let hasStyle = doc.blocks.flatMap(\.inlines).contains {
            if case .span(let styles) = $0.kind {
                return styles.contains(.fontStyle("italic"))
            }
            return false
        }
        XCTAssertTrue(hasStyle)
    }

    func testCSSTextDecoration() throws {
        let result = try parse("<span style=\"text-decoration:underline\">under</span>")
        let doc = MarkupDocument.from(result)
        let hasStyle = doc.blocks.flatMap(\.inlines).contains {
            if case .span(let styles) = $0.kind {
                return styles.contains(.textDecoration("underline"))
            }
            return false
        }
        XCTAssertTrue(hasStyle)
    }

    func testCSSLineHeight() throws {
        let result = try parse("<span style=\"line-height:1.5\">text</span>")
        let doc = MarkupDocument.from(result)
        let hasStyle = doc.blocks.flatMap(\.inlines).contains {
            if case .span(let styles) = $0.kind {
                return styles.contains(.lineHeight(1.5))
            }
            return false
        }
        XCTAssertTrue(hasStyle)
    }

    func testCSSLetterSpacing() throws {
        // letter-spacing 值由 C 引擎原样传递（如 "2px"），Float() 无法解析则不产出
        // 使用纯数字值测试
        let result = try parse("<span style=\"letter-spacing:2\">spaced</span>")
        let doc = MarkupDocument.from(result)
        let hasStyle = doc.blocks.flatMap(\.inlines).contains {
            if case .span(let styles) = $0.kind {
                return styles.contains(.letterSpacing(2))
            }
            return false
        }
        XCTAssertTrue(hasStyle)
    }

    // MARK: - Unicode 边界

    func testEmojiTextRange() throws {
        let result = try parse("<b>🎉hello</b>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        guard let inline = doc.blocks[0].inlines.first else {
            XCTFail("Expected bold inline")
            return
        }
        XCTAssertEqual(inline.kind, .bold)
        XCTAssertEqual(inline.range.location, 0)
        let expectedLength = ("🎉hello" as NSString).length
        XCTAssertEqual(inline.range.length, expectedLength)
    }

    func testChineseTextRange() throws {
        let result = try parse("<b>中文</b>测试")
        let doc = MarkupDocument.from(result)
        guard let inline = doc.blocks[0].inlines.first else {
            XCTFail("Expected bold inline")
            return
        }
        XCTAssertEqual(inline.kind, .bold)
        XCTAssertEqual(inline.range.location, 0)
        let expectedLength = ("中文" as NSString).length
        XCTAssertEqual(inline.range.length, expectedLength)
    }

    func testMultipleInlineSameBlock() throws {
        let result = try parse("<p><b>A</b><i>B</i><u>C</u></p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].inlines.count, 3)
        let ranges = doc.blocks[0].inlines.map(\.range)
        for i in 0 ..< ranges.count - 1 {
            let end = ranges[i].location + ranges[i].length
            XCTAssertLessThanOrEqual(end, ranges[i + 1].location, "内联 range 不应重叠")
        }
    }

    // MARK: - 其他块级元素

    func testDivisionBlock() throws {
        let result = try parse("<div>text</div>")
        let doc = MarkupDocument.from(result)
        let divBlocks = doc.blocks.filter { $0.kind == .division }
        XCTAssertFalse(divBlocks.isEmpty)
        XCTAssertEqual(divBlocks[0].text, "text")
    }

    func testTableCellBlocks() throws {
        let result = try parse("<table><tr><td>A</td><td>B</td></tr></table>")
        let doc = MarkupDocument.from(result)
        XCTAssertFalse(doc.blocks.isEmpty)
        let hasA = doc.blocks.contains { $0.text.contains("A") }
        let hasB = doc.blocks.contains { $0.text.contains("B") }
        XCTAssertTrue(hasA)
        XCTAssertTrue(hasB)
    }
}
