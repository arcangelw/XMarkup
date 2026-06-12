import XCTest
@testable import XMarkup

// MARK: - BlockNode 测试辅助（纯结构化 BlockNode，无 flatBlock）

extension BlockNode {
    /// 提取块的逻辑 BlockKind
    fileprivate var fk: BlockKind {
        switch self {
        case .paragraph:                    return .paragraph
        case .heading(let level, _):       return .heading(Level(rawValue: level)!)
        case .blockquote:                  return .blockquote
        case .preformatted:                return .preformatted
        case .horizontalRule:              return .horizontalRule
        case .division:                    return .division
        case .table(let structure):        return .table(structure)
        case .media:                       return .media
        case .list(let isOrdered, _):      return .listItem(isOrdered: isOrdered, indentLevel: 0)
        case .definitionTerm:              return .definitionTerm
        case .definitionDescription:       return .definitionDescription
        case .custom:                      return .division
        }
    }

    /// 提取块的文本内容（结构化节点通过 Flattener 展平 InlineNode → String）
    fileprivate var ft: String {
        switch self {
        case .paragraph(let nodes),
             .preformatted(let nodes),
             .heading(_, let nodes),
             .definitionTerm(let nodes),
             .definitionDescription(let nodes):
            return Flattener.flattenText(nodes).text
        case .blockquote(let children),
             .division(_, let children):
            return children.map(\.ft).joined()
        case .list(_, let items):
            return items.flatMap { $0.blocks }.map(\.ft).joined()
        case .custom(_, _, let children):
            return children.map(\.ft).joined()
        default:
            return ""
        }
    }

    /// 提取块的内联样式（结构化节点通过 Flattener 反展平 → [MarkupInline]）
    fileprivate var fi: [MarkupInline] {
        switch self {
        case .paragraph(let nodes),
             .preformatted(let nodes),
             .definitionTerm(let nodes),
             .definitionDescription(let nodes):
            return Flattener.flattenText(nodes).inlines
        case .heading(_, let nodes):
            return Flattener.flattenText(nodes).inlines
        case .blockquote(let children),
             .division(_, let children):
            return children.flatMap(\.fi)
        case .list(_, let items):
            return items.flatMap { $0.blocks.flatMap(\.fi) }
        case .custom(_, _, let children):
            return children.flatMap(\.fi)
        default:
            return []
        }
    }

