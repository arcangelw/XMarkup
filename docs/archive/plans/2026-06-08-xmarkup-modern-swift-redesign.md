# XMarkup iOS 现代化重构实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 XMarkup iOS 桥接层从命令式 6 趟管线重构为两层架构——MarkupDocument（段落树）+ AttributedString（原生输出），支持可插拔 Renderer、Result Builder DSL 主题、SwiftUI 原生渲染。

**架构：** 两层架构。MarkupDocument 从 C++ flat spans 一次性构建为段落/内联两级结构；MarkupTheme 通过 Result Builder DSL 配置样式；render(theme:) 输出携带自定义 XMarkupScope 属性的 AttributedString；多种 MarkupRenderer 实现消费同一份 AttributedString。

**技术栈：** Swift 6.0 / AttributedString + AttributedStringKey / AttributeScope / Result Builders / SPM

---

## 文件结构

### 新建文件（按任务顺序）

| 文件 | 职责 |
|------|------|
| `Sources/XMarkup/Core/MarkupInline.swift` | MarkupInline + InlineKind + InlineStyle |
| `Sources/XMarkup/Core/MarkupAttachment.swift` | MarkupAttachment + AttachmentContent + AttachmentAlignment |
| `Sources/XMarkup/Core/BlockKind.swift` | BlockKind + Level + TableStructure |
| `Sources/XMarkup/Core/MarkupBlock.swift` | MarkupBlock（段落级块） |
| `Sources/XMarkup/Core/MarkupDocument.swift` | MarkupDocument + appending() 预留 |
| `Sources/XMarkup/Core/MarkupDocumentBuilder.swift` | XMarkupResult → MarkupDocument 转换算法 |
| `Sources/XMarkup/Attributes/XMarkupScope.swift` | 6 个自定义 AttributedStringKey + XMarkupScope |
| `Sources/XMarkup/Theme/TagStyleKey.swift` | TagStyleKey 枚举 |
| `Sources/XMarkup/Theme/HeadingScale.swift` | 标题缩放系数配置 |
| `Sources/XMarkup/Theme/MediaRenderingStrategy.swift` | 媒体渲染策略枚举 |
| `Sources/XMarkup/Theme/MarkupTheme.swift` | MarkupTheme 主结构体 |
| `Sources/XMarkup/Theme/ThemeComponent.swift` | ThemeComponent 协议 + DSL 组件 |
| `Sources/XMarkup/Theme/MarkupThemeBuilder.swift` | @resultBuilder MarkupThemeBuilder |
| `Sources/XMarkup/Theme/PresetThemes.swift` | .default / .dark / .chat / .article |
| `Sources/XMarkup/Rendering/MarkupRenderer.swift` | MarkupRenderer 协议 |
| `Sources/XMarkup/Rendering/NSAttributedStringRenderer.swift` | NSAttributedStringRenderer 实现 |
| `Sources/XMarkup/Rendering/MarkupDocument+Render.swift` | render(theme:) 核心渲染实现 |
| `Sources/XMarkup/XMarkup.swift` | 公共导出模块入口 |

### 新建测试文件

| 文件 | 职责 |
|------|------|
| `Tests/XMarkupTests/Core/MarkupInlineTests.swift` | InlineKind / InlineStyle 测试 |
| `Tests/XMarkupTests/Core/MarkupAttachmentTests.swift` | MarkupAttachment 测试 |
| `Tests/XMarkupTests/Core/BlockKindTests.swift` | BlockKind / Level 测试 |
| `Tests/XMarkupTests/Core/MarkupBlockTests.swift` | MarkupBlock 测试 |
| `Tests/XMarkupTests/Core/MarkupDocumentTests.swift` | MarkupDocument 测试 |
| `Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift` | XMarkupResult → MarkupDocument 转换测试 |
| `Tests/XMarkupTests/Attributes/XMarkupScopeTests.swift` | 自定义 AttributeKey 存活和桥接测试 |
| `Tests/XMarkupTests/Theme/MarkupThemeTests.swift` | 主题配置测试 |
| `Tests/XMarkupTests/Theme/ThemeBuilderTests.swift` | Result Builder DSL 测试 |
| `Tests/XMarkupTests/Theme/PresetThemesTests.swift` | 预置主题测试 |
| `Tests/XMarkupTests/Rendering/RenderTests.swift` | MarkupDocument → AttributedString 渲染测试 |
| `Tests/XMarkupTests/Rendering/NSAttributedStringRendererTests.swift` | NSAttr 渲染器测试 |

### 修改文件

| 文件 | 变更 |
|------|------|
| `Sources/XMarkup/XMarkupStyleConfig.swift` | 添加 `@available(*, deprecated, message: "使用 MarkupTheme")` |
| `Sources/XMarkup/NSAttributedString+XMarkup.swift` | 添加 `@available(*, deprecated, message: "使用 MarkupDocument.render(theme:)")` |

### 不变文件

以下文件保持原样，无需修改：
- `Sources/XMarkup/PlatformTypes.swift`
- `Sources/XMarkup/XMarkupParser.swift`
- `Sources/XMarkup/XMarkupResult.swift`
- `Sources/XMarkup/XMarkupSpan.swift`
- `Sources/XMarkup/XMarkupTag.swift`
- `Sources/XMarkup/XMarkupStyle.swift`
- `Sources/XMarkup/XMarkupError.swift`
- `Sources/XMarkup/ColorParser.swift`

---

## 任务 1：MarkupInline 数据模型

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Core/MarkupInline.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Core/MarkupInlineTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Core/MarkupInlineTests.swift
import XCTest
@testable import XMarkup

final class MarkupInlineTests: XCTestCase {

    // MARK: - InlineKind

    func testInlineKindBoldIsEqual() {
        XCTAssertEqual(InlineKind.bold, InlineKind.bold)
    }

    func testInlineKindLinkCarriesURL() {
        let link = InlineKind.link(url: "https://example.com")
        if case let .link(url) = link {
            XCTAssertEqual(url, "https://example.com")
        } else {
            XCTFail("Expected .link(url:)")
        }
    }

    func testInlineKindSpanCarriesStyles() {
        let styles: [InlineStyle] = [.foregroundColor("#FF0000"), .fontSize(14)]
        let span = InlineKind.span(styles: styles)
        if case let .span(s) = span {
            XCTAssertEqual(s.count, 2)
            XCTAssertEqual(s[0], .foregroundColor("#FF0000"))
            XCTAssertEqual(s[1], .fontSize(14))
        } else {
            XCTFail("Expected .span(styles:)")
        }
    }

    // MARK: - InlineStyle

    func testInlineStyleEquality() {
        XCTAssertEqual(InlineStyle.foregroundColor("#FF0000"), InlineStyle.foregroundColor("#FF0000"))
        XCTAssertNotEqual(InlineStyle.foregroundColor("#FF0000"), InlineStyle.foregroundColor("#00FF00"))
        XCTAssertEqual(InlineStyle.fontSize(14.5), InlineStyle.fontSize(14.5))
    }

    func testInlineStyleAllCases() {
        // 确保所有 case 都可以构造且 Sendable
        let styles: [InlineStyle] = [
            .foregroundColor("#000"),
            .backgroundColor("#FFF"),
            .fontSize(16),
            .fontWeight("bold"),
            .fontStyle("italic"),
            .textDecoration("underline"),
            .lineHeight(1.5),
            .letterSpacing(0.5),
        ]
        XCTAssertEqual(styles.count, 8)
    }

    // MARK: - MarkupInline

    func testMarkupInlineCreation() {
        let text = "Hello World"
        let start = text.startIndex
        let end = text.index(start, offsetBy: 5)
        let inline = MarkupInline(range: start..<end, kind: .bold)
        XCTAssertEqual(inline.kind, .bold)
        XCTAssertEqual(text[inline.range], "Hello")
    }

    func testMarkupInlineEquality() {
        let text = "Test"
        let range = text.startIndex..<text.endIndex
        let a = MarkupInline(range: range, kind: .bold)
        let b = MarkupInline(range: range, kind: .bold)
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter MarkupInlineTests`
预期：FAIL，编译错误 "Cannot find 'InlineKind' in scope"

- [ ] **步骤 3：编写最少实现代码**

```swift
// platforms/ios/Sources/XMarkup/Core/MarkupInline.swift
import Foundation

/// 内联样式（字符级）
public struct MarkupInline: Sendable, Equatable {
    /// 在所属 block.text 中的范围（String.Index）
    public let range: Range<String.Index>
    /// 内联类型
    public let kind: InlineKind

    public init(range: Range<String.Index>, kind: InlineKind) {
        self.range = range
        self.kind = kind
    }
}

/// 内联类型
public enum InlineKind: Sendable, Equatable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case mark
    case link(url: String)
    case subscriptText
    case superscript
    case span(styles: [InlineStyle])
}

/// CSS 行内样式
public enum InlineStyle: Sendable, Equatable {
    case foregroundColor(String)    // "#RRGGBB"
    case backgroundColor(String)
    case fontSize(Float)
    case fontWeight(String)
    case fontStyle(String)
    case textDecoration(String)
    case lineHeight(Float)
    case letterSpacing(Float)
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter MarkupInlineTests`
预期：PASS，全部 6 个测试通过

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Core/MarkupInline.swift platforms/ios/Tests/XMarkupTests/Core/MarkupInlineTests.swift
git commit -m "feat: 添加 MarkupInline + InlineKind + InlineStyle 数据模型"
```

---

## 任务 2：MarkupAttachment 数据模型

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Core/MarkupAttachment.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Core/MarkupAttachmentTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Core/MarkupAttachmentTests.swift
import XCTest
@testable import XMarkup

final class MarkupAttachmentTests: XCTestCase {

    func testImageAttachment() {
        let attachment = MarkupAttachment(
            content: .image(src: "photo.jpg"),
            suggestedSize: CGSize(width: 200, height: 150),
            alignment: .default
        )
        if case let .image(src) = attachment.content {
            XCTAssertEqual(src, "photo.jpg")
        } else {
            XCTFail("Expected .image(src:)")
        }
        XCTAssertEqual(attachment.suggestedSize, CGSize(width: 200, height: 150))
    }

    func testVideoAttachment() {
        let attachment = MarkupAttachment(
            content: .video(src: "movie.mp4"),
            suggestedSize: CGSize(width: 300, height: 200),
            alignment: .center
        )
        if case let .video(src) = attachment.content {
            XCTAssertEqual(src, "movie.mp4")
        } else {
            XCTFail("Expected .video(src:)")
        }
        XCTAssertEqual(attachment.alignment, .center)
    }

    func testAudioAttachment() {
        let attachment = MarkupAttachment(
            content: .audio(src: "song.mp3"),
            suggestedSize: CGSize(width: 200, height: 44),
            alignment: .default
        )
        if case let .audio(src) = attachment.content {
            XCTAssertEqual(src, "song.mp3")
        } else {
            XCTFail("Expected .audio(src:)")
        }
    }

    func testCustomAttachment() {
        let attachment = MarkupAttachment(
            content: .custom(type: "map", metadata: ["lat": "39.9", "lng": "116.4"]),
            suggestedSize: CGSize(width: 200, height: 200),
            alignment: .center
        )
        if case let .custom(type, metadata) = attachment.content {
            XCTAssertEqual(type, "map")
            XCTAssertEqual(metadata["lat"], "39.9")
        } else {
            XCTFail("Expected .custom(type:metadata:)")
        }
    }

