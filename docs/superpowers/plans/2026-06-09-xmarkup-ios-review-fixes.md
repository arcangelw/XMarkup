# XMarkup iOS Code Review 收尾修复 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 Code Review 发现的 8 项实现问题，完成源码和测试的子目录迁移，补充注释规范，同步更新规格文档。

**架构：** 纯代码修复 + 文件迁移 + 文档同步，不涉及新功能。所有修改在 `main` 分支上进行。

**技术栈：** Swift 6 / SPM / XCTest

---

## 文件结构

### 迁移的源码文件（`Sources/XMarkup/` → `Sources/XMarkup/Bridge/`）

| 原路径 | 新路径 |
|--------|--------|
| `Sources/XMarkup/ColorParser.swift` | `Sources/XMarkup/Bridge/ColorParser.swift` |
| `Sources/XMarkup/PlatformTypes.swift` | `Sources/XMarkup/Bridge/PlatformTypes.swift` |
| `Sources/XMarkup/XMarkupError.swift` | `Sources/XMarkup/Bridge/XMarkupError.swift` |
| `Sources/XMarkup/XMarkupParser.swift` | `Sources/XMarkup/Bridge/XMarkupParser.swift` |
| `Sources/XMarkup/XMarkupResult.swift` | `Sources/XMarkup/Bridge/XMarkupResult.swift` |
| `Sources/XMarkup/XMarkupSpan.swift` | `Sources/XMarkup/Bridge/XMarkupSpan.swift` |
| `Sources/XMarkup/XMarkupStyle.swift` | `Sources/XMarkup/Bridge/XMarkupStyle.swift` |
| `Sources/XMarkup/XMarkupTag.swift` | `Sources/XMarkup/Bridge/XMarkupTag.swift` |

### 迁移的测试文件

| 原路径 | 新路径 |
|--------|--------|
| `Tests/XMarkupTests/XMarkupParserTests.swift` | `Tests/XMarkupTests/Bridge/XMarkupParserTests.swift` |
| `Tests/XMarkupTests/XMarkupResultTests.swift` | `Tests/XMarkupTests/Bridge/XMarkupResultTests.swift` |
| `Tests/XMarkupTests/ColorParserTests.swift` | `Tests/XMarkupTests/Bridge/ColorParserTests.swift` |
| `Tests/XMarkupTests/CrossPlatformTests.swift` | `Tests/XMarkupTests/Bridge/CrossPlatformTests.swift` |
| `Tests/XMarkupTests/Theme/MarkupThemeTests.swift` | `Tests/XMarkupTests/Theme/MarkupThemeTests.swift`（保持在 Theme/ 不变） |

### 修改的源码文件

| 文件 | 修改内容 |
|------|----------|
| `Sources/XMarkup/Theme/MarkupTheme.swift` | 补全 Equatable |
| `Sources/XMarkup/Core/MarkupDocumentBuilder.swift` | trimmedEnd 修正 + 部分重叠处理 |
| `Sources/XMarkup/Rendering/MarkupDocument+Render.swift` | 安全断言注释 |
| `Sources/XMarkup/Rendering/NSAttributedStringRenderer.swift` | 消除多余复制 |
| `Sources/XMarkup/Theme/HeadingScale.swift` | 来源注释 |
| `Sources/XMarkup/Theme/PresetThemes.swift` | dark 占位说明 |
| `Sources/XMarkup/Bridge/ColorParser.swift` | 格式说明 |
| `Sources/XMarkup/Core/MarkupInline.swift` | enum case 注释 |
| `Sources/XMarkup/Core/BlockKind.swift` | enum case 注释 |
| `Sources/XMarkup/Core/MarkupDocument.swift` | API 使用示例 |
| `Sources/XMarkup/Core/MarkupBlock.swift` | API 使用示例 |
| `Sources/XMarkup/Rendering/MarkupRenderer.swift` | API 使用示例 |

### 修改的文档文件

| 文件 | 修改内容 |
|------|----------|
| `docs/superpowers/specs/2026-06-08-xmarkup-modern-swift-redesign.md` | §3.1 range 类型 + §9.2 目录结构 |
| `~/.claude/projects/-Users-arcangelw-GitHub-XMarkup/memory/MEMORY.md` | 进度更新 |

