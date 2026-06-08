import XCTest
@testable import XMarkup

final class MarkupBlockTests: XCTestCase {

    func testBlockCreation() {
        let block = MarkupBlock(
            kind: .paragraph,
            text: "Hello World",
            inlines: [],
            attachment: nil
        )
        XCTAssertEqual(block.kind, .paragraph)
        XCTAssertEqual(block.text, "Hello World")
        XCTAssertTrue(block.inlines.isEmpty)
        XCTAssertNil(block.attachment)
    }

    func testBlockWithInline() {
        let text = "Hello World"
        let range = text.startIndex..<text.index(text.startIndex, offsetBy: 5)
        let inline = MarkupInline(range: range, kind: .bold)
        let block = MarkupBlock(
            kind: .paragraph,
            text: text,
            inlines: [inline],
            attachment: nil
        )
        XCTAssertEqual(block.inlines.count, 1)
        XCTAssertEqual(block.inlines[0].kind, .bold)
    }

    func testBlockWithAttachment() {
        let attachment = MarkupAttachment(
            content: .image(src: "photo.jpg"),
            suggestedSize: CGSize(width: 200, height: 150),
            alignment: .default
        )
        let block = MarkupBlock(
            kind: .paragraph,
            text: "\u{FFFC}",
            inlines: [],
            attachment: attachment
        )
        XCTAssertNotNil(block.attachment)
    }

    func testBlockEquality() {
        let a = MarkupBlock(kind: .paragraph, text: "Hi", inlines: [], attachment: nil)
        let b = MarkupBlock(kind: .paragraph, text: "Hi", inlines: [], attachment: nil)
        XCTAssertEqual(a, b)
    }
}
