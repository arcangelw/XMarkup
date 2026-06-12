import XCTest
@testable import XMarkup

final class MarkupDocumentTests: XCTestCase {

    func testEmptyDocument() {
        let doc = MarkupDocument(blocks: [])
        XCTAssertTrue(doc.blocks.isEmpty)
    }

    func testDocumentWithBlocks() {
        let blocks: [BlockNode] = [
            .heading(level: 1, [.text("Title")]),
            .paragraph([.text("Hello")]),
        ]
        let doc = MarkupDocument(blocks: blocks)
        XCTAssertEqual(doc.blocks.count, 2)
    }

    func testDocumentEquality() {
        let a = MarkupDocument(blocks: [.paragraph([.text("Hi")])])
        let b = MarkupDocument(blocks: [.paragraph([.text("Hi")])])
        XCTAssertEqual(a, b)
    }

    func testDocumentAppending() {
        let doc1 = MarkupDocument(blocks: [.paragraph([.text("A")])])
        let doc2 = MarkupDocument(blocks: [.paragraph([.text("B")])])
        let combined = doc1.appending(doc2)
        XCTAssertEqual(combined.blocks.count, 2)
    }

    func testDocumentAppendingPreservesOriginal() {
        let doc1 = MarkupDocument(blocks: [.paragraph([.text("A")])])
        let doc2 = MarkupDocument(blocks: [.paragraph([.text("B")])])
        _ = doc1.appending(doc2)
        // doc1 是不可变值类型，append 不影响原值
        XCTAssertEqual(doc1.blocks.count, 1)
    }
}
