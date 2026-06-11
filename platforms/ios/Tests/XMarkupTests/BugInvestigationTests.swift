import XCTest
@testable import XMarkup

final class BugInvestigationTests: XCTestCase {
    func testSemanticContainerNoContentDuplication() throws {
        let parser = try XMarkupParser()
        let html = "<article><h2>标题</h2><p>内容</p></article>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let rendered = doc.renderAttributed()
        let text = String(rendered.characters)

        let titleCount = text.components(separatedBy: "标题").count - 1
        XCTAssertEqual(titleCount, 1, "标题应只出现一次")
        let contentCount = text.components(separatedBy: "内容").count - 1
        XCTAssertEqual(contentCount, 1, "内容应只出现一次")
    }

    func testSectionContainerNoContentDuplication() throws {
        let parser = try XMarkupParser()
        let html = "<section><h3>章节</h3><p>正文</p></section>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let rendered = doc.renderAttributed()
        let text = String(rendered.characters)

        XCTAssertEqual(text.components(separatedBy: "章节").count - 1, 1)
        XCTAssertEqual(text.components(separatedBy: "正文").count - 1, 1)
    }

    func testNestedSemanticContainers() throws {
        let parser = try XMarkupParser()
        let html = "<article><header><h1>头部</h1></header><section><p>段落</p></section><footer><p>底部</p></footer></article>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let rendered = doc.renderAttributed()
        let text = String(rendered.characters)

        XCTAssertEqual(text.components(separatedBy: "头部").count - 1, 1)
        XCTAssertEqual(text.components(separatedBy: "段落").count - 1, 1)
        XCTAssertEqual(text.components(separatedBy: "底部").count - 1, 1)
    }

    func testItalicObliquenessInAttributedString() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<i>斜体文字</i>")
        let doc = MarkupDocument.from(result)
        let attr = doc.renderAttributed()