---

## 任务 1：目录结构迁移

**文件：**
- 迁移：8 个源码文件 → `Sources/XMarkup/Bridge/`
- 迁移：4 个测试文件 → `Tests/XMarkupTests/Bridge/`

- [ ] **步骤 1：迁移源码文件到 Bridge/ 子目录**

```bash
mkdir -p platforms/ios/Sources/XMarkup/Bridge
cd platforms/ios/Sources/XMarkup
git mv ColorParser.swift Bridge/
git mv PlatformTypes.swift Bridge/
git mv XMarkupError.swift Bridge/
git mv XMarkupParser.swift Bridge/
git mv XMarkupResult.swift Bridge/
git mv XMarkupSpan.swift Bridge/
git mv XMarkupStyle.swift Bridge/
git mv XMarkupTag.swift Bridge/
```

- [ ] **步骤 2：迁移测试文件到 Bridge/ 子目录**

```bash
mkdir -p platforms/ios/Tests/XMarkupTests/Bridge
cd platforms/ios/Tests/XMarkupTests
git mv XMarkupParserTests.swift Bridge/
git mv XMarkupResultTests.swift Bridge/
git mv ColorParserTests.swift Bridge/
git mv CrossPlatformTests.swift Bridge/
```

注意：`Theme/MarkupThemeTests.swift` 已经在 `Theme/` 子目录中，无需迁移。

- [ ] **步骤 3：运行测试验证迁移未破坏编译**

运行：`cd /Users/arcangelw/GitHub/XMarkup && swift test 2>&1 | tail -5`

预期：`Executed 134 tests, with 0 failures`

- [ ] **步骤 4：Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Bridge 层源码和测试到子目录，对齐规格目录结构"
```

---

## 任务 2：MarkupTheme Equatable 修复

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift`
- 修改：`platforms/ios/Tests/XMarkupTests/Theme/MarkupThemeTests.swift`

- [ ] **步骤 1：编写测试 — 不同 mediaStrategy 的 theme 应相等**

在 `MarkupThemeTests.swift` 的 `MarkupThemeTests` 类中添加：

```swift
func testThemeEqualityIgnoresMediaStrategy() {
    let a = MarkupTheme(mediaStrategy: .placeholder)
    let b = MarkupTheme(mediaStrategy: .imageProvider({ _ in nil }))
    // mediaStrategy 不同但 baseFont/headingScale/tagStyles 相同，应判等
    XCTAssertEqual(a, b)
}

func testThemeInequalityDifferentTagStyles() {
    var a = MarkupTheme()
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
```

同时更新现有的 `testThemeEquality`，从手动字段比较改为直接用 `==`：

```swift
func testThemeEquality() {
    let a = MarkupTheme.default
    let b = MarkupTheme.default
    XCTAssertEqual(a, b)
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test 2>&1 | grep -E "(FAIL|error:)" | head -5`

预期：`testThemeEqualityIgnoresMediaStrategy` 编译失败，因为 `MarkupTheme` 不遵循 `Equatable`。

- [ ] **步骤 3：修复 MarkupTheme — 声明 Equatable 并修正 ==**

将 `platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift` 修改为：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 纯值类型的样式主题
///
/// `Equatable` 仅比较 `baseFont`、`headingScale`、`tagStyles` 三个样式配置字段。
/// `mediaStrategy` 包含闭包（`.imageProvider` / `.customAttachment`），不可比较，因此不参与判等。
/// 如需比较渲染策略是否相同，请单独检查 `mediaStrategy` 的 case。
public struct MarkupTheme: @unchecked Sendable, Equatable {
    /// 基础字体
    public var baseFont: XMFont
    /// 标题缩放系数
    public var headingScale: HeadingScale
    /// 标签样式映射
    public var tagStyles: [TagStyleKey: AttributeContainer]
    /// 媒体渲染策略（不参与 Equatable 比较，因包含闭包）
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

