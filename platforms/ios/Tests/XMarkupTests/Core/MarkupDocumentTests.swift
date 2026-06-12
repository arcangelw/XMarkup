import XCTest
@testable import XMarkup

final class MarkupDocumentTests: XCTestCase {

    func testEmptyDocument() {
        let doc = MarkupDocument(blocks: [])
        XCTAssertTrue(doc.blocks.isEmpty)
    }

    func testDocumentWithBlocks() {
        let blocks: [BlockNode] = [
            .flatBlock(kind: .heading(.h1), text: "Title", inlines: [], attachment: nil),
            .flatBlock(kind: .paragraph, text: "Hello", inlines: [], attachment: nil),
        ]
        let doc = MarkupDocument(blocks: blocks)
        XCTAssertEqual(doc.blocks.count, 2)
    }

    func testDocumentEquality() {
        let a = MarkupDocument(blocks: [
            .flatBlock(kind: .paragraph, text: "Hi", inlines: [], attachment: nil),
        ])
        let b = MarkupDocument(blocks: [
            .flatBlock(kind: .paragraph, text: "Hi", inlines: [], attachment: nil),
        ])
        XCTAssertEqual(a, b)
    }

    func testDocumentAppending() {
        let doc1 = MarkupDocument(blocks: [
            .flatBlock(kind: .paragraph, text: "A", inlines: [], attachment: nil),
        ])
        let doc2 = MarkupDocument(blocks: [
            .flatBlock(kind: .paragraph, text: "B", inlines: [], attachment: nil),
        ])
        let combined = doc1.appending(doc2)
        XCTAssertEqual(combined.blocks.count, 2)
    }

    func testDocumentAppendingPreservesOriginal() {
        let doc1 = MarkupDocument(blocks: [
            .flatBlock(kind: .paragraph, text: "A", inlines: [], attachment: nil),
        ])
        let doc2 = MarkupDocument(blocks: [
            .flatBlock(kind: .paragraph, text: "B", inlines: [], attachment: nil),
        ])
        _ = doc1.appending(doc2)
        // doc1 是不可变值类型，append 不影响原值
        XCTAssertEqual(doc1.blocks.count, 1)
    }
}
