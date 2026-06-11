import XCTest
@testable import XMarkup

// MARK: - MarkupTheme 类型化主题测试

final class MarkupThemeTests: XCTestCase {

    // MARK: - 基础结构

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
        XCTAssertEqual(theme.heading.scale, .default)
    }

    func testThemeEquality() {
        let a = MarkupTheme.default
        let b = MarkupTheme.default
        XCTAssertEqual(a, b)
    }

    func testThemeEqualityIgnoresMedia() {
        var a = MarkupTheme()
        a.media = .placeholder
        var b = MarkupTheme()
        b.media = .imageProvider({ _ in nil })
        // media 不同但其他字段相同，应判等
        XCTAssertEqual(a, b)
    }

    func testThemeInequalityDifferentTypedTheme() {
        let a = MarkupTheme()
        var b = MarkupTheme()
        b.paragraph.spacingBefore = 20
        XCTAssertNotEqual(a, b)
    }

    func testThemeMediaDefault() {
        let theme = MarkupTheme.default
        if case .placeholder = theme.media {
            // 正确
        } else {
            XCTFail("Expected .placeholder")
        }
    }

    // MARK: - Typed Theme 字段验证

    func testDefaultParagraphTheme() {
        let theme = MarkupTheme()
        XCTAssertEqual(theme.paragraph.spacingBefore, 8)
        XCTAssertEqual(theme.paragraph.spacingAfter, 8)
        XCTAssertEqual(theme.paragraph.lineSpacing, 0)
    }

    func testDefaultBlockquoteTheme() {
        let theme = MarkupTheme()
        XCTAssertEqual(theme.blockquote.indent, 12)
    }

    func testDefaultListTheme() {
        let theme = MarkupTheme()
        XCTAssertEqual(theme.list.indentUnit, 24)
        XCTAssertEqual(theme.list.orderedMarker, .decimal)
        XCTAssertEqual(theme.list.unorderedMarker, .disc)
    }

    func testDefaultInlineTextThemes() {
        let theme = MarkupTheme()
        // 默认 inline text themes 不应有 nil resolve
        XCTAssertNotNil(theme.bold)
        XCTAssertNotNil(theme.italic)
        XCTAssertNotNil(theme.codeInline)
        XCTAssertNotNil(theme.mark)
        XCTAssertNotNil(theme.link)
    }
}

// MARK: - Result Builder DSL 测试

final class ThemeBuilderTests: XCTestCase {

    func testBaseFontComponent() {
        let theme = MarkupTheme {
            BaseFont(XMFont.systemFont(ofSize: 20))
        }
        XCTAssertEqual(theme.baseFont.pointSize, 20)
    }

    func testHeadingComponent() {
        let theme = MarkupTheme {
            Heading {
                $0.scale = HeadingScale(h1: 3.0, h2: 2.0, h3: 1.5, h4: 1.0, h5: 0.8, h6: 0.6)
                $0.bold = true
            }
        }
        XCTAssertEqual(theme.heading.scale.h1, 3.0)
        XCTAssertEqual(theme.heading.scale.h2, 2.0)
        XCTAssertTrue(theme.heading.bold)
    }

    func testParagraphComponent() {
        let theme = MarkupTheme {
            Paragraph {
                $0.spacingBefore = 12
                $0.spacingAfter = 12
                $0.lineSpacing = 4
            }
        }
        XCTAssertEqual(theme.paragraph.spacingBefore, 12)
        XCTAssertEqual(theme.paragraph.spacingAfter, 12)
        XCTAssertEqual(theme.paragraph.lineSpacing, 4)
    }

    func testBlockquoteComponent() {
        let theme = MarkupTheme {
            Blockquote {
                $0.indent = 20
                $0.borderWidth = 4
            }
        }
        XCTAssertEqual(theme.blockquote.indent, 20)
        XCTAssertEqual(theme.blockquote.borderWidth, 4)
    }

    func testCodeComponent() {
        let theme = MarkupTheme {
            Code { theme in
                theme.font = XMFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            }
        }
        XCTAssertNotNil(theme.codeInline.font)
        XCTAssertEqual(theme.codeInline.font?.pointSize, 14)
    }

    func testMarkComponent() {
        let theme = MarkupTheme {
            Mark { theme in
                #if canImport(UIKit)
                theme.backgroundColor = .systemYellow.withAlphaComponent(0.3)
                #elseif canImport(AppKit)
                theme.backgroundColor = .systemYellow.withAlphaComponent(0.3)
                #endif
            }
        }
        XCTAssertNotNil(theme.mark.backgroundColor)
    }

    func testLinkComponent() {
        let theme = MarkupTheme {
            Link {
                #if canImport(UIKit)
                $0.textColor = .systemBlue
                #elseif canImport(AppKit)
                $0.textColor = .linkColor
                #endif
            }
        }
        XCTAssertNotNil(theme.link.textColor)
    }

    func testMediaComponent() {
        let theme = MarkupTheme {
            Media(.placeholder)
        }
        if case .placeholder = theme.media {
            // 正确
        } else {
            XCTFail("Expected .placeholder")
        }
    }

    func testListComponent() {
        let theme = MarkupTheme {
            List {
                $0.indentUnit = 32
                $0.orderedMarker = .lowerRoman
            }
        }
        XCTAssertEqual(theme.list.indentUnit, 32)
        XCTAssertEqual(theme.list.orderedMarker, .lowerRoman)
    }

    func testMultipleComponents() {
        let theme = MarkupTheme {
            BaseFont(XMFont.systemFont(ofSize: 14))
            Heading {
                $0.scale = HeadingScale(h1: 2.5)
            }
            Code { theme in
                theme.font = XMFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            }
            Link {
                #if canImport(UIKit)
                $0.textColor = .tintColor
                #elseif canImport(AppKit)
                $0.textColor = .controlAccentColor
                #endif
            }
        }
        XCTAssertEqual(theme.baseFont.pointSize, 14)
        XCTAssertEqual(theme.heading.scale.h1, 2.5)
        XCTAssertNotNil(theme.codeInline.font)
        XCTAssertNotNil(theme.link.textColor)
    }
}

// MARK: - 预置主题测试

final class PresetThemesTests: XCTestCase {

    func testDefaultTheme() {
        let theme = MarkupTheme.default
        XCTAssertEqual(theme.baseFont.pointSize, 16)
        XCTAssertNotNil(theme.codeInline.font)
        XCTAssertNotNil(theme.mark.backgroundColor)
    }

    func testDarkTheme() {
        let theme = MarkupTheme.dark
        XCTAssertEqual(theme.baseFont.pointSize, 16)
        XCTAssertNotNil(theme.codeInline.font)
        XCTAssertNotNil(theme.mark.backgroundColor)
    }

    func testChatTheme() {
        let theme = MarkupTheme.chat
        XCTAssertEqual(theme.baseFont.pointSize, 14)
    }

    func testArticleTheme() {
        let theme = MarkupTheme.article
        XCTAssertEqual(theme.baseFont.pointSize, 17)
        XCTAssertNotNil(theme.blockquote.textColor)
        XCTAssertNotNil(theme.codeInline.font)
    }

    func testDefaultThemeHasPlaceholderStrategy() {
        let theme = MarkupTheme.default
        if case .placeholder = theme.media {
            // 正确
        } else {
            XCTFail("Expected .placeholder")
        }
    }
}