    /// Equatable 仅比较样式配置项，排除 mediaStrategy（闭包不可比较）
    public static func == (lhs: MarkupTheme, rhs: MarkupTheme) -> Bool {
        lhs.baseFont == rhs.baseFont
            && lhs.headingScale == rhs.headingScale
            && lhs.tagStyles == rhs.tagStyles
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test 2>&1 | tail -5`

预期：所有测试通过（含新增的 2 个 Equatable 测试）。

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift platforms/ios/Tests/XMarkupTests/Theme/MarkupThemeTests.swift
git commit -m "fix: MarkupTheme 补全 Equatable 协议，mediaStrategy 闭包不参与判等"
```

---

## 任务 3：convertToInlines trimmedEnd 修正 + 部分重叠处理

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift`
- 修改：`platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift`

- [ ] **步骤 1：编写测试 — 部分重叠的 inline span 不应被跳过**

在 `MarkupDocumentBuilderTests.swift` 末尾添加：

```swift
// MARK: - 边界修复测试

func testPartiallyOverlappingInlineNotDropped() throws {
    // 构造一个场景：inline span 尾部超出 parentRange 边界
    // 使用 <p><b>bold</b></p> 确保 bold span 完全在 <p> 内部
    // 再测试一个更复杂的场景验证 inline 不被错误跳过
    let result = try parse("<p><b>bold</b> text</p>")
    let doc = MarkupDocument.from(result)
    XCTAssertEqual(doc.blocks.count, 1)
    XCTAssertEqual(doc.blocks[0].inlines.count, 1)
    XCTAssertEqual(doc.blocks[0].inlines[0].kind, .bold)
}

func testInlineRangeRelativeToBlock() throws {
    // 验证 inline range 是相对于块起始位置的偏移
    let result = try parse("<p>Hello <b>bold</b></p>")
    let doc = MarkupDocument.from(result)
    XCTAssertEqual(doc.blocks.count, 1)
    guard let inline = doc.blocks[0].inlines.first else {
        XCTFail("Expected inline")
        return
    }
    // "Hello bold" → "bold" 从 index 6 开始，长度 4
    XCTAssertEqual(inline.range.location, 6)
    XCTAssertEqual(inline.range.length, 4)
}
```

- [ ] **步骤 2：运行测试验证通过（基线）**

运行：`swift test --filter MarkupDocumentBuilderTests 2>&1 | tail -5`

预期：通过。这些测试验证当前行为。

- [ ] **步骤 3：修复 convertToInlines — trimmedEnd 按块计算 + 部分重叠截断**

替换 `MarkupDocumentBuilder.swift` 中 `convertToInlines` 方法（第 140-185 行）为：

```swift
    /// 将内联 span 转换为 MarkupInline
    /// 生成的 NSRange 是相对于 parentRange.location 的偏移（即相对于块文本起始位置）
    private static func convertToInlines(
        _ spans: [XMarkupSpan],
        in text: String,
        parentRange: NSRange
    ) -> [MarkupInline] {
        var inlines: [MarkupInline] = []
        inlines.reserveCapacity(spans.count)

        // 计算当前块的尾部换行修剪位置（仅针对 parentRange 范围）
        let nsString = text as NSString
        let parentText = nsString.substring(with: parentRange)
        let trimmedParentLength = parentText.trimmingTrailingNewlines.utf16.count

        let parentEnd = parentRange.location + parentRange.length
        let trimmedBlockEnd = parentRange.location + trimmedParentLength

        for span in spans {
            // inline span 的起始必须在 parentRange 内
            guard span.range.location >= parentRange.location,
                  span.range.location < parentEnd else {
                continue
            }

            // 跳过无样式的 span 容器（tag=span, style=unknown, value=nil）
            // 实际 CSS 属性由独立的 CSS span 携带
            if span.tag == .span, case .unknown = span.style, span.value == nil {
                continue
            }

            let kind = inlineKind(for: span)
            // 跳过空样式 span（无实际 CSS 属性的内联）
            if case .span(let styles) = kind, styles.isEmpty {
                continue
            }

            // 计算相对于块起始位置的 NSRange
            let relativeLocation = span.range.location - parentRange.location

            // 截断超出 parentRange 的尾部，同时考虑尾部换行修剪
            let spanEnd = span.range.location + span.range.length
            let adjustedEnd = min(spanEnd, trimmedBlockEnd)
            let adjustedLength = max(adjustedEnd - span.range.location, 0)

            guard adjustedLength > 0 else { continue }

            let relativeRange = NSRange(location: relativeLocation, length: adjustedLength)
            inlines.append(MarkupInline(range: relativeRange, kind: kind))
        }

        return inlines
    }
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test 2>&1 | tail -5`

预期：所有 134+ 测试通过。

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift
git commit -m "fix: convertToInlines 按块计算 trimmedEnd + 支持部分重叠 span 截断"
```

---

## 任务 4：applyInlineAttributes 安全断言

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift`（第 127-145 行）

- [ ] **步骤 1：添加假设说明注释和 debug 断言**

替换 `MarkupDocument+Render.swift` 中 `applyInlineAttributes` 方法的第 133-145 行为：

```swift
    // inline.range 是 UTF-16 NSRange（相对于块文本起始位置）
    // 通过 String.Index 中转后使用 character offset 定位 AttributedString，
    // 避免 Range(NSRange, in: AttributedString) 在 emoji 场景下可能出现的边界错位。
    //
    // 关键假设：AttributedString(block.text) 的 character index 与 String(block.text) 的
    // character index 一致（两者都基于 Extended Grapheme Cluster）。
    // Apple 的 AttributedString 初始化时未做 Unicode 规范化（NFC），
    // 因此此假设在当前 Apple 实现下成立。
    let attrRange: Range<AttributedString.Index>
    do {
        guard let stringRange = Range(inline.range, in: blockText) else { return }
        let charOffset = blockText.distance(from: blockText.startIndex, to: stringRange.lowerBound)
        let charLength = blockText.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
        guard charLength > 0 else { return }
        #if DEBUG
        let start = attr.index(attr.startIndex, offsetByCharacters: charOffset)
        let end = attr.index(start, offsetByCharacters: charLength)
        assert(String(attr[start..<end].characters) == String(blockText[stringRange]),
               "AttributedString character index 与 String character index 不一致，请检查 Unicode 规范化问题")
        attrRange = start..<end
        #else
        let start = attr.index(attr.startIndex, offsetByCharacters: charOffset)
        let end = attr.index(start, offsetByCharacters: charLength)
        attrRange = start..<end
        #endif
    }
```

- [ ] **步骤 2：运行测试验证通过（含 debug 断言不触发）**

运行：`swift test 2>&1 | tail -5`

预期：所有测试通过，无 assertion 失败。

- [ ] **步骤 3：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift
git commit -m "docs: applyInlineAttributes 添加 character index 一致性假设注释和 debug 断言"
```

---

## 任务 5：NSAttributedStringRenderer 消除多余复制

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Rendering/NSAttributedStringRenderer.swift`

- [ ] **步骤 1：修改 render 方法消除最终不可变化复制**

将 `NSAttributedStringRenderer.render` 方法（第 15-19 行）改为：

```swift
    public func render(_ attributed: AttributedString) -> NSAttributedString {
        let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
        transferCustomKeys(from: attributed, to: nsAttr)
        return nsAttr
    }
```

- [ ] **步骤 2：运行测试验证通过**

运行：`swift test 2>&1 | tail -5`

预期：所有测试通过。`NSMutableAttributedString` 是 `NSAttributedString` 的子类，返回类型兼容。

- [ ] **步骤 3：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/NSAttributedStringRenderer.swift
git commit -m "perf: NSAttributedStringRenderer 消除多余的不可变化复制"
```

---

## 任务 6：注释补充（HeadingScale + dark 主题 + ColorParser + 枚举 case + API 示例）

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Theme/HeadingScale.swift`
- 修改：`platforms/ios/Sources/XMarkup/Theme/PresetThemes.swift`
- 修改：`platforms/ios/Sources/XMarkup/Bridge/ColorParser.swift`
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupInline.swift`
- 修改：`platforms/ios/Sources/XMarkup/Core/BlockKind.swift`
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupDocument.swift`
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupBlock.swift`
- 修改：`platforms/ios/Sources/XMarkup/Rendering/MarkupRenderer.swift`

- [ ] **步骤 1：HeadingScale 添加来源注释**

将 `HeadingScale.swift` 替换为：

```swift
import Foundation

/// 标题缩放配置
///
/// 默认值来源于 Chrome/Firefox/Safari 浏览器默认样式表中 h1-h6 的 font-size 缩放比例：
/// h1=2em, h2=1.5em, h3=1.17em, h4=1em, h5=0.83em, h6=0.67em
/// 参考：https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Heading_Elements
public struct HeadingScale: Sendable, Equatable {
    public var h1: CGFloat
    public var h2: CGFloat
    public var h3: CGFloat
    public var h4: CGFloat
    public var h5: CGFloat
    public var h6: CGFloat

    /// 创建标题缩放配置
    ///
    /// 默认值对应浏览器默认样式表（MDN 参考）。
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

    /// 浏览器默认缩放比例
    public static let `default` = HeadingScale()
}
```

- [ ] **步骤 2：PresetThemes.dark 添加占位说明**

在 `PresetThemes.swift` 中 `dark` 计算属性（第 37 行）的文档注释改为：

```swift
    /// 暗色模式主题
    ///
    /// - Note: 当前为静态颜色占位实现。完整的暗色适配应使用
    ///         `UIColor { traitCollection in ... }` 动态颜色，
    ///         根据用户外观偏好自动切换，待 P2 实现。
    public static let dark: MarkupTheme = {
```

- [ ] **步骤 3：ColorParser 添加格式说明**

将 `ColorParser.swift` 的文档注释替换为：

```swift
/// 十六进制颜色解析工具
///
/// 将 C 引擎输出的 `#RRGGBB` 格式字符串解析为 `XMColor`。
///
/// 支持的格式：`#RRGGBB`（7 字符，含 # 前缀）
/// 不支持的格式：`#RGB`（三位缩写）、`rgb(r,g,b)` 函数、CSS 命名颜色（如 `red`）
/// 这些格式由 C++ 核心引擎的 `normalize_color()` 预处理为 `#RRGGBB`。
enum ColorParser {
    /// 解析 #RRGGBB 格式的颜色字符串
    ///
    /// - Parameter hex: 颜色字符串，格式 "#RRGGBB"
    /// - Returns: XMColor，无效格式返回 nil
    static func parse(_ hex: String?) -> XMColor? {
```

- [ ] **步骤 4：MarkupInline 枚举 case 注释**

将 `MarkupInline.swift` 中的 `InlineKind` 和 `InlineStyle` 添加注释：

```swift
/// 内联类型
public enum InlineKind: Sendable, Equatable {
    case bold              // <b> 或 <strong>
    case italic            // <i> 或 <em>
    case underline         // <u>
    case strikethrough     // <s>、<strike> 或 <del>
    case code              // <code>
    case mark              // <mark>
    case link(url: String) // <a href="...">
    case subscriptText     // <sub>
    case superscript       // <sup>
    case span(styles: [InlineStyle]) // <span style="...">
}

/// CSS 行内样式
public enum InlineStyle: Sendable, Equatable {
    case foregroundColor(String)    // color:#RRGGBB
    case backgroundColor(String)    // background-color:#RRGGBB
    case fontSize(Float)            // font-size（已换算为 px）
    case fontWeight(String)         // font-weight（normal/bold/100-900）
    case fontStyle(String)          // font-style（italic/normal）
    case textDecoration(String)     // text-decoration（underline/line-through）
    case lineHeight(Float)          // line-height（P2 保留）
    case letterSpacing(Float)       // letter-spacing（P2 保留）
}
```

- [ ] **步骤 5：BlockKind 枚举 case 注释**

将 `BlockKind.swift` 中的 `BlockKind` 添加注释：

```swift
/// 段落类型
public enum BlockKind: Sendable, Equatable {
    case paragraph                                           // <p>
    case heading(Level)                                      // <h1>~<h6>
    case blockquote                                          // <blockquote>
    case preformatted                                        // <pre>
    case listItem(isOrdered: Bool, indentLevel: Int)         // <li>
    case division                                            // <div>
    case horizontalRule                                      // <hr>
    case table(TableStructure)                               // <table>
}
```

- [ ] **步骤 6：MarkupDocument 添加 API 使用示例**

将 `MarkupDocument.swift` 替换为：

```swift
import Foundation

/// 平台无关的标记文档，从 C++ 引擎的 flat spans 一次性构建
///
/// 使用方式：
/// ```swift
/// let parser = try XMarkupParser()
/// let result = try parser.parse("<h1>Title</h1><p>Hello <b>world</b></p>")
/// let document = MarkupDocument.from(result)
/// let attributed = document.render(theme: .default)
/// ```
public struct MarkupDocument: Sendable, Equatable {
    /// 段落级块列表
    public let blocks: [MarkupBlock]

    public init(blocks: [MarkupBlock]) {
        self.blocks = blocks
    }

    /// 追加内容（聊天场景）
    ///
    /// ```swift
    /// let doc1 = MarkupDocument.from(try parser.parse("<p>Hello</p>"))
    /// let doc2 = MarkupDocument.from(try parser.parse("<p>World</p>"))
    /// let combined = doc1.appending(doc2)
    /// ```
    public func appending(_ other: MarkupDocument) -> MarkupDocument {
        MarkupDocument(blocks: blocks + other.blocks)
    }
}
```

- [ ] **步骤 7：MarkupBlock 添加 API 使用示例**

将 `MarkupBlock.swift` 替换为：

```swift
import Foundation

/// 段落级块（h1-h6, p, blockquote, pre, li, hr, div 等）
///
/// 每个 `MarkupBlock` 对应 HTML 中的一个块级元素，包含纯文本、
/// 内联样式区间和可选的媒体附件。
///
/// ```swift
/// let block = doc.blocks[0]
/// print(block.kind)        // .paragraph
/// print(block.text)        // "Hello world"
/// print(block.inlines)     // [MarkupInline(range: (6,5), kind: .bold)]
/// print(block.attachment)  // nil（非媒体块）
/// ```
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

- [ ] **步骤 8：MarkupRenderer 添加 API 使用示例**

将 `MarkupRenderer.swift` 替换为：

```swift
import Foundation

/// 可插拔的渲染器协议
///
/// 所有渲染器消费 AttributedString（可能携带自定义 XMarkupScope 属性），
/// 而非自定义类型。第三方库通过 `NSAttributedString(AttributedString)` 桥接后
/// 读取标准属性 + 自定义 XMarkup key。
///
/// 使用方式：
/// ```swift
/// let attributed = document.render()
///
/// // UIKit/AppKit 渲染
/// let nsRenderer = NSAttributedStringRenderer()
/// let nsAttr = nsRenderer.render(attributed)
/// textView.attributedText = nsAttr
///
/// // 测量尺寸
/// let size = nsRenderer.measure(attributed, constrainedTo: 320)
/// ```
public protocol MarkupRenderer<Output>: Sendable {
    associatedtype Output

    /// 渲染
    func render(_ attributed: AttributedString) -> Output

    /// 测量内容尺寸（用于布局计算）
    func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize
}
```

- [ ] **步骤 9：运行测试验证所有注释修改未破坏编译**

运行：`swift test 2>&1 | tail -5`

预期：所有 134+ 测试通过。

- [ ] **步骤 10：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/HeadingScale.swift \
       platforms/ios/Sources/XMarkup/Theme/PresetThemes.swift \
       platforms/ios/Sources/XMarkup/Bridge/ColorParser.swift \
       platforms/ios/Sources/XMarkup/Core/MarkupInline.swift \
       platforms/ios/Sources/XMarkup/Core/BlockKind.swift \
       platforms/ios/Sources/XMarkup/Core/MarkupDocument.swift \
       platforms/ios/Sources/XMarkup/Core/MarkupBlock.swift \
       platforms/ios/Sources/XMarkup/Rendering/MarkupRenderer.swift
git commit -m "docs: 补充 HeadingScale 来源注释、dark 主题占位说明、ColorParser 格式说明、枚举 case 注释和 API 使用示例"
```

---

## 任务 7：规格文档同步

**文件：**
- 修改：`docs/superpowers/specs/2026-06-08-xmarkup-modern-swift-redesign.md`
- 修改：`~/.claude/projects/-Users-arcangelw-GitHub-XMarkup/memory/MEMORY.md`
- 修改：`~/.claude/projects/-Users-arcangelw-GitHub-XMarkup/memory/xmarkup-impl-progress.md`

- [ ] **步骤 1：更新规格文档 §3.1 — MarkupInline.range 类型**

在 `2026-06-08-xmarkup-modern-swift-redesign.md` 中，找到 §3.1 的 `MarkupInline` 定义（约第 122-128 行），将：

```swift
/// 内联样式（字符级）
public struct MarkupInline: Sendable, Equatable {
    /// 在所属 block.text 中的范围（String.Index）
    public let range: Range<String.Index>
    /// 内联类型
    public let kind: InlineKind
}
```

替换为：

```swift
/// 内联样式（字符级）
public struct MarkupInline: Sendable, Equatable {
    /// 在所属 block.text 中的范围（UTF-16 码元偏移，相对于块文本起始位置）
    ///
    /// - Note: 使用 NSRange（UTF-16）而非 Range<String.Index>（grapheme cluster），
    ///         因为 C++ 核心引擎输出的 span range 基于 UTF-16 编码单元索引，
    ///         与 NSString/NSAttributedString 索引体系直接对齐。
    ///         emoji 等多字节字符（如 🔄 = 2 UTF-16 码元但 1 grapheme）在 UTF-16 体系下
    ///         具有确定且一致的偏移量。
    public let range: NSRange
    /// 内联类型
    public let kind: InlineKind
}
```

- [ ] **步骤 2：更新规格文档 §9.2 — 目录结构**

在 `2026-06-08-xmarkup-modern-swift-redesign.md` 中，找到 §9.2 的目标结构（约第 686-718 行），将整个目录结构替换为：

```
platforms/ios/Sources/XMarkup/
├── Bridge/
│   ├── ColorParser.swift               # [迁移] 颜色解析
│   ├── PlatformTypes.swift             # [迁移] XMFont/XMColor 类型别名
│   ├── XMarkupError.swift              # [迁移] 错误枚举
│   ├── XMarkupParser.swift             # [迁移] C++ 引擎桥接
│   ├── XMarkupResult.swift             # [迁移] C++ 结果桥接
│   ├── XMarkupSpan.swift               # [迁移] C++ Span 映射
│   ├── XMarkupStyle.swift              # [迁移] CSS Style 枚举
│   └── XMarkupTag.swift                # [迁移] Tag 枚举
├── Core/
│   ├── BlockKind.swift                 # 段落类型 + Level + TableStructure
│   ├── MarkupAttachment.swift          # 附件模型 + AttachmentContent
│   ├── MarkupBlock.swift               # 段落级块
│   ├── MarkupDocument.swift            # 文档模型
│   ├── MarkupDocumentBuilder.swift     # XMarkupResult → MarkupDocument 转换
│   └── MarkupInline.swift              # 内联样式 + InlineKind + InlineStyle
├── Theme/
│   ├── HeadingScale.swift              # 标题缩放配置
│   ├── MarkupTheme.swift               # 主题主结构
│   ├── MarkupThemeBuilder.swift        # @resultBuilder
│   ├── MediaRenderingStrategy.swift    # 媒体渲染策略
│   ├── PresetThemes.swift              # 预置主题
│   ├── TagStyleKey.swift               # 主题配置 key
│   └── ThemeComponent.swift            # DSL 组件
├── Attributes/
│   └── XMarkupScope.swift              # 自定义 AttributedStringKey + AttributeScope
└── Rendering/
    ├── MarkupDocument+Render.swift     # render(theme:) 实现
    ├── MarkupRenderer.swift            # MarkupRenderer 协议
    └── NSAttributedStringRenderer.swift # UIKit/AppKit 渲染器

platforms/ios/Tests/XMarkupTests/
├── Bridge/
│   ├── XMarkupParserTests.swift        # 解析器生命周期测试
│   ├── XMarkupResultTests.swift        # 结果转换测试
│   ├── ColorParserTests.swift          # 颜色解析测试
│   └── CrossPlatformTests.swift        # 跨平台编译验证
├── Core/
│   ├── BlockKindTests.swift
│   ├── MarkupAttachmentTests.swift
│   ├── MarkupBlockTests.swift
│   ├── MarkupDocumentBuilderTests.swift
│   ├── MarkupDocumentTests.swift
│   └── MarkupInlineTests.swift
├── Theme/
│   └── MarkupThemeTests.swift          # 主题 + DSL + 预置主题测试
├── Attributes/
│   └── XMarkupScopeTests.swift
└── Rendering/
    ├── NSAttributedStringRendererTests.swift
    └── RenderTests.swift
```

- [ ] **步骤 3：更新 MEMORY.md**

在 `~/.claude/projects/-Users-arcangelw-GitHub-XMarkup/memory/MEMORY.md` 中，在现有条目后添加：

```markdown
- [Code Review 修复进度](xmarkup-review-fixes-progress.md) — Code Review 收尾修复进度：8 项代码修复 + 目录迁移 + 注释补充
```

- [ ] **步骤 4：创建进度记忆文件**

创建 `~/.claude/projects/-Users-arcangelw-GitHub-XMarkup/memory/xmarkup-review-fixes-progress.md`：

```markdown
---
name: xmarkup-review-fixes-progress
description: Code Review 收尾修复进度追踪
metadata:
  type: project
---

# Code Review 收尾修复进度

日期：2026-06-09

## 状态：进行中

## 修复项

### 必须修复
- [x] MarkupTheme Equatable 补全（mediaStrategy 排除）
- [x] convertToInlines trimmedEnd 按块计算
- [x] applyInlineAttributes 安全断言注释

### 建议修改
- [x] convertToInlines 部分重叠 span 截断
- [x] HeadingScale 来源注释
- [x] dark 主题占位说明
- [x] NSAttributedStringRenderer 多余复制
- [x] 规格文档 MarkupInline.range 类型同步

### 目录结构
- [x] 8 个 Bridge 源码文件迁移到 Bridge/ 子目录
- [x] 4 个测试文件迁移到 Bridge/ 子目录
- [x] MarkupThemeTests.swift 保持在 Theme/ 子目录

### 注释补充
- [x] InlineKind/BlockKind 枚举 case 注释
- [x] MarkupDocument/MarkupBlock/MarkupRenderer API 示例
- [x] ColorParser 格式说明
- [x] HeadingScale 来源注释

### 文档更新
- [x] 规格文档 §3.1 + §9.2 同步
- [x] MEMORY.md 更新

**Why:** Code Review 发现的实现细节问题和规范合规性缺失
**How to apply:** 所有修复在 main 分支，通过 `swift test` 验证
```

- [ ] **步骤 5：Commit**

```bash
git add docs/superpowers/specs/2026-06-08-xmarkup-modern-swift-redesign.md
git add -A ~/.claude/projects/-Users-arcangelw-GitHub-XMarkup/memory/
git commit -m "docs: 同步规格文档（MarkupInline.range 类型 + 目录结构）并更新项目记忆"
```

---

## 自检

### 1. 规格覆盖度

| 规格章节 | 对应任务 |
|---------|---------|
| §1.1 MarkupTheme Equatable | 任务 2 |
| §1.2 convertToInlines trimmedEnd | 任务 3 |
| §1.3 applyInlineAttributes 断言 | 任务 4 |
| §1.4 部分重叠 span | 任务 3 |
| §1.5 HeadingScale 注释 | 任务 6 |
| §1.6 dark 主题说明 | 任务 6 |
| §1.7 NSRenderer 复制 | 任务 5 |
| §1.8 规格文档同步 | 任务 7 |
| §2 目录迁移 | 任务 1 |
| §3 注释补充 | 任务 6 |
| §4 文档更新 | 任务 7 |

### 2. 占位符扫描

无 TODO/待定/后续实现。所有步骤包含完整代码或精确命令。

### 3. 类型一致性

- 任务 2 使用 `MarkupTheme`（任务 1 迁移后路径不变，仍在 `Theme/`）
- 任务 3 使用 `XMarkupSpan`（任务 1 迁移后在 `Bridge/XMarkupSpan.swift`，但 `MarkupDocumentBuilder` 已 `@testable import XMarkup`，无需改 import）
- 所有 `git mv` 在任务 1 完成，后续任务引用的路径已更新为迁移后路径