    /// 提取块的附件
    fileprivate var fa: MarkupAttachment? {
        switch self {
        case .media(let attachment):
            return attachment
        default:
            return nil
        }
    }
}

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
        XCTAssertEqual(doc.blocks[0].fk, .paragraph)
        XCTAssertEqual(doc.blocks[0].ft, "Hello World")
    }

    func testSingleParagraph() throws {
        let result = try parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].fk, .paragraph)
        XCTAssertEqual(doc.blocks[0].ft, "Hello")
    }

    // MARK: - 标题

    func testHeading1() throws {
        let result = try parse("<h1>Title</h1>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        if case let .heading(level) = doc.blocks[0].fk {
            XCTAssertEqual(level, .h1)
        } else {
            XCTFail("Expected .heading(.h1)")
        }
        XCTAssertEqual(doc.blocks[0].ft, "Title")
    }

    func testHeading3() throws {
        let result = try parse("<h3>Subtitle</h3>")
        let doc = MarkupDocument.from(result)
        if case let .heading(level) = doc.blocks[0].fk {
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
        XCTAssertEqual(doc.blocks[0].fi.count, 1)
        XCTAssertEqual(doc.blocks[0].fi[0].kind, .bold)
    }

    func testBoldItalicInlines() throws {
        let result = try parse("<b><i>both</i></b>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].fi.count, 2)
        let kinds = doc.blocks[0].fi.map(\.kind)
        XCTAssertTrue(kinds.contains(.bold))
        XCTAssertTrue(kinds.contains(.italic))
    }

    func testLinkInline() throws {
        let result = try parse("<a href=\"https://example.com\">click</a>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].fi.count, 1)
        if case let .link(url) = doc.blocks[0].fi[0].kind {
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
        XCTAssertEqual(doc.blocks[0].fk, .blockquote)
    }

    func testPreformatted() throws {
        let result = try parse("<pre>code block</pre>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].fk, .preformatted)
    }

    func testHorizontalRule() throws {
        let result = try parse("<hr>")
        let doc = MarkupDocument.from(result)
        let hrBlock = doc.blocks.first(where: { $0.fk == .horizontalRule })
        XCTAssertNotNil(hrBlock)
    }

    // MARK: - 多段落

    func testTwoParagraphs() throws {
        let result = try parse("<p>First</p><p>Second</p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 2)
        XCTAssertEqual(doc.blocks[0].ft, "First")
        XCTAssertEqual(doc.blocks[1].ft, "Second")
    }

    // MARK: - 列表

    func testUnorderedListItem() throws {
        let result = try parse("<ul><li>Item</li></ul>")
        let doc = MarkupDocument.from(result)
        let liBlock = doc.blocks.first(where: {
            if case .listItem = $0.fk { return true }
            return false
        })
        XCTAssertNotNil(liBlock)
        if case let .listItem(isOrdered, indentLevel) = liBlock!.fk {
            XCTAssertFalse(isOrdered)
            XCTAssertEqual(indentLevel, 0)
        }
    }

    func testOrderedListItem() throws {
        let result = try parse("<ol><li>Item</li></ol>")
        let doc = MarkupDocument.from(result)
        let liBlock = doc.blocks.first(where: {
            if case .listItem = $0.fk { return true }
            return false
        })
        XCTAssertNotNil(liBlock)
        if case let .listItem(isOrdered, _) = liBlock!.fk {
            XCTAssertTrue(isOrdered)
        }
    }

    // MARK: - 媒体附件

    func testImageAttachment() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertNotNil(doc.blocks[0].fa)
        if case let .image(src) = doc.blocks[0].fa?.content {
            XCTAssertEqual(src, "photo.jpg")
        } else {
            XCTFail("Expected .image(src:)")
        }
    }

    func testVideoAttachment() throws {
        let result = try parse("<video src=\"movie.mp4\"></video>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].fa)
        if case let .video(src) = doc.blocks[0].fa?.content {
            XCTAssertEqual(src, "movie.mp4")
        } else {
            XCTFail("Expected .video(src:)")
        }
    }

    func testVideoWithSourceChild() throws {
        let result = try parse("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].fa)
        if case let .video(src) = doc.blocks[0].fa?.content {
            XCTAssertEqual(src, "a.mp4")
        } else {
            XCTFail("Expected .video(src:)")
        }
    }

    func testAudioAttachment() throws {
        let result = try parse("<audio src=\"song.mp3\"></audio>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].fa)
        if case let .audio(src) = doc.blocks[0].fa?.content {
            XCTAssertEqual(src, "song.mp3")
        } else {
            XCTFail("Expected .audio(src:)")
        }
    }

    // MARK: - CSS 行内样式

    func testCSSForegroundColor() throws {
        let result = try parse("<span style=\"color:#FF0000\">red</span>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].fi.count, 1)
        if case let .span(styles) = doc.blocks[0].fi[0].kind {
            XCTAssertTrue(styles.contains(.foregroundColor("#FF0000")))
        } else {
            XCTFail("Expected .span(styles:)")
        }
    }

    func testUnknownTagProducesBlock() throws {
        let result = try parse("<custom>text</custom>")
        let doc = MarkupDocument.from(result)
        XCTAssertFalse(doc.blocks.isEmpty)
        XCTAssertEqual(doc.blocks[0].ft, "text")
    }

    // MARK: - 复合场景

    func testHeadingWithInline() throws {
        let result = try parse("<h1><b>Bold</b> Title</h1>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        if case .heading(.h1) = doc.blocks[0].fk {
            // 正确
        } else {
            XCTFail("Expected .heading(.h1)")
        }
        XCTAssertTrue(doc.blocks[0].fi.contains(where: { $0.kind == .bold }))
    }

    func testParagraphWithMixedInlines() throws {
        let result = try parse("<p><b>bold</b> <i>italic</i> <a href=\"https://example.com\">link</a></p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        let kinds = doc.blocks[0].fi.map(\.kind)
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
        XCTAssertEqual(doc.blocks[0].fi.count, 1)
        XCTAssertEqual(doc.blocks[0].fi[0].kind, .bold)
    }

    func testInlineRangeRelativeToBlock() throws {
        // 验证 inline range 是相对于块起始位置的偏移
        let result = try parse("<p>Hello <b>bold</b></p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        guard let inline = doc.blocks[0].fi.first else {
            XCTFail("Expected inline")
            return
        }
        // "Hello bold" → "bold" 从 index 6 开始，长度 4
        XCTAssertEqual(inline.range.start, 6)
        XCTAssertEqual(inline.range.length, 4)
    }

    // MARK: - Code Review 修复验证

    func testArticleSectionBlock() throws {
        // article/section 是语义容器，不产生独立 block
        // 内部没有子块级元素时，整段文本退化为一个 paragraph
        let result = try parse("<article>A</article><section>B</section>")
        let doc = MarkupDocument.from(result)
        XCTAssertFalse(doc.blocks.isEmpty)
        let allText = doc.blocks.map(\.ft).joined()
        XCTAssertTrue(allText.contains("A"))
        XCTAssertTrue(allText.contains("B"))
        // 关键：不应重复
        let countA = doc.blocks.filter { $0.ft.contains("A") }.count
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
        // 嵌套列表：顶层 1 个有序列表，内层 list 嵌套在 ListItem.blocks 中
        XCTAssertEqual(doc.blocks.count, 1)
        guard case .list(let isOrdered, let items) = doc.blocks[0] else {
            XCTFail("Expected .list"); return
        }
        XCTAssertTrue(isOrdered, "外层应为有序")
        XCTAssertEqual(items.count, 1)
        let outerBlocks = items[0].blocks
        XCTAssertEqual(outerBlocks.count, 2, "outer li: paragraph + nested list")
        if case .list(let innerOrdered, let innerItems) = outerBlocks[1] {
            XCTAssertFalse(innerOrdered, "内层 <ul> 应为无序")
            XCTAssertEqual(innerItems.count, 1)
            XCTAssertEqual(innerItems[0].blocks[0].ft, "inner")
        } else {
            XCTFail("Expected nested .list in outer li blocks")
        }
    }

    func testCSSTextAlignInline() throws {
        let result = try parse("<p style=\"text-align:center\">centered</p>")
        let doc = MarkupDocument.from(result)
        let inlines = doc.blocks.flatMap(\.fi)
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
        let hasStyle = doc.blocks.flatMap(\.fi).contains {
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
        let hasStyle = doc.blocks.flatMap(\.fi).contains {
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
        let hasStyle = doc.blocks.flatMap(\.fi).contains {
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
        let hasStyle = doc.blocks.flatMap(\.fi).contains {
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
        let hasStyle = doc.blocks.flatMap(\.fi).contains {
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
        let hasStyle = doc.blocks.flatMap(\.fi).contains {
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
        let hasStyle = doc.blocks.flatMap(\.fi).contains {
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
        guard let inline = doc.blocks[0].fi.first else {
            XCTFail("Expected bold inline")
            return
        }
        XCTAssertEqual(inline.kind, .bold)
        XCTAssertEqual(inline.range.start, 0)
        let expectedLength = ("🎉hello" as NSString).length
        XCTAssertEqual(inline.range.length, expectedLength)
    }

    func testChineseTextRange() throws {
        let result = try parse("<b>中文</b>测试")
        let doc = MarkupDocument.from(result)
        guard let inline = doc.blocks[0].fi.first else {
            XCTFail("Expected bold inline")
            return
        }
        XCTAssertEqual(inline.kind, .bold)
        XCTAssertEqual(inline.range.start, 0)
        let expectedLength = ("中文" as NSString).length
        XCTAssertEqual(inline.range.length, expectedLength)
    }

    func testMultipleInlineSameBlock() throws {
        let result = try parse("<p><b>A</b><i>B</i><u>C</u></p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].fi.count, 3)
        let ranges = doc.blocks[0].fi.map(\.range)
        for i in 0 ..< ranges.count - 1 {
            let end = ranges[i].start + ranges[i].length
            XCTAssertLessThanOrEqual(end, ranges[i + 1].start, "内联 range 不应重叠")
        }
    }

    // MARK: - 其他块级元素

    func testDivisionBlock() throws {
        let result = try parse("<div>text</div>")
        let doc = MarkupDocument.from(result)
        let divBlocks = doc.blocks.filter { $0.fk == .division }
        XCTAssertFalse(divBlocks.isEmpty)
        XCTAssertEqual(divBlocks[0].ft, "text")
    }

    func testTableCellBlocks() throws {
        let result = try parse("<table><tr><td>A</td><td>B</td></tr></table>")
        let doc = MarkupDocument.from(result)
        // 现在表格作为一个块产出，内容在 TableStructure 中
        let tableBlock = doc.blocks.first { if case .table = $0.fk { return true }; return false }
        XCTAssertNotNil(tableBlock, "应产出 table 块")

        if case .table(let structure) = tableBlock!.fk {
            XCTAssertEqual(structure.rows.count, 1, "应为 1 行")
            XCTAssertEqual(structure.columnCount, 2, "应为 2 列")
            XCTAssertEqual(structure.rows[0][0].text, "A")
            XCTAssertEqual(structure.rows[0][1].text, "B")
        }
    }

    // MARK: - Subscript / Superscript 标签解析

    func testSubscriptTag() throws {
        let result = try parse("<p>H<sub>2</sub>O</p>")
        let doc = MarkupDocument.from(result)
        let subInline = doc.blocks[0].fi.first { $0.kind == .subscriptText }
        XCTAssertNotNil(subInline, "<sub> 应解析为 .subscriptText")
    }

    func testSuperscriptTag() throws {
        let result = try parse("<p>10<sup>th</sup></p>")
        let doc = MarkupDocument.from(result)
        let supInline = doc.blocks[0].fi.first { $0.kind == .superscript }
        XCTAssertNotNil(supInline, "<sup> 应解析为 .superscript")
    }

    // MARK: - 表格更多场景

    func testTableWithHeaders() throws {
        let result = try parse("<table><tr><th>H1</th><th>H2</th></tr><tr><td>A</td><td>B</td></tr></table>")
        let doc = MarkupDocument.from(result)
        let tableBlock = doc.blocks.first { if case .table = $0.fk { return true }; return false }
        XCTAssertNotNil(tableBlock)
        if case .table(let structure) = tableBlock!.fk {
            XCTAssertEqual(structure.rows.count, 2, "应为 2 行")
            XCTAssertEqual(structure.headerRowCount, 1, "第一行为表头")
            XCTAssertTrue(structure.rows[0][0].isHeader)
            XCTAssertFalse(structure.rows[1][0].isHeader)
        }
    }

    func testEmptyTableRow() throws {
        let result = try parse("<table><tr></tr><tr><td>A</td></tr></table>")
        let doc = MarkupDocument.from(result)
        let tableBlock = doc.blocks.first { if case .table = $0.fk { return true }; return false }
        XCTAssertNotNil(tableBlock, "空行不应导致崩溃")
        if case .table(let structure) = tableBlock!.fk {
            XCTAssertEqual(structure.rows.count, 1, "空行应被跳过")
            XCTAssertEqual(structure.rows[0][0].text, "A")
        }
    }

    func testMultipleTables() throws {
        let html = "<table><tr><td>A</td></tr></table><p>sep</p><table><tr><td>B</td></tr></table>"
        let result = try parse(html)
        let doc = MarkupDocument.from(result)
        let tableBlocks = doc.blocks.filter { if case .table = $0.fk { return true }; return false }
        XCTAssertEqual(tableBlocks.count, 2, "两个 <table> 应产出两个 table 块")
    }

    func testTableRowAndCellKinds() throws {
        let result = try parse("<table><tr><td>Cell</td></tr></table>")
        let doc = MarkupDocument.from(result)
        guard case .table(let structure) = doc.blocks.first?.fk else {
            XCTFail("应产出 table 块"); return
        }
        // 验证 table 内子节点标识
        // 当前 direct: TableStructure.rows 中的 cell isHeader 已由 builder 设置
        XCTAssertFalse(structure.rows[0][0].isHeader)
    }

    func testMediaWithoutAltTextCreatesAttachment() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let doc = MarkupDocument.from(result)
        guard let block = doc.blocks.first else { XCTFail("应产出块"); return }
        XCTAssertNotNil(block.fa, "零文本 media 应生成附件块")
    }
}
