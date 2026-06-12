import XCTest
@testable import XMarkup

final class FlattenerTests: XCTestCase {

    // MARK: - InlineNode.code 嵌套支持

    func testCodeWithPlainText() {
        // .code([.text("hello")]) 等同于旧版 .code("hello")
        let nodes: [InlineNode] = [.code([.text("hello")])]
        let (text, inlines) = Flattener.flattenText(nodes)

        XCTAssertEqual(text, "hello")
        XCTAssertEqual(inlines.count, 1)
        XCTAssertEqual(inlines[0].kind, .code)
        XCTAssertEqual(inlines[0].range, TextRange(start: 0, length: 5))
    }

    func testCodeWithNestedBold() {
        // <code><b>bold</b></code> → code range 覆盖整段，bold 子范围也保留
        let nodes: [InlineNode] = [.code([.bold([.text("bold")])])]
        let (text, inlines) = Flattener.flattenText(nodes)

        XCTAssertEqual(text, "bold")
        // 应产出 2 个 inline：内部 bold + 外部 code
        XCTAssertEqual(inlines.count, 2)

        // bold 在前（递归先产出子节点 inline）
        let boldInline = inlines[0]
        XCTAssertEqual(boldInline.kind, .bold)
        XCTAssertEqual(boldInline.range, TextRange(start: 0, length: 4))

        // code 覆盖整段
        let codeInline = inlines[1]
        XCTAssertEqual(codeInline.kind, .code)
        XCTAssertEqual(codeInline.range, TextRange(start: 0, length: 4))
    }

    func testCodeWithMixedChildren() {
        // <code>prefix <i>italic</i> suffix</code>
        let nodes: [InlineNode] = [
            .code([
                .text("prefix "),
                .italic([.text("italic")]),
                .text(" suffix"),
            ]),
        ]
        let (text, inlines) = Flattener.flattenText(nodes)

        XCTAssertEqual(text, "prefix italic suffix")
        // "prefix " = 7 chars, "italic" = 6 chars, " suffix" = 7 chars → total 20

        // italic inline
        let italicInline = inlines.first { $0.kind == .italic }
        XCTAssertNotNil(italicInline)
        XCTAssertEqual(italicInline?.range, TextRange(start: 7, length: 6))

        // code 覆盖全部
        let codeInline = inlines.first { $0.kind == .code }
        XCTAssertNotNil(codeInline)
        XCTAssertEqual(codeInline?.range, TextRange(start: 0, length: 20))
    }

    func testCodeEmptyChildren() {
        // 空 code 不产出 inline
        let nodes: [InlineNode] = [.code([])]
        let (text, inlines) = Flattener.flattenText(nodes)

        XCTAssertEqual(text, "")
        XCTAssertTrue(inlines.isEmpty)
    }

    // MARK: - mark 嵌套支持

    func testMarkWithPlainText() {
        let nodes: [InlineNode] = [.mark([.text("highlighted")])]
        let (text, inlines) = Flattener.flattenText(nodes)

        XCTAssertEqual(text, "highlighted")
        XCTAssertEqual(inlines.count, 1)
        XCTAssertEqual(inlines[0].kind, .mark)
        XCTAssertEqual(inlines[0].range, TextRange(start: 0, length: 11))
    }

    func testMarkWithNestedBold() {
        let nodes: [InlineNode] = [.mark([.bold([.text("strong")])])]
        let (text, inlines) = Flattener.flattenText(nodes)

        XCTAssertEqual(text, "strong")
        XCTAssertEqual(inlines.count, 2)

        let boldInline = inlines[0]
        XCTAssertEqual(boldInline.kind, .bold)

        let markInline = inlines[1]
        XCTAssertEqual(markInline.kind, .mark)
        XCTAssertEqual(markInline.range, TextRange(start: 0, length: 6))
    }
}
