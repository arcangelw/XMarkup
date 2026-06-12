import XCTest
@testable import XMarkup

final class BlockKindTests: XCTestCase {

    // MARK: - Level

    func testLevelRawValues() {
        XCTAssertEqual(Level.h1.rawValue, 1)
        XCTAssertEqual(Level.h2.rawValue, 2)
        XCTAssertEqual(Level.h3.rawValue, 3)
        XCTAssertEqual(Level.h4.rawValue, 4)
        XCTAssertEqual(Level.h5.rawValue, 5)
        XCTAssertEqual(Level.h6.rawValue, 6)
    }

    func testLevelFromRawValue() {
        XCTAssertEqual(Level(rawValue: 1), .h1)
        XCTAssertEqual(Level(rawValue: 6), .h6)
        XCTAssertNil(Level(rawValue: 0))
        XCTAssertNil(Level(rawValue: 7))
    }

    func testLevelComparison() {
        XCTAssertTrue(Level.h1 < Level.h2)
        XCTAssertTrue(Level.h3 < Level.h6)
        XCTAssertFalse(Level.h6 < Level.h1)
    }

    // MARK: - BlockKind

    func testParagraph() {
        XCTAssertEqual(BlockKind.paragraph, BlockKind.paragraph)
    }

    func testHeading() {
        let h1 = BlockKind.heading(.h1)
        if case let .heading(level) = h1 {
            XCTAssertEqual(level, .h1)
        } else {
            XCTFail("Expected .heading(.h1)")
        }
    }

    func testListItem() {
        let ordered = BlockKind.listItem(isOrdered: true, indentLevel: 0)
        if case let .listItem(isOrdered, indentLevel) = ordered {
            XCTAssertTrue(isOrdered)
            XCTAssertEqual(indentLevel, 0)
        } else {
            XCTFail("Expected .listItem(isOrdered:indentLevel:)")
        }
    }

    func testListItemEquality() {
        let a = BlockKind.listItem(isOrdered: true, indentLevel: 1)
        let b = BlockKind.listItem(isOrdered: true, indentLevel: 1)
        XCTAssertEqual(a, b)
    }

    func testListItemInequality() {
        let ordered = BlockKind.listItem(isOrdered: true, indentLevel: 0)
        let unordered = BlockKind.listItem(isOrdered: false, indentLevel: 0)
        XCTAssertNotEqual(ordered, unordered)
    }

    func testTableStructure() {
        let table = TableStructure(
            rows: [
                [TableCell(text: "H1", inlines: [], isHeader: true)],
                [TableCell(text: "D1", inlines: [], isHeader: false)],
            ],
            headerRowCount: 1,
            columnCount: 1
        )
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.headerRowCount, 1)
        XCTAssertTrue(table.rows[0][0].isHeader)
        XCTAssertFalse(table.rows[1][0].isHeader)
    }

    func testBlockKindEquality() {
        XCTAssertEqual(BlockKind.paragraph, BlockKind.paragraph)
        XCTAssertEqual(BlockKind.blockquote, BlockKind.blockquote)
        XCTAssertEqual(BlockKind.horizontalRule, BlockKind.horizontalRule)
        XCTAssertEqual(BlockKind.division, BlockKind.division)
        XCTAssertEqual(BlockKind.preformatted, BlockKind.preformatted)
        XCTAssertNotEqual(BlockKind.paragraph, BlockKind.blockquote)
    }
}
