import XCTest
@testable import XMarkupDemoSwiftUI

final class DemoCatalogTests: XCTestCase {

    private func make(
        _ id: String,
        title: String = "",
        family: ExampleFamily = .inlineText,
        tier: ExampleTier = .basic,
        visibility: ExampleVisibility = .visible,
        html: String = ""
    ) -> DemoExample {
        DemoExample(id: id, title: title, summary: "", html: html,
                    family: family, tier: tier, visibility: visibility)
    }

    func testVisibleFiltersHidden() {
        let ex = [make("a"), make("b", visibility: .hidden)]
        XCTAssertEqual(DemoCatalog.visible(in: ex).map(\.id), ["a"])
    }

    func testSearchByTitle() {
        let ex = [make("x", title: "粗体文字", html: "<b>x</b>")]
        XCTAssertEqual(DemoCatalog.search("粗", in: ex).map(\.id), ["x"])
    }

    func testSearchByHTML() {
        let ex = [make("x", title: "标题", html: "<blockquote>引用</blockquote>")]
        XCTAssertEqual(DemoCatalog.search("blockquote", in: ex).map(\.id), ["x"])
    }

    func testSearchByID() {
        let ex = [make("bold-italic", title: "粗斜")]
        XCTAssertEqual(DemoCatalog.search("italic", in: ex).map(\.id), ["bold-italic"])
    }

    func testSearchNoMatch() {
        let ex = [make("x", title: "粗体")]
        XCTAssertTrue(DemoCatalog.search("不存在xyz", in: ex).isEmpty)
    }

    func testSearchHiddenExcluded() {
        let ex = [make("a", title: "粗体", visibility: .hidden)]
        XCTAssertTrue(DemoCatalog.search("粗", in: ex).isEmpty)
    }

    func testSearchEmptyQueryReturnsAllVisible() {
        let ex = [make("a"), make("b", visibility: .hidden), make("c")]
        XCTAssertEqual(DemoCatalog.search("  ", in: ex).map(\.id), ["a", "c"])
    }

    func testGroupedByFamilyPreservesAllCasesOrder() {
        let ex = [
            make("a", family: .table),
            make("b", family: .inlineText),
            make("c", family: .table),
        ]
        let grouped = DemoCatalog.groupedByFamily(in: ex)
        // 顺序遵循 ExampleFamily.allCases：inlineText 在 table 之前
        XCTAssertEqual(grouped.map(\.family), [.inlineText, .table])
        XCTAssertEqual(grouped[0].items.map(\.id), ["b"])
        XCTAssertEqual(grouped[1].items.map(\.id), ["a", "c"])
    }

    func testGroupedByFamilyExcludesHiddenAndEmpty() {
        let ex = [
            make("a", family: .link),
            make("b", family: .link, visibility: .hidden),
        ]
        // link 族只剩一个可见 → 应出现
        let grouped = DemoCatalog.groupedByFamily(in: ex)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].family, .link)
        XCTAssertEqual(grouped[0].items.map(\.id), ["a"])
    }
}
