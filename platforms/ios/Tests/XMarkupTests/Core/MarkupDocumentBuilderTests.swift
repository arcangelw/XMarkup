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
}
