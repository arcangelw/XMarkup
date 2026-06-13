import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import XMarkupDemoSwiftUI

final class DemoCanvasConfigTests: XCTestCase {

    func testDefaultValuesAlignWebBaseline() {
        let c = DemoCanvasConfig()
        XCTAssertEqual(c.paddingTop, 16)
        XCTAssertEqual(c.paddingLeading, 16)
        XCTAssertEqual(c.paddingBottom, 16)
        XCTAssertEqual(c.paddingTrailing, 16)
        XCTAssertEqual(c.lineHeight, 1.6, accuracy: 0.001)
        XCTAssertEqual(c.baseFontSize, 16)
        XCTAssertEqual(c.baseFontFamily, "-apple-system")
    }

    func testCSSStringContainsPaddingLineHeightFontSize() {
        let c = DemoCanvasConfig()
        let css = c.cssString()
        XCTAssertTrue(css.contains("padding"))
        XCTAssertTrue(css.contains("line-height: 1.6"))
        XCTAssertTrue(css.contains("font-size: 16"))
        XCTAssertTrue(css.contains("-apple-system"))
    }

    func testCustomConfigCSSReflectsValues() {
        let c = DemoCanvasConfig(paddingTop: 8, paddingLeading: 12,
                                 paddingBottom: 8, paddingTrailing: 12,
                                 lineHeight: 1.8, baseFontSize: 18)
        let css = c.cssString()
        XCTAssertTrue(css.contains("padding: 8px 12px 8px 12px"), css)
        XCTAssertTrue(css.contains("line-height: 1.8"))
        XCTAssertTrue(css.contains("font-size: 18"))
    }

    #if canImport(UIKit)
    func testUITextContainerInsetMapsAllFourSides() {
        let c = DemoCanvasConfig(paddingTop: 10, paddingLeading: 20,
                                 paddingBottom: 30, paddingTrailing: 40)
        let inset = c.uiTextContainerInset
        XCTAssertEqual(inset.top, 10)
        XCTAssertEqual(inset.left, 20)
        XCTAssertEqual(inset.bottom, 30)
        XCTAssertEqual(inset.right, 40)
    }
    #endif

    func testBaseFontUsesConfiguredSize() {
        XCTAssertEqual(DemoCanvasConfig(baseFontSize: 20).baseFont.pointSize, 20)
        XCTAssertEqual(DemoCanvasConfig(baseFontSize: 14).baseFont.pointSize, 14)
    }

    func testEquatable() {
        XCTAssertEqual(DemoCanvasConfig(), DemoCanvasConfig())
        XCTAssertNotEqual(DemoCanvasConfig(lineHeight: 1.5), DemoCanvasConfig())
    }
}