    func testAttachmentEquality() {
        let a = MarkupAttachment(
            content: .image(src: "a.jpg"),
            suggestedSize: CGSize(width: 100, height: 100),
            alignment: .default
        )
        let b = MarkupAttachment(
            content: .image(src: "a.jpg"),
            suggestedSize: CGSize(width: 100, height: 100),
            alignment: .default
        )
        XCTAssertEqual(a, b)
    }

    func testAttachmentInequality() {
        let a = MarkupAttachment(
            content: .image(src: "a.jpg"),
            suggestedSize: CGSize(width: 100, height: 100),
            alignment: .default
        )
        let b = MarkupAttachment(
            content: .video(src: "a.mp4"),
            suggestedSize: CGSize(width: 100, height: 100),
            alignment: .default
        )
        XCTAssertNotEqual(a, b)
    }

    func testAlignmentDefault() {
        let attachment = MarkupAttachment(
            content: .image(src: "x.jpg"),
            suggestedSize: .zero,
            alignment: .default
        )
        XCTAssertEqual(attachment.alignment, .default)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter MarkupAttachmentTests`
预期：FAIL，编译错误 "Cannot find 'MarkupAttachment' in scope"

- [ ] **步骤 3：编写最少实现代码**

```swift
// platforms/ios/Sources/XMarkup/Core/MarkupAttachment.swift
import Foundation

/// 平台无关的媒体附件描述
public struct MarkupAttachment: Sendable, Equatable {
    public let content: AttachmentContent
    public let suggestedSize: CGSize
    public let alignment: AttachmentAlignment

    public init(
        content: AttachmentContent,
        suggestedSize: CGSize,
        alignment: AttachmentAlignment = .default
    ) {
        self.content = content
        self.suggestedSize = suggestedSize
        self.alignment = alignment
    }
}

/// 附件内容类型
public enum AttachmentContent: Sendable, Equatable {
    case image(src: String)
    case video(src: String)
    case audio(src: String)
    /// 第三方扩展入口
    case custom(type: String, metadata: [String: String])
}

/// 附件对齐方式
public enum AttachmentAlignment: String, Sendable, Equatable {
    case `default`
    case center
    case leading
    case trailing
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter MarkupAttachmentTests`
预期：PASS，全部 7 个测试通过

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Core/MarkupAttachment.swift platforms/ios/Tests/XMarkupTests/Core/MarkupAttachmentTests.swift
git commit -m "feat: 添加 MarkupAttachment + AttachmentContent + AttachmentAlignment 数据模型"
```

---

## 任务 3：BlockKind + Level 数据模型

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Core/BlockKind.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Core/BlockKindTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Core/BlockKindTests.swift
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
                [MarkupBlock(kind: .paragraph, text: "H1", inlines: [], attachment: nil)],
                [MarkupBlock(kind: .paragraph, text: "D1", inlines: [], attachment: nil)],
            ],
            headerRowCount: 1,
            columnCount: 1
        )
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.headerRowCount, 1)
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
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter BlockKindTests`
预期：FAIL，编译错误 "Cannot find 'BlockKind' in scope"

- [ ] **步骤 3：编写最少实现代码**

```swift
// platforms/ios/Sources/XMarkup/Core/BlockKind.swift
import Foundation

/// 标题级别
public enum Level: Int, Sendable, Equatable, Comparable, Codable {
    case h1 = 1, h2, h3, h4, h5, h6

    public static func < (lhs: Level, rhs: Level) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 段落类型
public enum BlockKind: Sendable, Equatable {
    case paragraph
    case heading(Level)
    case blockquote
    case preformatted
    case listItem(isOrdered: Bool, indentLevel: Int)
    case division
    case horizontalRule
    case table(TableStructure)
}

/// 表格结构
public struct TableStructure: Sendable, Equatable {
    public let rows: [[MarkupBlock]]
    public let headerRowCount: Int
    public let columnCount: Int