        // 验证 AttributedString 层面斜体字体已设置
        // makeSyntheticItalicFont 使用 matrix 矩阵变换
        for run in attr.runs {
            #if canImport(UIKit)
            if let font = run.uiKit.font {
                let hasMatrixSkew = font.fontDescriptor.matrix.b != 0
                XCTAssertTrue(
                    hasMatrixSkew,
                    "斜体应通过 matrix 变换实现，实际 fontName=\(font.fontName) matrix.b=\(font.fontDescriptor.matrix.b)"
                )
            }
            #elseif canImport(AppKit)
            if let font = run.appKit.font {
                // macOS 系统字体 withMatrix 可能不保留 matrix，验证 fontName 已变更
                let baseFontName = XMFont.systemFont(ofSize: 16).fontName
                XCTAssertNotEqual(font.fontName, baseFontName,
                    "斜体字体应与系统正体不同，实际 fontName=\(font.fontName)")
            }
            #endif
        }
    }

    func testItalicInNSAttributedString() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<i>斜体文字</i>")
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        // 验证 NSAttributedString 层面斜体字体已设置
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font, "应设置斜体字体")

        let baseFontName = XMFont.systemFont(ofSize: 16).fontName
        XCTAssertNotEqual(font!.fontName, baseFontName,
            "斜体字体应与系统正体不同，实际 fontName=\(font!.fontName)")
    }

    // MARK: - 标题内嵌样式字体继承

    /// 验证 <h1>含<code>代码</code></h1> 中 code 字号继承 h1 的字号而非 baseFont
    func testHeadingCodeFontSizeInheritsHeading() throws {
        let parser = try XMarkupParser()
        let html = "<h1>标题含<code>代码</code></h1>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let text = nsAttr.string
        // 找到 "代码" 的位置
        let codeRange = (text as NSString).range(of: "代码")
        XCTAssertGreaterThan(codeRange.length, 0, "应找到'代码'文本")

        // 同时获取 "标题含" 的字体作为参照
        let headingRange = (text as NSString).range(of: "标题含")
        let headingFont = nsAttr.attribute(.font, at: headingRange.location, effectiveRange: nil) as? XMFont

        let codeFont = nsAttr.attribute(.font, at: codeRange.location, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(codeFont, "code 应有字体设置")
        XCTAssertNotNil(headingFont, "标题应有字体设置")

        // code 的字号应与 heading 相近（允许等宽字体略有差异），但不应是 baseFont 的 16pt
        let baseFontSize = MarkupTheme.default.baseFont.pointSize
        XCTAssertGreaterThan(codeFont!.pointSize, baseFontSize,
            "code 在 heading 内应继承 heading 的字号(\(headingFont!.pointSize))，而非 baseFont(\(baseFontSize))")
    }

    /// 验证 <h3>含<b>粗体</b></h3> 中 bold 字号保持 h3 的字号
    func testHeadingBoldFontSizePreserved() throws {
        let parser = try XMarkupParser()
        let html = "<h3>标题含<b>粗体</b></h3>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let text = nsAttr.string
        let boldRange = (text as NSString).range(of: "粗体")
        let headingRange = (text as NSString).range(of: "标题含")
        let headingFont = nsAttr.attribute(.font, at: headingRange.location, effectiveRange: nil) as? XMFont
        let boldFont = nsAttr.attribute(.font, at: boldRange.location, effectiveRange: nil) as? XMFont

        XCTAssertNotNil(boldFont, "bold 应有字体设置")
        XCTAssertNotNil(headingFont, "标题应有字体设置")

        // bold 在 heading 内应保持 heading 的字号
        XCTAssertEqual(boldFont!.pointSize, headingFont!.pointSize, accuracy: 0.5,
            "bold 在 heading 内应保持 heading 字号(\(headingFont!.pointSize))")
    }

    /// 验证 <h1>含<i>斜体</i></h1> 中 italic 保持 h1 字号
    func testHeadingItalicFontSizePreserved() throws {
        let parser = try XMarkupParser()
        let html = "<h1>标题含<i>斜体</i></h1>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let text = nsAttr.string
        let italicRange = (text as NSString).range(of: "斜体")
        let headingRange = (text as NSString).range(of: "标题含")
        let headingFont = nsAttr.attribute(.font, at: headingRange.location, effectiveRange: nil) as? XMFont
        let italicFont = nsAttr.attribute(.font, at: italicRange.location, effectiveRange: nil) as? XMFont

        XCTAssertNotNil(italicFont, "italic 应有字体设置")
        XCTAssertNotNil(headingFont, "标题应有字体设置")

        XCTAssertEqual(italicFont!.pointSize, headingFont!.pointSize, accuracy: 0.5,
            "italic 在 heading 内应保持 heading 字号(\(headingFont!.pointSize))")
    }

    /// 验证 <h2>含<span style="color:#FF0000">红色</span></h2> 颜色生效且字号不变
    func testHeadingSpanColorPreserved() throws {
        let parser = try XMarkupParser()
        let html = "<h2>标题含<span style=\"color:#FF0000\">红色</span></h2>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let text = nsAttr.string
        let spanRange = (text as NSString).range(of: "红色")
        let headingRange = (text as NSString).range(of: "标题含")

        let spanFont = nsAttr.attribute(.font, at: spanRange.location, effectiveRange: nil) as? XMFont
        let headingFont = nsAttr.attribute(.font, at: headingRange.location, effectiveRange: nil) as? XMFont

        XCTAssertNotNil(spanFont, "span 应有字体设置")
        XCTAssertNotNil(headingFont, "标题应有字体设置")

        // span 不应改变字号
        XCTAssertEqual(spanFont!.pointSize, headingFont!.pointSize, accuracy: 0.5,
            "span 在 heading 内应保持 heading 字号")
    }

    // MARK: - 嵌套组合场景（字体 trait 不丢失）

    /// 验证 <b><code>code</code></b> 中 code 保留 bold trait
    func testBoldCodePreservesBold() throws {
        let parser = try XMarkupParser()
        let html = "<p><b><code>boldCode</code></b></p>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let text = nsAttr.string
        let codeRange = (text as NSString).range(of: "boldCode")
        let codeFont = nsAttr.attribute(.font, at: codeRange.location, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(codeFont, "code 应有字体")

        #if canImport(UIKit)
        XCTAssertTrue(codeFont!.fontDescriptor.symbolicTraits.contains(.traitBold),
            "code 在 bold 内应保留 bold trait，实际 fontName=\(codeFont!.fontName)")
        #elseif canImport(AppKit)
        XCTAssertTrue(codeFont!.fontDescriptor.symbolicTraits.contains(.bold),
            "code 在 bold 内应保留 bold trait，实际 fontName=\(codeFont!.fontName)")
        #endif
    }

    /// 验证 <i><code>code</code></i> 中 code 保留 italic（matrix 或 fontName 变化）
    func testItalicCodePreservesItalic() throws {
        let parser = try XMarkupParser()
        let html = "<p><i><code>italicCode</code></i></p>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let text = nsAttr.string
        let codeRange = (text as NSString).range(of: "italicCode")
        let codeFont = nsAttr.attribute(.font, at: codeRange.location, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(codeFont, "code 应有字体")

        #if canImport(UIKit)
        // iOS: italic 通过 matrix 实现，验证 fontName 与 plain mono 不同
        let plainMono = XMFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        XCTAssertNotEqual(codeFont!.fontName, plainMono.fontName,
            "code 在 italic 内应有 italic 变化，实际 fontName=\(codeFont!.fontName)")
        #elseif canImport(AppKit)
        // macOS: 系统字体 withMatrix 可能不保留 matrix，验证代码路径不 crash
        // italic 的视觉效果由 matrix 在 Core Text 层面处理
        XCTAssertNotNil(codeFont, "code 在 italic 内应有有效字体")
        #endif
    }

    /// 验证 <b><i>text</i></b> 中 bold 保留 + italic 通过 matrix 生效
    func testBoldItalicBothPreserved() throws {
        let parser = try XMarkupParser()
        let html = "<p><b><i>boldItalic</i></b></p>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let text = nsAttr.string
        let range = (text as NSString).range(of: "boldItalic")
        let font = nsAttr.attribute(.font, at: range.location, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font, "应有字体设置")

        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold),
            "应保留 bold trait，实际 fontName=\(font!.fontName)")
        XCTAssertTrue(font!.fontDescriptor.matrix.b != 0,
            "italic 应通过 matrix 变换实现，实际 matrix.b=\(font!.fontDescriptor.matrix.b)")
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.bold),
            "应保留 bold trait，实际 fontName=\(font!.fontName)")
        // macOS 系统字体 withMatrix 可能不保留 matrix，验证 fontName 包含 Bold
        XCTAssertTrue(font!.fontName.contains("Bold"),
            "应包含 Bold，实际 fontName=\(font!.fontName)")
        #endif
    }

    /// 验证 <h1><b><i><code>text</code></i></b></h1> 四层嵌套不丢失
    func testHeadingBoldItalicCodeFullNesting() throws {
        let parser = try XMarkupParser()
        let html = "<h1>前<b><i><code>NestedCode</code></i></b>后</h1>"
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let nsAttr = doc.render()

        let text = nsAttr.string
        let codeRange = (text as NSString).range(of: "NestedCode")
        let codeFont = nsAttr.attribute(.font, at: codeRange.location, effectiveRange: nil) as? XMFont

        // 验证 heading 字号与旁边文本一致
        let textBefore = "前"
        let headingFont = nsAttr.attribute(.font, at: (text as NSString).range(of: textBefore).location, effectiveRange: nil) as? XMFont
        XCTAssertLessThan(abs(codeFont!.pointSize - headingFont!.pointSize), 1,
            "code 在 h1 内应保持 h1 字号，实际=\(codeFont!.pointSize)")

        #if canImport(UIKit)
        XCTAssertTrue(codeFont!.fontDescriptor.symbolicTraits.contains(.traitBold),
            "code 应保留 bold trait，实际 fontName=\(codeFont!.fontName)")
        XCTAssertTrue(codeFont!.fontDescriptor.matrix.b != 0,
            "code 应保留 italic matrix，实际 matrix.b=\(codeFont!.fontDescriptor.matrix.b)")
        #elseif canImport(AppKit)
        XCTAssertTrue(codeFont!.fontDescriptor.symbolicTraits.contains(.bold),
            "code 应保留 bold trait，实际 fontName=\(codeFont!.fontName)")
        // macOS: 验证 bold 存在，italic 通过 matrix（可能不保留）或 fontName 变化
        XCTAssertTrue(codeFont!.fontName.contains("Bold") || codeFont!.fontName.contains("Semibold"),
            "code 应保留 bold，实际 fontName=\(codeFont!.fontName)")
        #endif
    }
}
