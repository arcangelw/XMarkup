import XCTest
@testable import XMarkup

final class BugInvestigationTests: XCTestCase {
    func testSemanticContainerNoContentDuplication() throws {
        let parser = try XMarkupParser()
        let html = "<article><h2>标题</h2><p>内容</p></article>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let rendered = doc.render()
        let text = String(rendered.characters)

        let titleCount = text.components(separatedBy: "标题").count - 1
        XCTAssertEqual(titleCount, 1, "标题应只出现一次")
        let contentCount = text.components(separatedBy: "内容").count - 1
        XCTAssertEqual(contentCount, 1, "内容应只出现一次")
    }

    func testSectionContainerNoContentDuplication() throws {
        let parser = try XMarkupParser()
        let html = "<section><h3>章节</h3><p>正文</p></section>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let rendered = doc.render()
        let text = String(rendered.characters)

        XCTAssertEqual(text.components(separatedBy: "章节").count - 1, 1)
        XCTAssertEqual(text.components(separatedBy: "正文").count - 1, 1)
    }

    func testNestedSemanticContainers() throws {
        let parser = try XMarkupParser()
        let html = "<article><header><h1>头部</h1></header><section><p>段落</p></section><footer><p>底部</p></footer></article>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let rendered = doc.render()
        let text = String(rendered.characters)

        XCTAssertEqual(text.components(separatedBy: "头部").count - 1, 1)
        XCTAssertEqual(text.components(separatedBy: "段落").count - 1, 1)
        XCTAssertEqual(text.components(separatedBy: "底部").count - 1, 1)
    }

    func testItalicFallbackForCJKFont() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<i>斜体文字</i>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedStringRenderer().render(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font, "斜体应有字体")
    }
}