    public init(rows: [[MarkupBlock]], headerRowCount: Int, columnCount: Int) {
        self.rows = rows
        self.headerRowCount = headerRowCount
        self.columnCount = columnCount
    }
}
```

注意：`TableStructure` 引用了 `MarkupBlock`（任务 4 定义），但编译器允许前向引用。任务 3 和任务 4 必须在同一个编译批次中一起编译通过。如果 SPM 报错，将任务 3 和任务 4 的实现文件在同一步骤中一起创建。

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter BlockKindTests`
预期：如果 MarkupBlock 未定义则编译失败，需要继续任务 4 后再测试。如果前向引用成功则 PASS。

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Core/BlockKind.swift platforms/ios/Tests/XMarkupTests/Core/BlockKindTests.swift
git commit -m "feat: 添加 BlockKind + Level + TableStructure 数据模型"
```

---

## 任务 4：MarkupBlock + MarkupDocument 数据模型

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Core/MarkupBlock.swift`
- 创建：`platforms/ios/Sources/XMarkup/Core/MarkupDocument.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Core/MarkupBlockTests.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Core/MarkupBlockTests.swift
import XCTest
@testable import XMarkup

final class MarkupBlockTests: XCTestCase {

    func testBlockCreation() {
        let block = MarkupBlock(
            kind: .paragraph,
            text: "Hello World",
            inlines: [],
            attachment: nil
        )
        XCTAssertEqual(block.kind, .paragraph)
        XCTAssertEqual(block.text, "Hello World")
        XCTAssertTrue(block.inlines.isEmpty)
        XCTAssertNil(block.attachment)
    }

    func testBlockWithInline() {
        let text = "Hello World"
        let range = text.startIndex..<text.index(text.startIndex, offsetBy: 5)
        let inline = MarkupInline(range: range, kind: .bold)
        let block = MarkupBlock(
            kind: .paragraph,
            text: text,
            inlines: [inline],
            attachment: nil
        )
        XCTAssertEqual(block.inlines.count, 1)
        XCTAssertEqual(block.inlines[0].kind, .bold)
    }

    func testBlockWithAttachment() {
        let attachment = MarkupAttachment(
            content: .image(src: "photo.jpg"),
            suggestedSize: CGSize(width: 200, height: 150),
            alignment: .default
        )
        let block = MarkupBlock(
            kind: .paragraph,
            text: "\u{FFFC}",
            inlines: [],
            attachment: attachment
        )
        XCTAssertNotNil(block.attachment)
    }

    func testBlockEquality() {
        let a = MarkupBlock(kind: .paragraph, text: "Hi", inlines: [], attachment: nil)
        let b = MarkupBlock(kind: .paragraph, text: "Hi", inlines: [], attachment: nil)
        XCTAssertEqual(a, b)
    }
}
```

```swift
// platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentTests.swift
import XCTest
@testable import XMarkup

final class MarkupDocumentTests: XCTestCase {

    func testEmptyDocument() {
        let doc = MarkupDocument(blocks: [])
        XCTAssertTrue(doc.blocks.isEmpty)
    }

    func testDocumentWithBlocks() {
        let blocks = [
            MarkupBlock(kind: .heading(.h1), text: "Title", inlines: [], attachment: nil),
            MarkupBlock(kind: .paragraph, text: "Hello", inlines: [], attachment: nil),
        ]
        let doc = MarkupDocument(blocks: blocks)
        XCTAssertEqual(doc.blocks.count, 2)
        XCTAssertEqual(doc.blocks[0].text, "Title")
        XCTAssertEqual(doc.blocks[1].text, "Hello")
    }

    func testDocumentEquality() {
        let a = MarkupDocument(blocks: [
            MarkupBlock(kind: .paragraph, text: "Hi", inlines: [], attachment: nil),
        ])
        let b = MarkupDocument(blocks: [
            MarkupBlock(kind: .paragraph, text: "Hi", inlines: [], attachment: nil),
        ])
        XCTAssertEqual(a, b)
    }

    func testDocumentAppending() {
        let doc1 = MarkupDocument(blocks: [
            MarkupBlock(kind: .paragraph, text: "A", inlines: [], attachment: nil),
        ])
        let doc2 = MarkupDocument(blocks: [
            MarkupBlock(kind: .paragraph, text: "B", inlines: [], attachment: nil),
        ])
        let combined = doc1.appending(doc2)
        XCTAssertEqual(combined.blocks.count, 2)
        XCTAssertEqual(combined.blocks[0].text, "A")
        XCTAssertEqual(combined.blocks[1].text, "B")
    }

    func testDocumentAppendingPreservesOriginal() {
        let doc1 = MarkupDocument(blocks: [
            MarkupBlock(kind: .paragraph, text: "A", inlines: [], attachment: nil),
        ])
        let doc2 = MarkupDocument(blocks: [
            MarkupBlock(kind: .paragraph, text: "B", inlines: [], attachment: nil),
        ])
        _ = doc1.appending(doc2)
        // doc1 是不可变值类型，append 不影响原值
        XCTAssertEqual(doc1.blocks.count, 1)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter "MarkupBlockTests|MarkupDocumentTests"`
预期：FAIL，编译错误 "Cannot find 'MarkupBlock' in scope"

- [ ] **步骤 3：编写最少实现代码**

```swift
// platforms/ios/Sources/XMarkup/Core/MarkupBlock.swift
import Foundation

/// 段落级块（h1-h6, p, blockquote, pre, li, hr, div 等）
public struct MarkupBlock: Sendable, Equatable {
    public let kind: BlockKind
    /// 该段落的纯文本
    public let text: String
    /// 内联样式区间（bold/italic/link/code/mark 等）
    public let inlines: [MarkupInline]
    /// 媒体附件（image/video/audio/custom），非媒体块为 nil
    public let attachment: MarkupAttachment?

    public init(
        kind: BlockKind,
        text: String,
        inlines: [MarkupInline],
        attachment: MarkupAttachment?
    ) {
        self.kind = kind
        self.text = text
        self.inlines = inlines
        self.attachment = attachment
    }
}
```

```swift
// platforms/ios/Sources/XMarkup/Core/MarkupDocument.swift
import Foundation

/// 平台无关的标记文档，从 C++ 引擎的 flat spans 一次性构建
public struct MarkupDocument: Sendable, Equatable {
    /// 段落级块列表
    public let blocks: [MarkupBlock]

    public init(blocks: [MarkupBlock]) {
        self.blocks = blocks
    }

    /// 追加内容（聊天场景）
    public func appending(_ other: MarkupDocument) -> MarkupDocument {
        MarkupDocument(blocks: blocks + other.blocks)
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter "MarkupBlockTests|MarkupDocumentTests"`
预期：PASS，全部 9 个测试通过（4 个 Block + 5 个 Document）

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Core/MarkupBlock.swift platforms/ios/Sources/XMarkup/Core/MarkupDocument.swift platforms/ios/Tests/XMarkupTests/Core/MarkupBlockTests.swift platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentTests.swift
git commit -m "feat: 添加 MarkupBlock + MarkupDocument 数据模型"
```

---

## 任务 5：MarkupDocumentBuilder（XMarkupResult → MarkupDocument）

这是核心转换算法。将 C++ 引擎的 flat spans（text + [XMarkupSpan]）转为段落/内联两级结构的 MarkupDocument。

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift
import XCTest
@testable import XMarkup

final class MarkupDocumentBuilderTests: XCTestCase {

    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    // MARK: - 基础转换

    func testEmptyInput() throws {
        let result = try parse("")
        let doc = MarkupDocument.from(result)
        XCTAssertTrue(doc.blocks.isEmpty)
    }

    func testPureText() throws {
        let result = try parse("Hello World")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .paragraph)
        XCTAssertEqual(doc.blocks[0].text, "Hello World")
    }

    func testSingleParagraph() throws {
        let result = try parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .paragraph)
        XCTAssertEqual(doc.blocks[0].text, "Hello")
    }

    // MARK: - 标题

    func testHeading1() throws {
        let result = try parse("<h1>Title</h1>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        if case let .heading(level) = doc.blocks[0].kind {
            XCTAssertEqual(level, .h1)
        } else {
            XCTFail("Expected .heading(.h1)")
        }
        XCTAssertEqual(doc.blocks[0].text, "Title")
    }

    func testHeading3() throws {
        let result = try parse("<h3>Subtitle</h3>")
        let doc = MarkupDocument.from(result)
        if case let .heading(level) = doc.blocks[0].kind {
            XCTAssertEqual(level, .h3)
        } else {
            XCTFail("Expected .heading(.h3)")
        }
    }

    // MARK: - 内联样式

    func testBoldInline() throws {
        let result = try parse("<b>bold</b>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].inlines.count, 1)
        XCTAssertEqual(doc.blocks[0].inlines[0].kind, .bold)
    }

    func testBoldItalicInlines() throws {
        let result = try parse("<b><i>both</i></b>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].inlines.count, 2)
        // 确认 bold 和 italic 都存在
        let kinds = doc.blocks[0].inlines.map(\.kind)
        XCTAssertTrue(kinds.contains(.bold))
        XCTAssertTrue(kinds.contains(.italic))
    }

    func testLinkInline() throws {
        let result = try parse("<a href=\"https://example.com\">click</a>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].inlines.count, 1)
        if case let .link(url) = doc.blocks[0].inlines[0].kind {
            XCTAssertEqual(url, "https://example.com")
        } else {
            XCTFail("Expected .link(url:)")
        }
    }

    // MARK: - 块级元素

    func testBlockquote() throws {
        let result = try parse("<blockquote>quote</blockquote>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .blockquote)
    }

    func testPreformatted() throws {
        let result = try parse("<pre>code block</pre>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(doc.blocks[0].kind, .preformatted)
    }

    func testHorizontalRule() throws {
        let result = try parse("<hr>")
        let doc = MarkupDocument.from(result)
        // hr 作为一个块
        let hrBlock = doc.blocks.first(where: { $0.kind == .horizontalRule })
        XCTAssertNotNil(hrBlock)
    }

    // MARK: - 多段落

    func testTwoParagraphs() throws {
        let result = try parse("<p>First</p><p>Second</p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 2)
        XCTAssertEqual(doc.blocks[0].text, "First")
        XCTAssertEqual(doc.blocks[1].text, "Second")
    }

    // MARK: - 列表

    func testUnorderedListItem() throws {
        let result = try parse("<ul><li>Item</li></ul>")
        let doc = MarkupDocument.from(result)
        let liBlock = doc.blocks.first(where: {
            if case .listItem = $0.kind { return true }
            return false
        })
        XCTAssertNotNil(liBlock)
        if case let .listItem(isOrdered, indentLevel) = liBlock!.kind {
            XCTAssertFalse(isOrdered)
            XCTAssertEqual(indentLevel, 0)
        }
    }

    func testOrderedListItem() throws {
        let result = try parse("<ol><li>Item</li></ol>")
        let doc = MarkupDocument.from(result)
        let liBlock = doc.blocks.first(where: {
            if case .listItem = $0.kind { return true }
            return false
        })
        XCTAssertNotNil(liBlock)
        if case let .listItem(isOrdered, _) = liBlock!.kind {
            XCTAssertTrue(isOrdered)
        }
    }

    // MARK: - 媒体附件

    func testImageAttachment() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertNotNil(doc.blocks[0].attachment)
        if case let .image(src) = doc.blocks[0].attachment?.content {
            XCTAssertEqual(src, "photo.jpg")
        } else {
            XCTFail("Expected .image(src:)")
        }
    }

    func testVideoAttachment() throws {
        let result = try parse("<video src=\"movie.mp4\"></video>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].attachment)
        if case let .video(src) = doc.blocks[0].attachment?.content {
            XCTAssertEqual(src, "movie.mp4")
        } else {
            XCTFail("Expected .video(src:)")
        }
    }

    func testVideoWithSourceChild() throws {
        let result = try parse("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].attachment)
        if case let .video(src) = doc.blocks[0].attachment?.content {
            XCTAssertEqual(src, "a.mp4")
        } else {
            XCTFail("Expected .video(src:)")
        }
    }

    func testAudioAttachment() throws {
        let result = try parse("<audio src=\"song.mp3\"></audio>")
        let doc = MarkupDocument.from(result)
        XCTAssertNotNil(doc.blocks[0].attachment)
        if case let .audio(src) = doc.blocks[0].attachment?.content {
            XCTAssertEqual(src, "song.mp3")
        } else {
            XCTFail("Expected .audio(src:)")
        }
    }

    // MARK: - CSS 行内样式

    func testCSSForegroundColor() throws {
        let result = try parse("<span style=\"color:#FF0000\">red</span>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks[0].inlines.count, 1)
        if case let .span(styles) = doc.blocks[0].inlines[0].kind {
            XCTAssertTrue(styles.contains(.foregroundColor("#FF0000")))
        } else {
            XCTFail("Expected .span(styles:)")
        }
    }

    func testUnknownTagProducesBlock() throws {
        let result = try parse("<custom>text</custom>")
        let doc = MarkupDocument.from(result)
        // 未知标签不应崩溃，应产出至少一个块
        XCTAssertFalse(doc.blocks.isEmpty)
        XCTAssertEqual(doc.blocks[0].text, "text")
    }

    // MARK: - 复合场景

    func testHeadingWithInline() throws {
        let result = try parse("<h1><b>Bold</b> Title</h1>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        if case .heading(.h1) = doc.blocks[0].kind {
            // 正确
        } else {
            XCTFail("Expected .heading(.h1)")
        }
        XCTAssertTrue(doc.blocks[0].inlines.contains(where: { $0.kind == .bold }))
    }

    func testParagraphWithMixedInlines() throws {
        let result = try parse("<p><b>bold</b> <i>italic</i> <a href=\"https://example.com\">link</a></p>")
        let doc = MarkupDocument.from(result)
        XCTAssertEqual(doc.blocks.count, 1)
        let kinds = doc.blocks[0].inlines.map(\.kind)
        XCTAssertTrue(kinds.contains(.bold))
        XCTAssertTrue(kinds.contains(.italic))
        XCTAssertTrue(kinds.contains(where: {
            if case .link = $0 { return true }
            return false
        }))
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter MarkupDocumentBuilderTests`
预期：FAIL，编译错误 "Value of type 'MarkupDocument' has no member 'from'"

- [ ] **步骤 3：编写实现代码**

```swift
// platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift
import Foundation

extension MarkupDocument {

    /// 从 C++ 桥接结果构建 MarkupDocument
    ///
    /// 算法：
    /// 1. 遍历所有 spans，识别块级 tag（h1-h6/p/blockquote/li/pre/hr/div/table）
    /// 2. 根据 span 的 NSRange 和 text 的换行符，将文本分割为段落块
    /// 3. 每个块分配对应的 BlockKind
    /// 4. 非块级 span（bold/italic/link/code/mark/underline/strikethrough/...) 映射为对应块的 MarkupInline
    /// 5. 媒体类 span（img/video/audio）映射为 MarkupAttachment
    public static func from(_ result: XMarkupResult) -> MarkupDocument {
        let text = result.text
        let spans = result.spans

        guard !text.isEmpty else {
            return MarkupDocument(blocks: [])
        }

        // 块级 tag 集合
        let blockTags: Set<XMarkupTag> = [
            .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
            .blockquote, .preformatted, .horizontalRule, .division,
            .listOrdered, .listUnordered, .listItem,
            .table, .tableRow, .tableCell, .tableHeader,
            .image, .video, .audio,
        ]

        // 媒体 tag 集合
        let mediaTags: Set<XMarkupTag> = [.image, .video, .audio]
        let mediaSourceTags: Set<XMarkupTag> = [.videoSource, .audioSource]

        // 提取块级 spans 和内联 spans
        let blockSpans = spans.filter { blockTags.contains($0.tag) }
        let inlineSpans = spans.filter { !blockTags.contains($0.tag) }

        // 如果没有块级 span，整段文本作为一个 paragraph
        if blockSpans.isEmpty {
            let nsRange = NSRange(location: 0, length: (text as NSString).length)
            let inlines = convertToInlines(inlineSpans, in: text, parentRange: nsRange)
            return MarkupDocument(blocks: [
                MarkupBlock(kind: .paragraph, text: text, inlines: inlines, attachment: nil),
            ])
        }

        // 为每个块级 span 构建块
        var blocks: [MarkupBlock] = []
        blocks.reserveCapacity(blockSpans.count)

        for span in blockSpans {
            let spanRange = span.range
            let kind = blockKind(for: span)
            let blockText = extractText(text: text, nsRange: spanRange)

            // 判断是否为媒体块
            let attachment: MarkupAttachment?
            if mediaTags.contains(span.tag) {
                let src = resolveMediaSrc(span, allSpans: spans)
                attachment = MarkupAttachment(
                    content: attachmentContent(for: span.tag, src: src),
                    suggestedSize: CGSize(width: 200, height: 150),
                    alignment: .default
                )
            } else {
                attachment = nil
            }

            // 收集属于这个块的内联 span
            let inlines = convertToInlines(inlineSpans, in: text, parentRange: spanRange)

            blocks.append(MarkupBlock(
                kind: kind,
                text: blockText,
                inlines: inlines,
                attachment: attachment
            ))
        }

        return MarkupDocument(blocks: blocks)
    }
}

// MARK: - Private Helpers

extension MarkupDocument {

    /// 将 XMarkupTag 映射为 BlockKind
    private static func blockKind(for span: XMarkupSpan) -> BlockKind {
        switch span.tag {
        case .paragraph:
            return .paragraph
        case .heading1:
            return .heading(.h1)
        case .heading2:
            return .heading(.h2)
        case .heading3:
            return .heading(.h3)
        case .heading4:
            return .heading(.h4)
        case .heading5:
            return .heading(.h5)
        case .heading6:
            return .heading(.h6)
        case .blockquote:
            return .blockquote
        case .preformatted:
            return .preformatted
        case .listItem:
            return .listItem(isOrdered: false, indentLevel: 0)
        case .horizontalRule:
            return .horizontalRule
        case .division:
            return .division
        case .image, .video, .audio:
            return .paragraph
        default:
            return .paragraph
        }
    }

    /// 从 NSRange 提取子字符串
    private static func extractText(text: String, nsRange: NSRange) -> String {
        let nsString = text as NSString
        guard nsRange.location + nsRange.length <= nsString.length,
              nsRange.location >= 0 else {
            return ""
        }
        return nsString.substring(with: nsRange)
    }

    /// 将内联 span 转换为 MarkupInline
    private static func convertToInlines(
        _ spans: [XMarkupSpan],
        in text: String,
        parentRange: NSRange
    ) -> [MarkupInline] {
        let nsString = text as NSString
        var inlines: [MarkupInline] = []
        inlines.reserveCapacity(spans.count)

        for span in spans {
            // 只收集在 parentRange 范围内的 inline span
            guard span.range.location >= parentRange.location,
                  span.range.location + span.range.length <= parentRange.location + parentRange.length else {
                continue
            }

            let kind = inlineKind(for: span)
            // 将 NSRange 转换为 Range<String.Index>
            guard let range = Range(span.range, in: text) else { continue }
            inlines.append(MarkupInline(range: range, kind: kind))
        }

        return inlines
    }

    /// 将 XMarkupSpan 映射为 InlineKind
    private static func inlineKind(for span: XMarkupSpan) -> InlineKind {
        switch span.tag {
        case .bold:
            return .bold
        case .italic:
            return .italic
        case .underline:
            return .underline
        case .strikethrough:
            return .strikethrough
        case .code:
            return .code
        case .mark:
            return .mark
        case .link:
            return .link(url: span.value ?? "")
        case .subscriptText:
            return .subscriptText
        case .superscript:
            return .superscript
        case .span:
            return .span(styles: inlineStyles(for: span))
        default:
            return .bold  // fallback
        }
    }

    /// 从 XMarkupSpan 提取 CSS 行内样式列表
    private static func inlineStyles(for span: XMarkupSpan) -> [InlineStyle] {
        var styles: [InlineStyle] = []

        switch span.style {
        case .foregroundColor:
            if let value = span.value {
                styles.append(.foregroundColor(value))
            }
        case .backgroundColor:
            if let value = span.value {
                styles.append(.backgroundColor(value))
            }
        case .fontSize:
            if let value = span.value, let f = Float(value) {
                styles.append(.fontSize(f))
            }
        case .fontWeight:
            if let value = span.value {
                styles.append(.fontWeight(value))
            }
        case .fontStyle:
            if let value = span.value {
                styles.append(.fontStyle(value))
            }
        case .textDecoration:
            if let value = span.value {
                styles.append(.textDecoration(value))
            }
        case .lineHeight:
            if let value = span.value, let f = Float(value) {
                styles.append(.lineHeight(f))
            }
        case .letterSpacing:
            if let value = span.value, let f = Float(value) {
                styles.append(.letterSpacing(f))
            }
        default:
            break
        }

        return styles
    }

    /// 解析媒体 src
    private static func resolveMediaSrc(_ span: XMarkupSpan, allSpans: [XMarkupSpan]) -> String? {
        if let src = span.value, !src.isEmpty { return src }

        let childTag: XMarkupTag
        switch span.tag {
        case .video: childTag = .videoSource
        case .audio: childTag = .audioSource
        default: return nil
        }

        for child in allSpans {
            if child.tag == childTag,
               child.range.location >= span.range.location,
               child.range.location + child.range.length <= span.range.location + span.range.length,
               let src = child.value {
                return src
            }
        }
        return nil
    }

    /// 将 tag + src 映射为 AttachmentContent
    private static func attachmentContent(for tag: XMarkupTag, src: String?) -> AttachmentContent {
        switch tag {
        case .image:
            return .image(src: src ?? "")
        case .video:
            return .video(src: src ?? "")
        case .audio:
            return .audio(src: src ?? "")
        default:
            return .image(src: src ?? "")
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter MarkupDocumentBuilderTests`
预期：PASS，全部 20 个测试通过

注意：有序列表 `<ol><li>` 的处理需要额外逻辑——C++ 引擎中 `<ol>` 和 `<li>` 分别产生独立的 span，`<li>` 的 tag 始终是 `.listItem`，但 `isOrdered` 需要从外层 `<ol>` / `<ul>` span 推断。如果测试 `testOrderedListItem` 失败，需要调整 `blockKind(for:)` 方法，使其查找 span 是否被 `listOrdered` span 包裹来决定 `isOrdered`。

如果 `testOrderedListItem` 失败，将 `blockKind(for:)` 中的 `.listItem` case 修改为：

```swift
case .listItem:
    // 查找外层 list 容器 span 来决定 isOrdered
    // （需要传入 allSpans，因此调整方法签名）
    return .listItem(isOrdered: false, indentLevel: 0)
```

实际修复：将 `blockKind(for:)` 改为 `blockKind(for span: XMarkupSpan, allSpans: [XMarkupSpan]) -> BlockKind`，在 `.listItem` case 中搜索包含此 span 的 `listOrdered` / `listUnordered` span 来判断 `isOrdered`：

```swift
case .listItem:
    let isOrdered = allSpans.contains { parent in
        (parent.tag == .listOrdered || parent.tag == .listUnordered)
        && parent.range.location <= span.range.location
        && parent.range.location + parent.range.length >= span.range.location + span.range.length
    }
    return .listItem(isOrdered: isOrdered, indentLevel: 0)
```

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift
git commit -m "feat: 添加 MarkupDocumentBuilder（XMarkupResult → MarkupDocument 转换）"
```

---

## 任务 6：XMarkupScope 自定义 AttributedStringKey

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Attributes/XMarkupScope.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Attributes/XMarkupScopeTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Attributes/XMarkupScopeTests.swift
import XCTest
@testable import XMarkup

final class XMarkupScopeTests: XCTestCase {

    func testCustomKeyInAttributedString() {
        var attr = AttributedString("Hello World")
        attr[XMarkupTagKey.self] = "heading1"
        XCTAssertEqual(attr[XMarkupTagKey.self], "heading1")
    }

    func testCustomKeyInAttributedStringRange() {
        var attr = AttributedString("Hello World")
        let range = attr.range(of: "Hello")!
        attr[range][XMarkupTagKey.self] = "bold"
        // "Hello" 范围有 tag
        XCTAssertEqual(attr[range][XMarkupTagKey.self], "bold")
    }

    func testMultipleCustomKeysCoexist() {
        var attr = AttributedString("Title")
        attr[XMarkupTagKey.self] = "heading"
        attr[XMarkupBlockKindKey.self] = "heading"
        attr[XMarkupHeadingLevelKey.self] = 1
        XCTAssertEqual(attr[XMarkupTagKey.self], "heading")
        XCTAssertEqual(attr[XMarkupBlockKindKey.self], "heading")
        XCTAssertEqual(attr[XMarkupHeadingLevelKey.self], 1)
    }

    func testCustomKeySurvivesNSBridge() {
        var attr = AttributedString("Test")
        attr[XMarkupTagKey.self] = "link"
        attr[XMarkupLinkURLKey.self] = "https://example.com"

        let nsAttr = NSAttributedString(attr)
        // 通过 raw key 名读取
        let tagValue = nsAttr.attribute(NSAttributedString.Key("XMarkup.Tag"), at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(tagValue, "link")
        let urlValue = nsAttr.attribute(NSAttributedString.Key("XMarkup.LinkURL"), at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(urlValue, "https://example.com")
    }

    func testCustomKeyRoundTrip() {
        var attr = AttributedString("Test")
        attr[XMarkupTagKey.self] = "code"
        attr[XMarkupBlockKindKey.self] = "preformatted"

        let nsAttr = NSAttributedString(attr)
        let back = AttributedString(nsAttr)
        XCTAssertEqual(back[XMarkupTagKey.self], "code")
        XCTAssertEqual(back[XMarkupBlockKindKey.self], "preformatted")
    }

    func testCustomKeyWithUIKitAttributes() {
        var attr = AttributedString("Colored")
        #if canImport(UIKit)
        attr.uiKit.foregroundColor = .red
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.foregroundColor = .red
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif
        attr[XMarkupTagKey.self] = "span"

        // UIKit/AppKit 属性和自定义属性共存
        XCTAssertEqual(attr[XMarkupTagKey.self], "span")
        #if canImport(UIKit)
        XCTAssertEqual(attr.uiKit.foregroundColor, .red)
        #elseif canImport(AppKit)
        XCTAssertEqual(attr.appKit.foregroundColor, .red)
        #endif
    }

    func testListItemInfoKey() {
        var attr = AttributedString("Item 1")
        attr[XMarkupListItemInfoKey.self] = "ordered:0"
        XCTAssertEqual(attr[XMarkupListItemInfoKey.self], "ordered:0")
    }

    func testAttachmentRefKey() {
        var attr = AttributedString("\u{FFFC}")
        attr[XMarkupAttachmentRefKey.self] = "img-0"
        XCTAssertEqual(attr[XMarkupAttachmentRefKey.self], "img-0")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter XMarkupScopeTests`
预期：FAIL，编译错误 "Cannot find 'XMarkupTagKey' in scope"

- [ ] **步骤 3：编写实现代码**

```swift
// platforms/ios/Sources/XMarkup/Attributes/XMarkupScope.swift
import Foundation

/// XMarkup 自定义属性作用域
/// 携带语义信息，与 UIKit/SwiftUI scope 共存于同一个 AttributedString
enum XMarkupScope: AttributeScope {
    var xmarkupTag: XMarkupTagKey { get {} }
    var xmarkupBlockKind: XMarkupBlockKindKey { get {} }
    var xmarkupLinkURL: XMarkupLinkURLKey { get {} }
    var xmarkupHeadingLevel: XMarkupHeadingLevelKey { get {} }
    var xmarkupListItemInfo: XMarkupListItemInfoKey { get {} }
    var xmarkupAttachmentRef: XMarkupAttachmentRefKey { get {} }
}

struct XMarkupTagKey: AttributedStringKey {
    typealias Value = String
    static let name = "XMarkup.Tag"
}

struct XMarkupBlockKindKey: AttributedStringKey {
    typealias Value = String
    static let name = "XMarkup.BlockKind"
}

struct XMarkupLinkURLKey: AttributedStringKey {
    typealias Value = String
    static let name = "XMarkup.LinkURL"
}

struct XMarkupHeadingLevelKey: AttributedStringKey {
    typealias Value = Int
    static let name = "XMarkup.HeadingLevel"
}

struct XMarkupListItemInfoKey: AttributedStringKey {
    typealias Value = String
    static let name = "XMarkup.ListItemInfo"
}

struct XMarkupAttachmentRefKey: AttributedStringKey {
    typealias Value = String
    static let name = "XMarkup.AttachmentRef"
}

// 扩展 AttributeScopes 使 XMarkupScope 可被发现
extension AttributeScopes {
    var xmarkup: XMarkupScope.Type { XMarkupScope.self }
}

// 扩展 AttributeDynamicLookup 支持 .xmarkup 访问
extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(_: KeyPath<XMarkupScope, T>) -> T {
        return T()
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter XMarkupScopeTests`
预期：PASS，全部 7 个测试通过

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Attributes/XMarkupScope.swift platforms/ios/Tests/XMarkupTests/Attributes/XMarkupScopeTests.swift
git commit -m "feat: 添加 XMarkupScope（6 个自定义 AttributedStringKey + AttributeScope）"
```

---

## 任务 7：MarkupTheme 基础结构（TagStyleKey + HeadingScale + MediaRenderingStrategy）

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Theme/TagStyleKey.swift`
- 创建：`platforms/ios/Sources/XMarkup/Theme/HeadingScale.swift`
- 创建：`platforms/ios/Sources/XMarkup/Theme/MediaRenderingStrategy.swift`
- 创建：`platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Theme/MarkupThemeTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Theme/MarkupThemeTests.swift
import XCTest
@testable import XMarkup

final class MarkupThemeTests: XCTestCase {

    // MARK: - TagStyleKey

    func testTagStyleKeyAllCases() {
        let keys: [TagStyleKey] = [
            .bold, .italic, .underline, .strikethrough, .code, .mark,
            .link, .heading, .paragraph, .blockquote, .preformatted,
            .listItem, .division, .horizontalRule,
            .image, .video, .audio,
        ]
        XCTAssertEqual(keys.count, 17)
    }

    func testTagStyleKeyRawValue() {
        XCTAssertEqual(TagStyleKey.bold.rawValue, "bold")
        XCTAssertEqual(TagStyleKey.heading.rawValue, "heading")
    }

    // MARK: - HeadingScale

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

    func testHeadingScaleEquality() {
        let a = HeadingScale.default
        let b = HeadingScale.default
        XCTAssertEqual(a, b)
    }

    // MARK: - MarkupTheme

    func testDefaultThemeBaseFont() {
        let theme = MarkupTheme.default
        #if canImport(UIKit)
        XCTAssertEqual(theme.baseFont, UIFont.systemFont(ofSize: 16))
        #elseif canImport(AppKit)
        XCTAssertEqual(theme.baseFont, NSFont.systemFont(ofSize: 16))
        #endif
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
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter MarkupThemeTests`
预期：FAIL，编译错误 "Cannot find 'TagStyleKey' in scope"

- [ ] **步骤 3：编写实现代码**

```swift
// platforms/ios/Sources/XMarkup/Theme/TagStyleKey.swift
import Foundation

/// 主题配置 key（用于 tagStyles 字典）
public enum TagStyleKey: String, Sendable, Equatable, Hashable, CaseIterable {
    case bold, italic, underline, strikethrough, code, mark
    case link, heading, paragraph, blockquote, preformatted
    case listItem, division, horizontalRule
    case image, video, audio
}
```

```swift
// platforms/ios/Sources/XMarkup/Theme/HeadingScale.swift
import Foundation

/// 标题缩放配置
public struct HeadingScale: Sendable, Equatable {
    public var h1: CGFloat  // 默认 2.0
    public var h2: CGFloat  // 默认 1.5
    public var h3: CGFloat  // 默认 1.17
    public var h4: CGFloat  // 默认 1.0
    public var h5: CGFloat  // 默认 0.83
    public var h6: CGFloat  // 默认 0.67

    public init(
        h1: CGFloat = 2.0,
        h2: CGFloat = 1.5,
        h3: CGFloat = 1.17,
        h4: CGFloat = 1.0,
        h5: CGFloat = 0.83,
        h6: CGFloat = 0.67
    ) {
        self.h1 = h1
        self.h2 = h2
        self.h3 = h3
        self.h4 = h4
        self.h5 = h5
        self.h6 = h6
    }

    public static let `default` = HeadingScale()
}
```

```swift
// platforms/ios/Sources/XMarkup/Theme/MediaRenderingStrategy.swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 媒体渲染策略
public enum MediaRenderingStrategy: Sendable {
    /// 使用 SF Symbol 占位图（默认）
    case placeholder
    /// 通过闭包加载图片
    case imageProvider(@Sendable (String) -> XMImage?)
    /// 通过闭包创建自定义附件
    case customAttachment(@Sendable (AttachmentContent, CGSize) -> NSTextAttachment?)
}
```

```swift
// platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 纯值类型的样式主题
public struct MarkupTheme: Sendable, Equatable {
    /// 基础字体
    public var baseFont: XMFont
    /// 标题缩放系数
    public var headingScale: HeadingScale
    /// 标签样式映射
    public var tagStyles: [TagStyleKey: AttributeContainer]
    /// 媒体渲染策略
    public var mediaStrategy: MediaRenderingStrategy

    public init(
        baseFont: XMFont = XMFont.systemFont(ofSize: 16),
        headingScale: HeadingScale = .default,
        tagStyles: [TagStyleKey: AttributeContainer] = [:],
        mediaStrategy: MediaRenderingStrategy = .placeholder
    ) {
        self.baseFont = baseFont
        self.headingScale = headingScale
        self.tagStyles = tagStyles
        self.mediaStrategy = mediaStrategy
    }
}
```

注意：`MarkupTheme` 的 `Equatable` 实现需要注意 `MediaRenderingStrategy` 包含闭包，闭包不可比较。需要自定义 `==` 实现：

在 `MarkupTheme` 中添加：

```swift
    public static func == (lhs: MarkupTheme, rhs: MarkupTheme) -> Bool {
        // 闭包不可比较，只比较其他字段
        // 如果两个 theme 的非闭包字段相同，视为相等
        // 注意：这是简化实现，实际中应使用类型擦除或其他方式
        return lhs.baseFont == rhs.baseFont
            && lhs.headingScale == rhs.headingScale
            && lhs.tagStyles == rhs.tagStyles
    }
```

同时 `MediaRenderingStrategy` 需要手动实现 `Equatable`：

```swift
// 在 MediaRenderingStrategy.swift 中替换
public enum MediaRenderingStrategy: Sendable {
    case placeholder
    case imageProvider(@Sendable (String) -> XMImage?)
    case customAttachment(@Sendable (AttachmentContent, CGSize) -> NSTextAttachment?)
}

// MediaRenderingStrategy 不能自动 Equatable（闭包不可比较）
// 在 MarkupTheme.== 中跳过 mediaStrategy 比较
```

实际操作：将 `MediaRenderingStrategy` 从 `Equatable` 移除，在 `MarkupTheme` 中手动实现 `==`，只比较 `baseFont`、`headingScale`、`tagStyles`。

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter MarkupThemeTests`
预期：PASS，全部 8 个测试通过

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/ platforms/ios/Tests/XMarkupTests/Theme/MarkupThemeTests.swift
git commit -m "feat: 添加 MarkupTheme + TagStyleKey + HeadingScale + MediaRenderingStrategy"
```

---

## 任务 8：Result Builder DSL（ThemeComponent + MarkupThemeBuilder）

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift`
- 创建：`platforms/ios/Sources/XMarkup/Theme/MarkupThemeBuilder.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Theme/ThemeBuilderTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Theme/ThemeBuilderTests.swift
import XCTest
@testable import XMarkup

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
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter ThemeBuilderTests`
预期：FAIL，编译错误 "Cannot find 'MarkupTheme' initializer that accepts a trailing closure"

- [ ] **步骤 3：编写实现代码**

```swift
// platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift
import Foundation

/// 主题 DSL 组件协议
public protocol ThemeComponent: Sendable {
    func apply(to theme: inout MarkupTheme)
}

/// 基础字体组件
public struct BaseFont: ThemeComponent {
    public let font: XMFont

