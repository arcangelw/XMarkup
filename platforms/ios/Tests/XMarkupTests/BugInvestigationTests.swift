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

    func testItalicObliquenessInAttributedString() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<i>斜体文字</i>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()

        // 验证 AttributedString 层面斜体属性存在（italic font 或 obliqueness 二选一）
        for run in attr.runs {
            #if canImport(UIKit)
            let obliqueness = run.uiKit.obliqueness
            let font = run.uiKit.font
            let hasItalicFont = font.map {
                $0.fontDescriptor.symbolicTraits.contains(.traitItalic)
            } ?? false
            XCTAssertTrue(
                hasItalicFont || obliqueness == 0.25,
                "应含 italic font 或 obliqueness=0.25"
            )
            #endif
        }
    }

    func testItalicObliquenessInNSAttributedString() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<i>斜体文字</i>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedStringRenderer().render(attr)

        // 验证 NSAttributedString 层面斜体属性存在（italic font 或 obliqueness 二选一）
        let obliqueness = nsAttr.attribute(.obliqueness, at: 0, effectiveRange: nil) as? NSNumber
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        let hasItalicFont: Bool
        #if canImport(UIKit)
        hasItalicFont = font?.fontDescriptor.symbolicTraits.contains(.traitItalic) ?? false
        #elseif canImport(AppKit)
        hasItalicFont = font?.fontDescriptor.symbolicTraits.contains(.italic) ?? false
        #endif
        XCTAssertTrue(
            hasItalicFont || obliqueness?.floatValue == 0.25,
            "NSAttributedString 应含 italic font 或 .obliqueness=0.25"
        )
    }
}
