import XCTest
@testable import XMarkup

// MARK: - 任务 7：MarkupTheme 基础结构测试

final class MarkupThemeTests: XCTestCase {

    func testTagStyleKeyAllCases() {
        XCTAssertEqual(TagStyleKey.allCases.count, 23)
    }

    func testTagStyleKeyRawValue() {
        XCTAssertEqual(TagStyleKey.bold.rawValue, "bold")
        XCTAssertEqual(TagStyleKey.heading.rawValue, "heading")
    }

    func testDefaultHeadingScale() {
        let scale = HeadingScale.default
        XCTAssertEqual(scale.h1, 2.0)
        XCTAssertEqual(scale.h2, 1.5)
        XCTAssertEqual(scale.h3, 1.17)
        XCTAssertEqual(scale.h4, 1.0)
        XCTAssertEqual(scale.h5, 0.83)
        XCTAssertEqual(scale.h6, 0.67)
    }

    func testCustomHeadingScale() {
        let scale = HeadingScale(h1: 3.0, h2: 2.0, h3: 1.5, h4: 1.0, h5: 0.8, h6: 0.6)
        XCTAssertEqual(scale.h1, 3.0)
    }

    func testDefaultThemeBaseFont() {
        let theme = MarkupTheme.default
        XCTAssertEqual(theme.baseFont.pointSize, 16)
    }

    func testDefaultThemeHasHeadingScale() {
        let theme = MarkupTheme.default
        XCTAssertEqual(theme.headingScale, .default)
    }

    func testThemeEquality() {
        let a = MarkupTheme.default
        let b = MarkupTheme.default
        XCTAssertEqual(a, b)
    }

    func testThemeEqualityIgnoresMediaStrategy() {
        let a = MarkupTheme(mediaStrategy: .placeholder)
        let b: MarkupTheme = MarkupTheme(mediaStrategy: .imageProvider({ _ in nil }))
        // mediaStrategy 不同但 baseFont/headingScale/tagStyles 相同，应判等
        XCTAssertEqual(a, b)
    }

    func testThemeInequalityDifferentTagStyles() {
        let a = MarkupTheme()
        var b = MarkupTheme()
        var container = AttributeContainer()
        #if canImport(UIKit)
        container.uiKit.foregroundColor = .red
        #elseif canImport(AppKit)
        container.appKit.foregroundColor = .red
        #endif
        b.tagStyles[.bold] = container
        XCTAssertNotEqual(a, b)
    }

    func testThemeWithCustomTagStyle() {
        var theme = MarkupTheme.default
        var container = AttributeContainer()
        #if canImport(UIKit)
        container.uiKit.foregroundColor = .systemBlue
        #elseif canImport(AppKit)
        container.appKit.foregroundColor = .systemBlue
        #endif
        theme.tagStyles[.link] = container
        XCTAssertNotNil(theme.tagStyles[.link])
    }

    func testThemeMediaStrategyDefault() {
        let theme = MarkupTheme.default
        if case .placeholder = theme.mediaStrategy {
            // 正确
        } else {
            XCTFail("Expected .placeholder")
        }
    }
}

// MARK: - 任务 8：Result Builder DSL 测试

final class ThemeBuilderTests: XCTestCase {

    func testBaseFontComponent() {
        let theme = MarkupTheme {
            BaseFont(XMFont.systemFont(ofSize: 20))
        }
        XCTAssertEqual(theme.baseFont.pointSize, 20)
    }

    func testHeadingScaleComponent() {
        let theme = MarkupTheme {
            HeadingScaleComponent(HeadingScale(h1: 3.0, h2: 2.0, h3: 1.5, h4: 1.0, h5: 0.8, h6: 0.6))
        }
        XCTAssertEqual(theme.headingScale.h1, 3.0)
        XCTAssertEqual(theme.headingScale.h2, 2.0)
    }

    func testTagComponent() {
        let theme = MarkupTheme {
            Tag(.link) { container in
                #if canImport(UIKit)
                container.uiKit.foregroundColor = .systemBlue
                #elseif canImport(AppKit)
                container.appKit.foregroundColor = .systemBlue
                #endif
            }
        }
        XCTAssertNotNil(theme.tagStyles[.link])
    }

    func testMediaComponent() {
        let theme = MarkupTheme {
            Media(.placeholder)
        }
        if case .placeholder = theme.mediaStrategy {
            // 正确
        } else {
            XCTFail("Expected .placeholder")
        }
    }

    func testMultipleComponents() {
        let theme = MarkupTheme {
            BaseFont(XMFont.systemFont(ofSize: 14))
            HeadingScaleComponent(HeadingScale(h1: 2.5))
            Tag(.code) { container in
                #if canImport(UIKit)
                container.uiKit.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
                container.uiKit.backgroundColor = .systemGray6
                #elseif canImport(AppKit)
                container.appKit.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
                #endif
            }
            Tag(.link) { container in
                #if canImport(UIKit)
                container.uiKit.foregroundColor = .tintColor
                #elseif canImport(AppKit)
                container.appKit.foregroundColor = .controlAccentColor
                #endif
            }
        }
        XCTAssertEqual(theme.baseFont.pointSize, 14)
        XCTAssertEqual(theme.headingScale.h1, 2.5)
        XCTAssertNotNil(theme.tagStyles[.code])
        XCTAssertNotNil(theme.tagStyles[.link])
    }
}

// MARK: - 任务 9：预置主题测试

final class PresetThemesTests: XCTestCase {

    func testDefaultTheme() {
        let theme = MarkupTheme.default
        XCTAssertEqual(theme.baseFont.pointSize, 16)
        XCTAssertNotNil(theme.tagStyles[.mark])
        XCTAssertNotNil(theme.tagStyles[.code])
    }

    func testDarkTheme() {
        let theme = MarkupTheme.dark
        XCTAssertEqual(theme.baseFont.pointSize, 16)
        XCTAssertNotNil(theme.tagStyles[.mark])
        XCTAssertNotNil(theme.tagStyles[.code])
    }

    func testChatTheme() {
        let theme = MarkupTheme.chat
        XCTAssertEqual(theme.baseFont.pointSize, 14)
        XCTAssertNotNil(theme.tagStyles[.link])
    }

    func testArticleTheme() {
        let theme = MarkupTheme.article
        XCTAssertEqual(theme.baseFont.pointSize, 17)
        XCTAssertNotNil(theme.tagStyles[.blockquote])
        XCTAssertNotNil(theme.tagStyles[.code])
    }

    func testDefaultThemeHasPlaceholderStrategy() {
        let theme = MarkupTheme.default
        if case .placeholder = theme.mediaStrategy {
            // 正确
        } else {
            XCTFail("Expected .placeholder")
        }
    }
}
