import XCTest
@testable import XMarkupDemoSwiftUI

final class DemoExampleModelTests: XCTestCase {

    func testExampleFamilyHasTwelveCases() {
        XCTAssertEqual(ExampleFamily.allCases.count, 12)
    }

    func testExampleTierHasThreeCases() {
        XCTAssertEqual(ExampleTier.allCases.count, 3)
    }

    func testFamilyDisplayNameAndSymbolNonEmpty() {
        for family in ExampleFamily.allCases {
            XCTAssertFalse(family.displayName.isEmpty, "\(family) 缺少 displayName")
            XCTAssertFalse(family.symbol.isEmpty, "\(family) 缺少 SF Symbol")
        }
    }

    func testFunctionalFamilies() {
        XCTAssertTrue(ExampleFamily.theme.isFunctional)
        XCTAssertTrue(ExampleFamily.showcase.isFunctional)
        XCTAssertTrue(ExampleFamily.robustness.isFunctional)
        XCTAssertFalse(ExampleFamily.inlineText.isFunctional)
        XCTAssertFalse(ExampleFamily.table.isFunctional)
    }

    func testDemoExampleDefaults() {
        let ex = DemoExample(id: "x", title: "T", summary: "S", html: "<b/>",
                             family: .inlineText, tier: .basic)
        XCTAssertEqual(ex.visibility, .visible)
        XCTAssertFalse(ex.isRegression)
        XCTAssertNil(ex.note)
        XCTAssertNil(ex.themeOverride)
        XCTAssertNil(ex.themeVariants)
        XCTAssertNil(ex.appendHTML)
    }

    func testDemoExampleIsIdentifiable() {
        let ex = DemoExample(id: "abc", title: "", summary: "", html: "",
                             family: .list, tier: .nested)
        XCTAssertEqual(ex.id, "abc")
    }
}
