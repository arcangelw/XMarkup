import XCTest
@testable import XMarkupDemoSwiftUI

/// 数据完整性测试 — 验证 12 族用例体系的收编正确性
final class DemoCatalogDataTests: XCTestCase {

    func testNoExampleIDCollision() {
        let ids = DemoCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "用例 id 重复")
    }

    func testAllTwelveFamiliesHaveExamples() {
        let families = Set(DemoCatalog.all.map(\.family))
        XCTAssertEqual(families.count, 12, "应有 12 个族有用例")
        for family in ExampleFamily.allCases {
            XCTAssertTrue(families.contains(family), "\(family.displayName) 族无用例")
        }
    }

    func testTotalExampleCountPreserved() {
        // 66 旧用例（全部迁移）+ 7 新增表格（table-layout 为迁移，不计新增）= 73
        XCTAssertEqual(DemoCatalog.all.count, 73, "用例总数应为 73（66 旧 + 7 新表格）")
    }

    func testTableCoversColspanRowspanTfootNestedList() {
        let html = DemoCatalog.all.filter { $0.family == .table }.map(\.html).joined()
        XCTAssertTrue(html.contains("colspan"), "表格族缺 colspan 用例")
        XCTAssertTrue(html.contains("rowspan"), "表格族缺 rowspan 用例")
        XCTAssertTrue(html.contains("tfoot"), "表格族缺 tfoot 用例")
        XCTAssertTrue(html.contains("<ul>"), "表格族缺嵌套列表用例")
    }

    func testAPITestExamplesHidden() {
        let hidden = DemoCatalog.all.filter { $0.visibility == .hidden }
        XCTAssertGreaterThanOrEqual(hidden.count, 2, "apiTest 用例应隐藏")
        let hiddenIDs = Set(hidden.map(\.id))
        XCTAssertTrue(DemoCatalog.visible.map(\.id).filter { hiddenIDs.contains($0) }.isEmpty,
                      "hidden 用例不应出现在 visible")
    }

    func testRegressionExamplesHaveNote() {
        let regressions = DemoCatalog.all.filter { $0.isRegression }
        XCTAssertGreaterThan(regressions.count, 0, "应存在回归用例")
        for ex in regressions {
            XCTAssertNotNil(ex.note, "回归用例 \(ex.id) 缺 note 说明")
        }
    }

    func testGroupedByFamilyMatchesVisible() {
        let grouped = DemoCatalog.groupedByFamily()
        XCTAssertGreaterThanOrEqual(grouped.count, 11, "可见族应 >= 11")
        let groupedIDs = Set(grouped.flatMap { $0.items.map(\.id) })
        let visibleIDs = Set(DemoCatalog.visible.map(\.id))
        XCTAssertEqual(groupedIDs, visibleIDs, "groupedByFamily 应覆盖全部 visible")
    }

    func testSearchFindsAcrossFamilies() {
        let result = DemoCatalog.search("粗体")
        XCTAssertTrue(result.contains { $0.id == "bold" }, "搜索「粗体」应命中 bold")
    }
}