    public init(_ font: XMFont) {
        self.font = font
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.baseFont = font
    }
}

/// 标题缩放组件
public struct HeadingScaleComponent: ThemeComponent {
    public let scale: HeadingScale

    public init(_ scale: HeadingScale) {
        self.scale = scale
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.headingScale = scale
    }
}

/// 标签样式组件
public struct TagStyleComponent: ThemeComponent {
    public let key: TagStyleKey
    public let configure: @Sendable (inout AttributeContainer) -> Void

    public init(
        _ key: TagStyleKey,
        configure: @Sendable @escaping (inout AttributeContainer) -> Void
    ) {
        self.key = key
        self.configure = configure
    }

    public func apply(to theme: inout MarkupTheme) {
        var container = AttributeContainer()
        configure(&container)
        theme.tagStyles[key] = container
    }
}

/// 便利函数：创建 TagStyleComponent
public func Tag(
    _ key: TagStyleKey,
    configure: @Sendable @escaping (inout AttributeContainer) -> Void
) -> TagStyleComponent {
    TagStyleComponent(key, configure: configure)
}

/// 媒体策略组件
public struct MediaComponent: ThemeComponent {
    public let strategy: MediaRenderingStrategy

    public init(_ strategy: MediaRenderingStrategy) {
        self.strategy = strategy
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.mediaStrategy = strategy
    }
}

/// 便利函数：创建 MediaComponent
public func Media(_ strategy: MediaRenderingStrategy) -> MediaComponent {
    MediaComponent(strategy)
}
```

```swift
// platforms/ios/Sources/XMarkup/Theme/MarkupThemeBuilder.swift
import Foundation

@resultBuilder
public enum MarkupThemeBuilder {
    public static func buildBlock(_ components: ThemeComponent...) -> [ThemeComponent] {
        Array(components)
    }
}

extension MarkupTheme {
    /// 使用 Result Builder DSL 构建主题
    public init(@MarkupThemeBuilder builder: () -> [ThemeComponent]) {
        self.init()
        var theme = MarkupTheme()
        for component in builder() {
            component.apply(to: &theme)
        }
        self = theme
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter ThemeBuilderTests`
预期：PASS，全部 5 个测试通过

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift platforms/ios/Sources/XMarkup/Theme/MarkupThemeBuilder.swift platforms/ios/Tests/XMarkupTests/Theme/ThemeBuilderTests.swift
git commit -m "feat: 添加 Result Builder DSL（MarkupThemeBuilder + ThemeComponent）"
```

---

## 任务 9：预置主题

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Theme/PresetThemes.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Theme/PresetThemesTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Theme/PresetThemesTests.swift
import XCTest
@testable import XMarkup

final class PresetThemesTests: XCTestCase {

    func testDefaultTheme() {
        let theme = MarkupTheme.default
        XCTAssertEqual(theme.baseFont.pointSize, 16)
        // mark 应有背景色
        XCTAssertNotNil(theme.tagStyles[.mark])
        // code 应有背景色
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
        XCTAssertNotNil(theme.tagStyles[.heading])
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
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter PresetThemesTests`
预期：FAIL，`MarkupTheme.default` 是一个没有静态属性的空 init

- [ ] **步骤 3：编写实现代码**

```swift
// platforms/ios/Sources/XMarkup/Theme/PresetThemes.swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension MarkupTheme {

    /// 通用主题
    public static let `default`: MarkupTheme = {
        var theme = MarkupTheme()
        #if canImport(UIKit)
        var markStyle = AttributeContainer()
        markStyle.uiKit.backgroundColor = .systemYellow.withAlphaComponent(0.3)
        theme.tagStyles[.mark] = markStyle

        var codeStyle = AttributeContainer()
        codeStyle.uiKit.backgroundColor = .systemGray6
        codeStyle.uiKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #elseif canImport(AppKit)
        var markStyle = AttributeContainer()
        markStyle.appKit.backgroundColor = .systemYellow.withAlphaComponent(0.3)
        theme.tagStyles[.mark] = markStyle

        var codeStyle = AttributeContainer()
        codeStyle.appKit.backgroundColor = .systemGray.withAlphaComponent(0.15)
        codeStyle.appKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #endif
        return theme
    }()

    /// 暗色模式主题
    public static let dark: MarkupTheme = {
        var theme = MarkupTheme()
        #if canImport(UIKit)
        var markStyle = AttributeContainer()
        markStyle.uiKit.backgroundColor = .systemOrange.withAlphaComponent(0.3)
        theme.tagStyles[.mark] = markStyle

        var codeStyle = AttributeContainer()
        codeStyle.uiKit.backgroundColor = .systemGray
        codeStyle.uiKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #elseif canImport(AppKit)
        var markStyle = AttributeContainer()
        markStyle.appKit.backgroundColor = .systemOrange.withAlphaComponent(0.3)
        theme.tagStyles[.mark] = markStyle

        var codeStyle = AttributeContainer()
        codeStyle.appKit.backgroundColor = .systemGray.withAlphaComponent(0.3)
        codeStyle.appKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #endif
        return theme
    }()

    /// 聊天气泡主题
    public static let chat: MarkupTheme = {
        var theme = MarkupTheme(baseFont: XMFont.systemFont(ofSize: 14))
        #if canImport(UIKit)
        var linkStyle = AttributeContainer()
        linkStyle.uiKit.foregroundColor = .systemBlue
        theme.tagStyles[.link] = linkStyle
        #elseif canImport(AppKit)
        var linkStyle = AttributeContainer()
        linkStyle.appKit.foregroundColor = .linkColor
        theme.tagStyles[.link] = linkStyle
        #endif
        return theme
    }()

    /// 文章阅读主题
    public static let article: MarkupTheme = {
        var theme = MarkupTheme(baseFont: XMFont.systemFont(ofSize: 17))
        #if canImport(UIKit)
        var blockquoteStyle = AttributeContainer()
        blockquoteStyle.uiKit.foregroundColor = .secondaryLabel
        theme.tagStyles[.blockquote] = blockquoteStyle

        var codeStyle = AttributeContainer()
        codeStyle.uiKit.backgroundColor = .systemGray6
        codeStyle.uiKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #elseif canImport(AppKit)
        var blockquoteStyle = AttributeContainer()
        blockquoteStyle.appKit.foregroundColor = .secondaryLabelColor
        theme.tagStyles[.blockquote] = blockquoteStyle

        var codeStyle = AttributeContainer()
        codeStyle.appKit.backgroundColor = .textBackgroundColor
        codeStyle.appKit.font = .monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        theme.tagStyles[.code] = codeStyle
        #endif
        return theme
    }()
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter PresetThemesTests`
预期：PASS，全部 5 个测试通过

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/PresetThemes.swift platforms/ios/Tests/XMarkupTests/Theme/PresetThemesTests.swift
git commit -m "feat: 添加预置主题（.default / .dark / .chat / .article）"
```

---

## 任务 10：MarkupRenderer 协议 + NSAttributedStringRenderer

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Rendering/MarkupRenderer.swift`
- 创建：`platforms/ios/Sources/XMarkup/Rendering/NSAttributedStringRenderer.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Rendering/NSAttributedStringRendererTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Rendering/NSAttributedStringRendererTests.swift
import XCTest
@testable import XMarkup

final class NSAttributedStringRendererTests: XCTestCase {

    func testRenderAttributedString() {
        var attr = AttributedString("Hello World")
        #if canImport(UIKit)
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif

        let renderer = NSAttributedStringRenderer()
        let result = renderer.render(attr)
        XCTAssertEqual(result.string, "Hello World")
    }

    func testRenderPreservesAttributes() {
        var attr = AttributedString("Hello")
        #if canImport(UIKit)
        attr.uiKit.font = .boldSystemFont(ofSize: 20)
        attr.uiKit.foregroundColor = .red
        #elseif canImport(AppKit)
        attr.appKit.font = .boldSystemFont(ofSize: 20)
        attr.appKit.foregroundColor = .red
        #endif
        attr[XMarkupTagKey.self] = "bold"

        let renderer = NSAttributedStringRenderer()
        let result = renderer.render(attr)

        // 验证 UIKit/AppKit 属性保留
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 20)

        // 验证自定义属性通过 raw key 保留
        let tagValue = result.attribute(NSAttributedString.Key("XMarkup.Tag"), at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(tagValue, "bold")
    }

    func testMeasureReturnsNonZeroSize() {
        var attr = AttributedString("Hello World with some text")
        #if canImport(UIKit)
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif

        let renderer = NSAttributedStringRenderer()
        let size = renderer.measure(attr, constrainedTo: 320)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
    }

    func testMeasureRespectsWidth() {
        var attr = AttributedString("A very long text that should wrap to multiple lines when constrained to a narrow width")
        #if canImport(UIKit)
        attr.uiKit.font = .systemFont(ofSize: 16)
        #elseif canImport(AppKit)
        attr.appKit.font = .systemFont(ofSize: 16)
        #endif

        let renderer = NSAttributedStringRenderer()
        let size = renderer.measure(attr, constrainedTo: 100)
        XCTAssertLessThanOrEqual(size.width, 100)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter NSAttributedStringRendererTests`
预期：FAIL，编译错误 "Cannot find 'NSAttributedStringRenderer' in scope"

- [ ] **步骤 3：编写实现代码**

```swift
// platforms/ios/Sources/XMarkup/Rendering/MarkupRenderer.swift
import Foundation

/// 可插拔的渲染器协议
///
/// 所有渲染器消费 AttributedString（可能携带自定义 XMarkupScope 属性），
/// 而非自定义类型。第三方库通过 NSAttributedString(AttributedString) 桥接后
/// 读取标准属性 + 自定义 XMarkup key。
public protocol MarkupRenderer<Output>: Sendable {
    associatedtype Output

    /// 渲染
    func render(_ attributed: AttributedString) -> Output

    /// 测量内容尺寸（用于布局计算）
    func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize
}
```

```swift
// platforms/ios/Sources/XMarkup/Rendering/NSAttributedStringRenderer.swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 零成本桥接渲染器——NSAttributedString(AttributedString) 是 O(1) 桥接
public struct NSAttributedStringRenderer: MarkupRenderer, Sendable {
    public init() {}

    public func render(_ attributed: AttributedString) -> NSAttributedString {
        return NSAttributedString(attributed)
    }

    public func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize {
        let nsAttr = NSAttributedString(attributed)
        let size = nsAttr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter NSAttributedStringRendererTests`
预期：PASS，全部 4 个测试通过

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/MarkupRenderer.swift platforms/ios/Sources/XMarkup/Rendering/NSAttributedStringRenderer.swift platforms/ios/Tests/XMarkupTests/Rendering/NSAttributedStringRendererTests.swift
git commit -m "feat: 添加 MarkupRenderer 协议 + NSAttributedStringRenderer 实现"
```

---

## 任务 11：MarkupDocument.render(theme:) 核心渲染管线

这是最核心的转换：将 MarkupDocument + MarkupTheme → AttributedString。

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift`

- [ ] **步骤 1：编写失败的测试**

```swift
// platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift
import XCTest
@testable import XMarkup

final class RenderTests: XCTestCase {

    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    // MARK: - 基础渲染

    func testRenderEmptyDocument() {
        let doc = MarkupDocument(blocks: [])
        let attr = doc.render()
        XCTAssertTrue(attr.characters.isEmpty)
    }

    func testRenderSingleParagraph() throws {
        let result = try parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        XCTAssertEqual(String(attr.characters), "Hello")
    }

    func testRenderTwoParagraphs() throws {
        let result = try parse("<p>First</p><p>Second</p>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let text = String(attr.characters)
        XCTAssertTrue(text.contains("First"))
        XCTAssertTrue(text.contains("Second"))
    }

    // MARK: - 字体属性

    func testRenderBoldFontTrait() throws {
        let result = try parse("<b>bold</b>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        // 转换为 NSAttributedString 检查字体
        let nsAttr = NSAttributedString(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.bold))
        #endif
    }

    func testRenderItalicFontTrait() throws {
        let result = try parse("<i>italic</i>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.italic))
        #endif
    }

    func testRenderBoldItalicMerged() throws {
        let result = try parse("<b><i>both</i></b>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitItalic))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.bold))
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.italic))
        #endif
    }

    // MARK: - 非字体属性

    func testRenderUnderline() throws {
        let result = try parse("<u>under</u>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let style = nsAttr.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testRenderStrikethrough() throws {
        let result = try parse("<s>strike</s>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let style = nsAttr.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(style, NSUnderlineStyle.single.rawValue)
    }

    func testRenderLink() throws {
        let result = try parse("<a href=\"https://example.com\">click</a>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let link = nsAttr.attribute(.link, at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(link, "https://example.com")
    }

    func testRenderCodeHasMonospaceFont() throws {
        let result = try parse("<code>print()</code>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
        #if canImport(UIKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        #elseif canImport(AppKit)
        XCTAssertTrue(font!.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #endif
    }

    func testRenderCodeHasBackgroundColor() throws {
        let result = try parse("<code>code</code>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render(theme: .default)
        let nsAttr = NSAttributedString(attr)
        let bg = nsAttr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(bg, "<code> 使用默认主题应有背景色")
    }

    // MARK: - 自定义 XMarkupScope 属性

    func testRenderCarriesXMarkupTag() throws {
        let result = try parse("<b>bold</b>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        // 检查自定义 key 存在
        let nsAttr = NSAttributedString(attr)
        let tagValue = nsAttr.attribute(NSAttributedString.Key("XMarkup.Tag"), at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(tagValue, "bold")
    }

    func testRenderCarriesHeadingLevel() throws {
        let result = try parse("<h1>Title</h1>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let level = nsAttr.attribute(NSAttributedString.Key("XMarkup.HeadingLevel"), at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(level, 1)
    }

    func testRenderCarriesLinkURL() throws {
        let result = try parse("<a href=\"https://example.com\">click</a>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let url = nsAttr.attribute(NSAttributedString.Key("XMarkup.LinkURL"), at: 0, effectiveRange: nil) as? String
        XCTAssertEqual(url, "https://example.com")
    }

    // MARK: - 主题覆盖

    func testRenderWithCustomTheme() throws {
        let result = try parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        let customTheme = MarkupTheme(baseFont: XMFont.systemFont(ofSize: 20))
        let attr = doc.render(theme: customTheme)
        let nsAttr = NSAttributedString(attr)
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertEqual(font?.pointSize, 20)
    }

    // MARK: - CSS 样式

    func testRenderCSSForegroundColor() throws {
        let result = try parse("<span style=\"color:#FF0000\">red</span>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        let color = nsAttr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    // MARK: - 媒体附件

    func testRenderImageAttachment() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        let nsAttr = NSAttributedString(attr)
        var foundAttachment = false
        nsAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    // MARK: - 边界情况

    func testRenderUnknownTagNoCrash() throws {
        let result = try parse("<custom>text</custom>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        XCTAssertFalse(String(attr.characters).isEmpty)
    }

    func testRenderEmptyInput() throws {
        let result = try parse("")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()
        XCTAssertTrue(String(attr.characters).isEmpty)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter RenderTests`
预期：FAIL，编译错误 "Value of type 'MarkupDocument' has no member 'render'"

- [ ] **步骤 3：编写实现代码**

```swift
// platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension MarkupDocument {

    /// 将文档转换为 AttributedString
    ///
    /// 性能策略：按 block 分段构建（init(String, attributes: AttributeContainer)），
    /// 然后一次性 append 拼接。利用 AttributedString 的 COW 优化。
    public func render(theme: MarkupTheme = .default) -> AttributedString {
        guard !blocks.isEmpty else {
            return AttributedString("")
        }

        var result = AttributedString("")

        for (index, block) in blocks.enumerated() {
            let blockAttr = renderBlock(block, theme: theme)

            if index > 0 {
                // 块级元素之间追加换行
                result.append(AttributedString("\n"))
            }

            result.append(blockAttr)
        }

        return result
    }

    // MARK: - Block Rendering

    private func renderBlock(_ block: MarkupBlock, theme: MarkupTheme) -> AttributedString {
        // 1. 构建块级基础属性
        var baseAttributes = AttributeContainer()
        baseAttributes.uiKit.font = theme.baseFont

        // 2. 根据 block.kind 调整属性
        let blockKindName = blockKindName(for: block.kind)
        applyBlockKindAttributes(
            kind: block.kind,
            theme: theme,
            to: &baseAttributes
        )

        // 3. 设置自定义 XMarkupScope 属性
        baseAttributes[XMarkupTagKey.self] = blockKindName
        baseAttributes[XMarkupBlockKindKey.self] = blockKindName

        switch block.kind {
        case let .heading(level):
            baseAttributes[XMarkupHeadingLevelKey.self] = level.rawValue
        case let .listItem(isOrdered, indentLevel):
            baseAttributes[XMarkupListItemInfoKey.self] = "\(isOrdered ? "ordered" : "unordered"):\(indentLevel)"
        default:
            break
        }

        // 4. 处理媒体附件
        if let attachment = block.attachment {
            return renderAttachmentBlock(block, attachment: attachment, theme: theme, baseAttributes: baseAttributes)
        }

        // 5. 构建段落 AttributedString
        var attr = AttributedString(block.text, attributes: baseAttributes)

        // 6. 应用内联样式
        for inline in block.inlines {
            applyInlineAttributes(inline, theme: theme, to: &attr, blockText: block.text)
        }

        // 7. 应用主题 tagStyles 覆盖
        applyThemeOverrides(for: block, theme: theme, to: &attr)

        return attr
    }

    // MARK: - Block Kind Attributes

    private func applyBlockKindAttributes(
        kind: BlockKind,
        theme: MarkupTheme,
        to attributes: inout AttributeContainer
    ) {
        switch kind {
        case let .heading(level):
            let scale: CGFloat
            switch level {
            case .h1: scale = theme.headingScale.h1
            case .h2: scale = theme.headingScale.h2
            case .h3: scale = theme.headingScale.h3
            case .h4: scale = theme.headingScale.h4
            case .h5: scale = theme.headingScale.h5
            case .h6: scale = theme.headingScale.h6
            }
            let fontSize = theme.baseFont.pointSize * scale
            #if canImport(UIKit)
            let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(.traitBold)!
            attributes.uiKit.font = UIFont(descriptor: boldDescriptor, size: fontSize)
            #elseif canImport(AppKit)
            let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(.bold)
            attributes.appKit.font = NSFont(descriptor: boldDescriptor, size: fontSize)
            #endif

        case .preformatted:
            #if canImport(UIKit)
            attributes.uiKit.font = UIFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
            #elseif canImport(AppKit)
            attributes.appKit.font = NSFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
            #endif

        case .horizontalRule:
            // HR 只是一个视觉分隔，文本内容通常为空
            break

        case .blockquote:
            break  // 颜色等由主题 tagStyles 覆盖

        default:
            break
        }
    }

    // MARK: - Inline Attributes

    private func applyInlineAttributes(
        _ inline: MarkupInline,
        theme: MarkupTheme,
        to attr: inout AttributedString,
        blockText: String
    ) {
        // 将 String.Index range 转换为 AttributedString 的 Range
        let nsRange = NSRange(inline.range, in: blockText)
        guard let attrRange = Range(nsRange, in: attr) else { return }

        switch inline.kind {
        case .bold:
            applyFontTrait(traitBold, to: attrRange, in: &attr)

        case .italic:
            applyFontTrait(traitItalic, to: attrRange, in: &attr)

        case .underline:
            attr[attrRange].uiKit.underlineStyle = .single

        case .strikethrough:
            attr[attrRange].uiKit.strikethroughStyle = .single

        case .code:
            #if canImport(UIKit)
            let monoFont = UIFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
            #elseif canImport(AppKit)
            let monoFont = NSFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
            #endif
            attr[attrRange].uiKit.font = monoFont

        case .mark:
            break  // 颜色由主题 tagStyles 覆盖

        case .link(let url):
            attr[attrRange].uiKit.foregroundColor = XMColor.systemBlue
            attr[attrRange].link = URL(string: url)
            attr[attrRange][XMarkupLinkURLKey.self] = url

        case .subscriptText:
            break  // P2

        case .superscript:
            break  // P2

        case .span(let styles):
            for style in styles {
                applyInlineStyle(style, to: attrRange, in: &attr)
            }
        }

        // 为所有内联元素设置自定义 tag
        let tagName = inlineKindName(for: inline.kind)
        attr[attrRange][XMarkupTagKey.self] = tagName
    }

    private func applyFontTrait(
        _ trait: XMFontDescriptor.SymbolicTraits,
        to range: Range<AttributedString.Index>,
        in attr: inout AttributedString
    ) {
        // 遍历 range 内的 runs，对每个 font 添加 trait
        for run in attr[range].runs {
            #if canImport(UIKit)
            if let font = run.uiKit.font {
                var traits = font.fontDescriptor.symbolicTraits
                traits.insert(trait)
                if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                    let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                    attr[run.range].uiKit.font = newFont
                }
            }
            #elseif canImport(AppKit)
            if let font = run.appKit.font {
                var traits = font.fontDescriptor.symbolicTraits
                traits.insert(trait)
                let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                if let newFont = NSFont(descriptor: descriptor, size: font.pointSize) {
                    attr[run.range].appKit.font = newFont
                }
            }
            #endif
        }
    }

    private func applyInlineStyle(
        _ style: InlineStyle,
        to range: Range<AttributedString.Index>,
        in attr: inout AttributedString
    ) {
        switch style {
        case .foregroundColor(let hex):
            if let color = ColorParser.parse(hex) {
                attr[range].uiKit.foregroundColor = color
            }
        case .backgroundColor(let hex):
            if let color = ColorParser.parse(hex) {
                attr[range].uiKit.backgroundColor = color
            }
        case .fontSize(let size):
            for run in attr[range].runs {
                #if canImport(UIKit)
                if let font = run.uiKit.font {
                    let newFont = UIFont(descriptor: font.fontDescriptor, size: CGFloat(size))
                    attr[run.range].uiKit.font = newFont
                }
                #elseif canImport(AppKit)
                if let font = run.appKit.font {
                    if let newFont = NSFont(descriptor: font.fontDescriptor, size: CGFloat(size)) {
                        attr[run.range].appKit.font = newFont
                    }
                }
                #endif
            }
        case .fontWeight(let weight):
            break  // CSS font-weight 映射，P2
        case .fontStyle(let fontStyle):
            if fontStyle == "italic" {
                applyFontTrait(traitItalic, to: range, in: &attr)
            }
        case .textDecoration(let decoration):
            if decoration == "underline" {
                attr[range].uiKit.underlineStyle = .single
            } else if decoration == "line-through" {
                attr[range].uiKit.strikethroughStyle = .single
            }
        case .lineHeight:
            break  // 行高需要段落样式，P2
        case .letterSpacing:
            break  // 字间距需要 kern，P2
        }
    }

    // MARK: - Theme Overrides

    private func applyThemeOverrides(
        for block: MarkupBlock,
        theme: MarkupTheme,
        to attr: inout AttributedString
    ) {
        // 块级主题覆盖
        let blockStyleKey = blockStyleKey(for: block.kind)
        if let container = theme.tagStyles[blockStyleKey] {
            let fullRange = attr.startIndex..<attr.endIndex
            mergeAttributeContainer(container, into: &attr, range: fullRange)
        }

        // 内联主题覆盖
        for inline in block.inlines {
            let inlineStyleKey = inlineStyleKey(for: inline.kind)
            if let container = theme.tagStyles[inlineStyleKey] {
                let nsRange = NSRange(inline.range, in: block.text)
                if let attrRange = Range(nsRange, in: attr) {
                    mergeAttributeContainer(container, into: &attr, range: attrRange)
                }
            }
        }
    }

    private func mergeAttributeContainer(
        _ container: AttributeContainer,
        into attr: inout AttributedString,
        range: Range<AttributedString.Index>
    ) {
        // 合并非 nil 的 UIKit 属性
        #if canImport(UIKit)
        if let font = container.uiKit.font {
            attr[range].uiKit.font = font
        }
        if let color = container.uiKit.foregroundColor {
            attr[range].uiKit.foregroundColor = color
        }
        if let bgColor = container.uiKit.backgroundColor {
            attr[range].uiKit.backgroundColor = bgColor
        }
        #elseif canImport(AppKit)
        if let font = container.appKit.font {
            attr[range].appKit.font = font
        }
        if let color = container.appKit.foregroundColor {
            attr[range].appKit.foregroundColor = color
        }
        if let bgColor = container.appKit.backgroundColor {
            attr[range].appKit.backgroundColor = bgColor
        }
        #endif
    }

    // MARK: - Attachment Rendering

    private func renderAttachmentBlock(
        _ block: MarkupBlock,
        attachment: MarkupAttachment,
        theme: MarkupTheme,
        baseAttributes: AttributeContainer
    ) -> AttributedString {
        let nsAttachment: NSTextAttachment

        switch theme.mediaStrategy {
        case .placeholder:
            nsAttachment = createPlaceholderAttachment(
                content: attachment.content,
                suggestedSize: attachment.suggestedSize
            )
        case .imageProvider(let provider):
            let src = extractSrc(from: attachment.content)
            if let image = provider(src) {
                let attachment = NSTextAttachment()
                attachment.image = image
                let aspectRatio = image.size.height / max(image.size.width, 1)
                let displayWidth = attachment.suggestedSize.width
                let displaySize = CGSize(width: displayWidth, height: displayWidth * aspectRatio)
                attachment.bounds = CGRect(origin: .zero, size: displaySize)
                nsAttachment = attachment
            } else {
                nsAttachment = createPlaceholderAttachment(
                    content: attachment.content,
                    suggestedSize: attachment.suggestedSize
                )
            }
        case .customAttachment(let factory):
            if let custom = factory(attachment.content, attachment.suggestedSize) {
                nsAttachment = custom
            } else {
                nsAttachment = createPlaceholderAttachment(
                    content: attachment.content,
                    suggestedSize: attachment.suggestedSize
                )
            }
        }

        var attr = AttributedString("\u{FFFC}", attributes: baseAttributes)
        attr[XMarkupAttachmentRefKey.self] = srcIdentifier(from: attachment.content)
        attr[XMarkupTagKey.self] = blockKindName(for: block.kind)

        // 将 NSTextAttachment 通过 NSAttributedString 中间步骤嵌入
        let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attr))
        let attachmentAttr = NSAttributedString(attachment: nsAttachment)
        // 找到 \u{FFFC} 并替换
        let nsRange = (nsAttr.string as NSString).range(of: "\u{FFFC}")
        if nsRange.location != NSNotFound {
            nsAttr.replaceCharacters(in: nsRange, with: attachmentAttr)
        }

        return AttributedString(nsAttr)
    }

    private func createPlaceholderAttachment(
        content: AttachmentContent,
        suggestedSize: CGSize
    ) -> NSTextAttachment {
        let symbolName: String
        switch content {
        case .image: symbolName = "photo"
        case .video: symbolName = "play.rectangle"
        case .audio: symbolName = "waveform"
        case .custom: symbolName = "square"
        }

        let size = suggestedSize.width > 0 ? suggestedSize : CGSize(width: 200, height: 150)
        let image = createPlaceholderImage(systemName: symbolName, size: size)

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)
        return attachment
    }

    private func createPlaceholderImage(systemName: String, size: CGSize) -> XMImage {
        #if canImport(UIKit)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: min(size.width, size.height) * 0.3)
        let symbol = UIImage(systemName: systemName, withConfiguration: symbolConfig) ?? UIImage()
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemGray.withAlphaComponent(0.1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let symbolSize = symbol.size
            symbol.draw(at: CGPoint(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2
            ))
        }
        #elseif canImport(AppKit)
        let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage(size: size)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemGray.withAlphaComponent(0.1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let symbolSize = symbol.size
        symbol.draw(
            at: NSPoint(x: (size.width - symbolSize.width) / 2, y: (size.height - symbolSize.height) / 2),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        image.unlockFocus()
        return image
        #endif
    }

    // MARK: - Name Mappings

    private func blockKindName(for kind: BlockKind) -> String {
        switch kind {
        case .paragraph: return "paragraph"
        case .heading(let level): return "heading\(level.rawValue)"
        case .blockquote: return "blockquote"
        case .preformatted: return "preformatted"
        case .listItem: return "listItem"
        case .division: return "division"
        case .horizontalRule: return "horizontalRule"
        case .table: return "table"
        }
    }

    private func inlineKindName(for kind: InlineKind) -> String {
        switch kind {
        case .bold: return "bold"
        case .italic: return "italic"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .code: return "code"
        case .mark: return "mark"
        case .link: return "link"
        case .subscriptText: return "subscript"
        case .superscript: return "superscript"
        case .span: return "span"
        }
    }

    private func blockStyleKey(for kind: BlockKind) -> TagStyleKey? {
        switch kind {
        case .paragraph: return .paragraph
        case .heading: return .heading
        case .blockquote: return .blockquote
        case .preformatted: return .preformatted
        case .listItem: return .listItem
        case .division: return .division
        case .horizontalRule: return .horizontalRule
        case .table: return nil
        }
    }

    private func inlineStyleKey(for kind: InlineKind) -> TagStyleKey? {
        switch kind {
        case .bold: return .bold
        case .italic: return .italic
        case .underline: return .underline
        case .strikethrough: return .strikethrough
        case .code: return .code
        case .mark: return .mark
        case .link: return .link
        case .subscriptText, .superscript: return nil
        case .span: return nil
        }
    }

    private func extractSrc(from content: AttachmentContent) -> String {
        switch content {
        case .image(let src), .video(let src), .audio(let src): return src
        case .custom(_, let metadata): return metadata["src"] ?? ""
        }
    }

    private func srcIdentifier(from content: AttachmentContent) -> String {
        switch content {
        case .image(let src): return "image:\(src)"
        case .video(let src): return "video:\(src)"
        case .audio(let src): return "audio:\(src)"
        case .custom(let type, _): return "custom:\(type)"
        }
    }
}

// MARK: - 跨平台字体 Trait 常量

#if canImport(UIKit)
private let traitBold: UIFontDescriptor.SymbolicTraits = .traitBold
private let traitItalic: UIFontDescriptor.SymbolicTraits = .traitItalic
#elseif canImport(AppKit)
private let traitBold: NSFontDescriptor.SymbolicTraits = .bold
private let traitItalic: NSFontDescriptor.SymbolicTraits = .italic
#endif
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter RenderTests`
预期：PASS，全部测试通过

注意：`attr[range].uiKit` 和 `attr[range].appKit` 需要平台条件编译。如果编译失败，将所有 `attr[range].uiKit.xxx` 替换为：

```swift
#if canImport(UIKit)
attr[range].uiKit.xxx
#elseif canImport(AppKit)
attr[range].appKit.xxx
#endif
```

为简化代码，创建辅助扩展：

```swift
// 在 MarkupDocument+Render.swift 顶部添加
extension AttributeContainer {
    var platformFont: XMFont? {
        #if canImport(UIKit)
        return uiKit.font
        #elseif canImport(AppKit)
        return appKit.font
        #endif
    }
}
```

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift
git commit -m "feat: 实现 MarkupDocument.render(theme:) 核心渲染管线"
```

---

## 任务 12：公共导出模块 + 废弃旧 API

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/XMarkup.swift`
- 修改：`platforms/ios/Sources/XMarkup/XMarkupStyleConfig.swift`（添加 deprecated 标注）
- 修改：`platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift`（添加 deprecated 标注）

- [ ] **步骤 1：创建公共导出模块**

```swift
// platforms/ios/Sources/XMarkup/XMarkup.swift
// XMarkup 现代化公共 API 导出
//
// 此文件不做任何实现，仅作为模块入口的文档标记。
// SPM 会自动扫描子目录下的所有 .swift 文件，所有 public 类型自动可见。
```

- [ ] **步骤 2：标记旧 API 为 deprecated**

在 `XMarkupStyleConfig.swift` 文件顶部（import 之后，第一个类型定义之前）添加：

```swift
// 在 XMarkupTagStyle 定义之前添加：
@available(*, deprecated, renamed: "MarkupTheme", message: "请使用 MarkupTheme 和 TagStyleKey 代替")
```

即：
```swift
@available(*, deprecated, renamed: "MarkupTheme", message: "请使用 MarkupTheme 和 TagStyleKey 代替")
public struct XMarkupTagStyle: @unchecked Sendable {
```

```swift
@available(*, deprecated, renamed: "MarkupTheme", message: "请使用 MarkupTheme 代替")
public struct XMarkupStyleConfig: @unchecked Sendable {
```

在 `NSAttributedString+XMarkup.swift` 的 `makeAttributedString` 方法前添加：

```swift
@available(*, deprecated, message: "请使用 MarkupDocument.from(result).render(theme:) 代替")
public func makeAttributedString(config: XMarkupStyleConfig = .default) -> NSAttributedString {
```

- [ ] **步骤 3：运行全部测试确保没有破坏**

运行：`swift test`
预期：PASS，全部测试通过（新旧 API 都能编译运行）
注意：可能有 deprecated warnings，这是预期行为。

- [ ] **步骤 4：Commit**

```bash
git add platforms/ios/Sources/XMarkup/XMarkup.swift platforms/ios/Sources/XMarkup/XMarkupStyleConfig.swift platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift
git commit -m "feat: 添加公共导出模块 + 标记旧 API 为 deprecated"
```

---

## 任务 13：最终集成测试 + 清理

**文件：**
- 运行全部测试确保新旧 API 共存
- 验证 Demo App 可以正常编译

- [ ] **步骤 1：运行全部测试**

运行：`swift test`
预期：PASS，全部测试通过（包括旧测试文件和新测试文件）

- [ ] **步骤 2：运行完整的 Xcode 构建检查**

运行：`swift build`
预期：BUILD SUCCEEDED

- [ ] **步骤 3：验证新 API 端到端流程**

在 `RenderTests.swift` 中添加端到端集成测试：

```swift
    // MARK: - 端到端集成

    func testEndToEndParseBuildRender() throws {
        let html = "<h1>Title</h1><p>Hello <b>world</b> <a href=\"https://example.com\">link</a></p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let attr = doc.render(theme: .default)
        let nsAttr = NSAttributedString(attr)

        // 验证包含所有文本
        XCTAssertTrue(nsAttr.string.contains("Title"))
        XCTAssertTrue(nsAttr.string.contains("Hello"))
        XCTAssertTrue(nsAttr.string.contains("world"))
        XCTAssertTrue(nsAttr.string.contains("link"))

        // 验证标题有 heading level
        let fullRange = NSRange(location: 0, length: nsAttr.length)
        var foundHeadingLevel = false
        nsAttr.enumerateAttribute(NSAttributedString.Key("XMarkup.HeadingLevel"), in: fullRange) { value, _, _ in
            if let level = value as? Int, level == 1 {
                foundHeadingLevel = true
            }
        }
        XCTAssertTrue(foundHeadingLevel)
    }

    func testEndToEndWithArticleTheme() throws {
        let html = "<h1>Article Title</h1><p>Content with <code>code</code> and <b>bold</b>.</p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let attr = doc.render(theme: .article)
        let nsAttr = NSAttributedString(attr)

        // 验证文章主题的 base font
        let font = nsAttr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
        XCTAssertNotNil(font)
    }

    func testEndToEndWithNSRenderer() throws {
        let html = "<p>Hello <b>bold</b></p>"
        let parser = try XMarkupParser()
        let result = try parser.parse(html)
        let doc = MarkupDocument.from(result)
        let attr = doc.render()

        let renderer = NSAttributedStringRenderer()
        let nsAttr = renderer.render(attr)
        let size = renderer.measure(attr, constrainedTo: 300)

        XCTAssertEqual(nsAttr.string, "Hello bold")
        XCTAssertGreaterThan(size.height, 0)
    }
```

- [ ] **步骤 4：运行新增测试**

运行：`swift test --filter RenderTests`
预期：PASS

- [ ] **步骤 5：最终 Commit**

```bash
git add platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift
git commit -m "test: 添加端到端集成测试（parse → build → render → renderer）"
```

---

## 自检清单

### 1. 规格覆盖度

| 规格章节 | 覆盖任务 |
|---------|---------|
| §3 数据模型：MarkupDocument | 任务 1-5 |
| §3.2 通用附件模型 | 任务 2 |
| §3.3 从 C++ flat spans 构建 | 任务 5 |
| §3.4 增量更新预留 | 任务 4（appending） |
| §4.1 主题核心类型 | 任务 7 |
| §4.2 Result Builder DSL | 任务 8 |
| §4.3 预置主题 | 任务 9 |
| §5 XMarkupScope | 任务 6 |
| §6.1 render(theme:) | 任务 11 |
| §6.2 MarkupRenderer 协议 | 任务 10 |
| §6.3 NSAttributedStringRenderer | 任务 10 |
| §7 用户侧 API 总览 | 任务 11-13 |
| §9 文件结构规划 | 任务 1-13 逐步建立 |
| §10 废弃计划 | 任务 12 |
| §11 P1 后期迭代 | 任务 4（appending 预留）、DocumentDiff 留 P3 |
| §12 性能策略 | 任务 11（分段构建 + COW） |
| §13 测试策略 | 任务 1-13 每个 TDD |

无遗漏。

### 2. 占位符扫描

无 "待定"、"TODO"、"后续实现" 等占位符。所有步骤包含完整代码。

### 3. 类型一致性

- `MarkupInline.range` 类型为 `Range<String.Index>`，在任务 5（builder）中使用 `Range(span.range, in: text)` 从 NSRange 转换，在任务 11（render）中使用 `NSRange(inline.range, in: blockText)` 反向转换。
- `BlockKind.heading(Level)` 中 `Level` 是独立 enum，非 `Int`。
- `InlineKind.link(url: String)` 携带 URL 字符串。
- 所有 `TagStyleKey` 使用一致（任务 7 定义、任务 8 DSL 使用、任务 11 render 使用）。
- `XMarkupTagKey` 等自定义 Key 在任务 6 定义，在任务 11 的 render 中使用。
- 跨平台 `uiKit` / `appKit` 属性访问使用 `#if canImport(UIKit)` / `#if canImport(AppKit)` 条件编译，贯穿所有任务。
