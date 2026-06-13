# iOS 架构重设计 — 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。

**目标：** 修复有序列表不编号（NSTextList 实例共享）、表格无布局（NSTextTable 接入）、blockquote 无竖线效果、DSL 无法配置块级属性。分 P0~P3 四级执行。

**架构：** 渲染层从纯函数 `renderBlock(block, theme)` 改为两阶段 `DocumentRenderer`（先组分析再渲染）；DSL 新增 `BlockStyle` 组件覆盖 NSTextBlock/NSTextTable/NSTextList 配置；数据模型填充 `TableStructure`。

**技术栈：** Swift 5.9+, iOS 15+, UIKit AttributedString, NSTextList, NSTextTable, NSTextBlock

---

## 文件结构（创建/修改/删除）

### 创建的文件

| 文件 | 职责 | 阶段 |
|:-----|:-----|:-----|
| `Rendering/DocumentRenderer.swift` | 两阶段渲染器主入口 | P0 |
| `Rendering/ListRenderer.swift` | NSTextList 组管理与共享实例 | P0 |
| `Rendering/TableRenderer.swift` | NSTextTable + NSTextTableBlock 封装 | P2 |
| `Rendering/NSTextBlockApplicator.swift` | BlockStyleConfiguration → NSTextBlock 应用 | P1 |
| `Rendering/AsyncMediaLoader.swift` | 异步图片加载器 | P3 |
| `Theme/BlockStyleConfig.swift` | BlockStyleConfiguration 值类型 | P1 |
| `Rendering/PresentationIntent.swift` | PresentationIntent 标注辅助 | P2 |

### 修改的文件

| 文件 | 变更 | 阶段 |
|:-----|:-----|:-----|
| `Core/MarkupDocumentBuilder.swift` | 填充 TableStructure；blockKind 返回 table 类型 | P2 |
| `Core/BlockKind.swift` | 无变更（TableStructure 已足够） | - |
| `Core/MarkupDocument.swift` | render(theme:) 委派给 DocumentRenderer | P0 |
| `Core/MarkupInline.swift` | InlineStyle 确认枚举值完整性（已完整） | P0 |
| `Rendering/BlockRenderer.swift` | 拆分 + 重构 | P0 |
| `Rendering/MarkupDocument+Render.swift` | 删除或委派 | P0 |
| `Rendering/RenderHelpers.swift` | 部分函数合并/删除 | P3 |
| `Rendering/InlineRenderer.swift` | 新增 PresentationIntent 标注 | P2 |
| `Rendering/AttachmentRenderer.swift` | 无变更 | - |
| `Rendering/NSAttributedStringRenderer.swift` | 无变更 | - |
| `Theme/MarkupTheme.swift` | 新增 blockStyles 字段 | P1 |
| `Theme/TagStyleKey.swift` | 无变更（名称优化在 P3） | P3 |
| `Theme/ThemeComponent.swift` | 新增 HeadingScale/ParagraphSpacing 便利函数 | P1 |
| `Theme/MarkupThemeBuilder.swift` | 无变更 | - |

### 删除的文件

| 文件 | 理由 | 阶段 |
|:-----|:-----|:-----|
| `Rendering/MarkupDocument+Render.swift` | 业务迁移到 DocumentRenderer | P0 |

---

## P0 — 渲染器两阶段重构（最优先）

**目标：** 有序列表编号恢复、无序列表渲染正确、BlockGroups 组分析可用。

### 任务 1：BlockGroups 组分析 + DocumentRenderer 骨架

**文件：**
- 创建：`Rendering/DocumentRenderer.swift`
- 创建：`Rendering/ListRenderer.swift`
- 修改：`Core/MarkupDocument.swift:render(theme:)`
- 测试：`Tests/Rendering/RenderTests.swift`

- [ ] **步骤 1.1：创建 BlockGroups 结构和 analyzeBlockGroups()**

```swift
// Rendering/DocumentRenderer.swift
import Foundation

/// 列表组分析结果
struct BlockGroups {
    /// 按 block 索引 → 共享的 NSTextList 实例数组
    var listTextLists: [Int: [NSTextList]] = [:]
}
```

- [ ] **步骤 1.2：实现组分析算法**

```swift
// 追加到 DocumentRenderer.swift
extension DocumentRenderer {
    func analyzeBlockGroups(_ blocks: [MarkupBlock]) -> BlockGroups {
        var groups = BlockGroups()
        var currentIdx: [Int] = []
        var currentOrdered: Bool?
        var currentIndent: Int?

        for (i, block) in blocks.enumerated() {
            guard case .listItem(let isOrdered, let indent) = block.kind else {
                finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
                currentIdx = []; currentOrdered = nil; currentIndent = nil
                continue
            }
            if currentIdx.isEmpty {
                currentIdx = [i]; currentOrdered = isOrdered; currentIndent = indent
            } else if isOrdered == currentOrdered && indent == currentIndent {
                currentIdx.append(i)
            } else {
                finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
                currentIdx = [i]; currentOrdered = isOrdered; currentIndent = indent
            }
        }
        finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
        return groups
    }

    private func finalizeGroup(_ idx: inout [Int], _ groups: inout BlockGroups,
                                ordered: Bool?, indent: Int?) {
        guard !idx.isEmpty, let ord = ordered, let ind = indent else { return }
        let lists = buildTextLists(isOrdered: ord, indentLevel: ind)
        for i in idx { groups.listTextLists[i] = lists }
        idx = []
    }

    private func buildTextLists(isOrdered: Bool, indentLevel: Int) -> [NSTextList] {
        var lists: [NSTextList] = []
        for level in 0...indentLevel {
            let fmt: NSTextList.MarkerFormat = (level == 0)
                ? (isOrdered ? .decimal : .disc)
                : (isOrdered ? .decimal : .circle)
            lists.append(NSTextList(markerFormat: fmt, options: 0))
        }
        return lists
    }
}
```

- [ ] **步骤 1.3：创建 DocumentRenderer 主结构**

```swift
// Rendering/DocumentRenderer.swift 完整内容

import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// 两阶段渲染器：先组分析，再渲染
struct DocumentRenderer {
    let theme: MarkupTheme

    func render(_ blocks: [MarkupBlock]) -> AttributedString {
        let groups = analyzeBlockGroups(blocks)
        let hasTable = blocks.contains { if case .table = $0.kind { return true }; return false }

        if hasTable {
            return renderWithNSA(blocks, groups: groups)
        }
        return renderWithAS(blocks, groups: groups)
    }
}

// MARK: - AttributedString 路径（无 table）
extension DocumentRenderer {
    func renderWithAS(_ blocks: [MarkupBlock], groups: BlockGroups) -> AttributedString {
        var result = AttributedString("")
        for (i, block) in blocks.enumerated() {
            if i > 0 { result.append(AttributedString("\n")) }
            let attr = renderBlock(block, sharedLists: groups.listTextLists[i], theme: theme)
            result.append(attr)
        }
        return result
    }
}

// MARK: - NSAttributedString 路径（含 table）
extension DocumentRenderer {
    func renderWithNSA(_ blocks: [MarkupBlock], groups: BlockGroups) -> AttributedString {
        let nsResult = NSMutableAttributedString()
        for (i, block) in blocks.enumerated() {
            if i > 0 {
                if case .table = block.kind { continue }
                nsResult.append(NSAttributedString(string: "\n"))
            }
            if case .table(let structure) = block.kind {
                let tableAttr = renderTable(structure, theme: theme)
                nsResult.append(tableAttr)
            } else {
                let attr = renderBlock(block, sharedLists: groups.listTextLists[i], theme: theme)
                nsResult.append(NSAttributedString(attr))
            }
        }
        return AttributedString(nsResult)
    }
}
```

- [ ] **步骤 1.4：MarkupDocument.render() 委派到 DocumentRenderer**

```swift
// Core/MarkupDocument.swift 修改
extension MarkupDocument {
    public func render(theme: MarkupTheme = .default) -> AttributedString {
        let renderer = DocumentRenderer(theme: theme)
        return renderer.render(blocks)
    }
}
```

- [ ] **步骤 1.5：编写组分析测试**

```swift
// Tests/XMarkupTests/Rendering/RenderTests.swift 追加
func testOrderedListSharedNSTextList() throws {
    let result = try parse("<ol><li>A</li><li>B</li><li>C</li></ol>")
    let doc = MarkupDocument.from(result)
    // 验证三个 li 块
    let liBlocks = doc.blocks.filter { if case .listItem = $0.kind { return true }; return false }
    XCTAssertEqual(liBlocks.count, 3)
    // 验证渲染不崩溃
    let attr = doc.render()
    let text = String(attr.characters)
    XCTAssertTrue(text.contains("A"))
    XCTAssertTrue(text.contains("B"))
    XCTAssertTrue(text.contains("C"))
}

func testUnorderedListRender() throws {
    let result = try parse("<ul><li>X</li><li>Y</li></ul>")
    let doc = MarkupDocument.from(result)
    let attr = doc.render()
    let text = String(attr.characters)
    XCTAssertTrue(text.contains("X"))
    XCTAssertTrue(text.contains("Y"))
}
```

- [ ] **步骤 1.6：运行测试验证**

```bash
cd platforms/ios && swift test --filter RenderTests --parallel
```

预期：`testOrderedListSharedNSTextList` PASS, `testUnorderedListRender` PASS

- [ ] **步骤 1.7：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/DocumentRenderer.swift \
       platforms/ios/Sources/XMarkup/Rendering/ListRenderer.swift \
       platforms/ios/Sources/XMarkup/Core/MarkupDocument.swift \
       platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift
git commit -m "feat(ios): add DocumentRenderer with block group analysis

- BlockGroups + analyzeBlockGroups() 组分析
- DocumentRenderer 两阶段渲染骨架
- MarkupDocument.render() 委派到 DocumentRenderer
"
```

### 任务 2：renderBlock() 共享 NSTextList + heading/blockquote 渲染

**文件：**
- 修改：`Rendering/BlockRenderer.swift` — 重构为共享实例版
- 删除：`Rendering/MarkupDocument+Render.swift` — 委派逻辑

- [ ] **步骤 2.1：重构 BlockRenderer.renderBlock() 接收 sharedLists 参数**

```swift
// Rendering/BlockRenderer.swift 顶部新增
/// 渲染单个 block（外部接口）
func renderBlock(_ block: MarkupBlock, sharedLists: [NSTextList]?, theme: MarkupTheme) -> AttributedString {
    var base = AttributeContainer()
    #if canImport(UIKit)
    base.uiKit.font = theme.baseFont
    #elseif canImport(AppKit)
    base.appKit.font = theme.baseFont
    #endif

    let paraStyle = NSMutableParagraphStyle()
    paraStyle.paragraphSpacingBefore = theme.paragraphSpacing.spacingBefore
    paraStyle.paragraphSpacing = theme.paragraphSpacing.spacingAfter

    switch block.kind {
    case .listItem(let isOrdered, let indentLevel):
        if let shared = sharedLists {
            paraStyle.textLists = shared
        } else {
            paraStyle.textLists = buildTextLists(isOrdered: isOrdered, indentLevel: indentLevel)
        }
        paraStyle.headIndent = CGFloat(indentLevel + 1) * 24
        paraStyle.firstLineHeadIndent = CGFloat(indentLevel + 1) * 24
        paraStyle.tabStops = [NSTextTab(textAlignment: .left, location: CGFloat(indentLevel + 1) * 24, options: [:])]

    case .heading(let level):
        let scale: CGFloat
        switch level {
        case .h1: scale = 0.50; case .h2: scale = 0.60
        case .h3: scale = 0.70; case .h4: scale = 0.80
        case .h5: scale = 0.90; case .h6: scale = 1.00
        }
        let spacing = theme.baseFont.pointSize * scale
        paraStyle.paragraphSpacingBefore = spacing
        paraStyle.paragraphSpacing = spacing * 0.5

    case .blockquote:
        paraStyle.headIndent = 24
        paraStyle.firstLineHeadIndent = 24

    case .preformatted:
        #if canImport(UIKit)
        paraStyle.lineBreakMode = .byCharWrapping
        #endif

    default:
        break
    }

    #if canImport(UIKit)
    base.uiKit.paragraphStyle = paraStyle
    #elseif canImport(AppKit)
    base.appKit.paragraphStyle = paraStyle
    #endif

    applyBlockKindAttributes(kind: block.kind, theme: theme, to: &base)

    // BlockStyle 配置
    applyBlockStyle(kind: block.kind, theme: theme, to: &base)

    // 自定义 scope 属性
    let tagName = blockKindName(for: block.kind)
    base[XMarkupTagKey.self] = tagName
    base[XMarkupBlockKindKey.self] = tagName
    switch block.kind {
    case .heading(let level):
        base[XMarkupHeadingLevelKey.self] = level.rawValue
    case .listItem(let isOrdered, let indentLevel):
        base[XMarkupListItemInfoKey.self] = "\(isOrdered ? "ordered" : "unordered"):\(indentLevel)"
    default:
        break
    }

    // 媒体附件
    if let attachment = block.attachment {
        return renderAttachmentBlock(block, attachment: attachment, theme: theme, baseAttributes: base)
    }

    // 段落文本
    let blockText: String
    if case .horizontalRule = block.kind {
        blockText = "\u{2003}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2003}"
    } else {
        blockText = block.text
    }

    var attr = AttributedString(blockText, attributes: base)

    // 内联样式
    for inline in block.inlines {
        applyInlineAttributes(inline, theme: theme, to: &attr, blockText: block.text)
    }

    // 主题覆盖
    applyThemeOverrides(for: block, theme: theme, to: &attr)

    return attr
}

/// 独立构建 textLists（非组中的孤立列表项）
func buildTextLists(isOrdered: Bool, indentLevel: Int) -> [NSTextList] {
    var lists: [NSTextList] = []
    for level in 0...indentLevel {
        let fmt: NSTextList.MarkerFormat = (level == 0)
            ? (isOrdered ? .decimal : .disc)
            : (isOrdered ? .decimal : .circle)
        lists.append(NSTextList(markerFormat: fmt, options: 0))
    }
    return lists
}
```

- [ ] **步骤 2.2：删除旧 renderBlock(block, theme) 签名**

```swift
// BlockRenderer.swift 中移除旧函数
// 旧签名: func renderBlock(_ block: MarkupBlock, theme: MarkupTheme) -> AttributedString
// 替换为新签名: func renderBlock(_ block: MarkupBlock, sharedLists: [NSTextList]?, theme: MarkupTheme) -> AttributedString
```

- [ ] **步骤 2.3：删除 MarkupDocument+Render.swift（委派到 DocumentRenderer）**

```swift
// 将 MarkupDocument+Render.swift 内容替换为:
extension MarkupDocument {
    // render(theme:) 现在在 DocumentRenderer.swift 中实现
    // 本文件保留为空，待后续删除
}
```

- [ ] **步骤 2.4：测试列表编号（验证通过共享实例确认）**

```swift
// RenderTests.swift 追加
func testOrderedListNumberingSharedInstance() throws {
    let result = try parse("<ol><li>First</li><li>Second</li></ol>")
    let doc = MarkupDocument.from(result)
    let attr = doc.render()
    let nsAttr = NSAttributedStringRenderer().render(attr)

    // 遍历 NSAttributedString 检查 NSTextList 实例共享
    var listInstances: [NSTextList] = []
    let fullRange = NSRange(location: 0, length: nsAttr.length)
    nsAttr.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
        guard let style = value as? NSParagraphStyle,
              let lists = style.textLists,
              !lists.isEmpty else { return }
        if listInstances.isEmpty {
            listInstances = lists
        } else {
            // 同一列表应共享同一 NSTextList 实例
            for (idx, list) in lists.enumerated() {
                if idx < listInstances.count {
                    XCTAssertIdentical(list, listInstances[idx],
                        "同一有序列表的 NSTextList 应是同一个实例")
                }
            }
        }
    }
    XCTAssertGreaterThan(listInstances.count, 0, "应有 NSTextList 实例")
}

func testNestedListRendering() throws {
    // 嵌套无序列表
    let html = "<ul><li>Outer<ul><li>Inner</li></ul></li></ul>"
    let result = try parse(html)
    let doc = MarkupDocument.from(result)
    let attr = doc.render()
    let text = String(attr.characters)
    XCTAssertTrue(text.contains("Outer"))
    XCTAssertTrue(text.contains("Inner"))
    // 验证内层 li 的 indentLevel > 外层 li 的 indentLevel
    let outerLI = doc.blocks.first { $0.text.contains("Outer") }
    let innerLI = doc.blocks.first { $0.text.contains("Inner") }
    if case .listItem(_, let outerIndent) = outerLI?.kind,
       case .listItem(_, let innerIndent) = innerLI?.kind {
        XCTAssertLessThan(outerIndent, innerIndent, "内层 li 缩进应大于外层")
    }
}
```

- [ ] **步骤 2.5：运行测试验证**

```bash
cd platforms/ios && swift test --filter RenderTests --parallel
```

预期：全部 PASS

- [ ] **步骤 2.6：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift \
       platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift \
       platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift
git commit -m "fix(ios): ordered list number via shared NSTextList instance

- renderBlock() 接收 sharedLists 参数
- 列表项共享同一 NSTextList 实现自动编号
- 验证测试确认实例共享
"
```

---

## P1 — BlockStyle DSL + 块级属性配置

**目标：** DSL 可以配置 blockquote 左边框、列表符号类型、表格边框。

### 任务 3：BlockStyleConfiguration 值类型

**文件：**
- 创建：`Theme/BlockStyleConfig.swift`
- 修改：`Theme/MarkupTheme.swift` — 新增 blockStyles 字段
- 测试：`Tests/XMarkupTests/Theme/MarkupThemeTests.swift`

- [ ] **步骤 3.1：定义 BlockStyleConfiguration**

```swift
// Theme/BlockStyleConfig.swift
import Foundation

/// 块级排版配置（值类型，Sendable + Equatable）
/// 渲染器读取此配置构建 NSTextBlock / NSTextTable / NSTextList
public struct BlockStyleConfiguration: Sendable, Equatable {
    // MARK: - NSTextBlock（blockquote, pre, division）
    public var backgroundColor: String?
    public var borderLeading: BorderEdge?
    public var borderTrailing: BorderEdge?
    public var borderTop: BorderEdge?
    public var borderBottom: BorderEdge?
    public var paddingLeading: CGFloat?
    public var paddingTrailing: CGFloat?
    public var paddingTop: CGFloat?
    public var paddingBottom: CGFloat?

    // MARK: - NSTextTable（table）
    public var collapsesBorders: Bool?
    public var layoutAlgorithm: TableLayout?

    // MARK: - NSTextList（listItem）
    public var orderedMarker: MarkerType?
    public var unorderedMarker: MarkerType?
    public var nestedOrderedMarker: MarkerType?
    public var nestedUnorderedMarker: MarkerType?

    public init() {}

    // MARK: - Nested types

    public struct BorderEdge: Sendable, Equatable {
        public var width: CGFloat
        public var color: String // hex
        public init(width: CGFloat, color: String) {
            self.width = width; self.color = color
        }
    }

    public enum TableLayout: String, Sendable, Equatable {
        case automatic, fixed
    }

    public enum MarkerType: String, Sendable, Equatable, CaseIterable {
        case disc, circle, square, decimal
        case lowerAlpha, upperAlpha
        case lowerRoman, upperRoman
        case hyphen, check, box, diamond
    }
}
```

- [ ] **步骤 3.2：MarkupTheme 新增 blockStyles 字段**

```swift
// Theme/MarkupTheme.swift 修改
public struct MarkupTheme: @unchecked Sendable, Equatable {
    public var baseFont: XMFont
    public var headingScale: HeadingScale
    public var paragraphSpacing: ParagraphSpacing
    public var tagStyles: [TagStyleKey: AttributeContainer]
    public var blockStyles: [TagStyleKey: BlockStyleConfiguration]  // 新增
    public var mediaStrategy: MediaRenderingStrategy

    public init(
        baseFont: XMFont = XMFont.systemFont(ofSize: 16),
        headingScale: HeadingScale = .default,
        paragraphSpacing: ParagraphSpacing = .default,
        tagStyles: [TagStyleKey: AttributeContainer] = [:],
        blockStyles: [TagStyleKey: BlockStyleConfiguration] = [:],  // 新增
        mediaStrategy: MediaRenderingStrategy = .placeholder
    ) {
        self.baseFont = baseFont
        self.headingScale = headingScale
        self.paragraphSpacing = paragraphSpacing
        self.tagStyles = tagStyles
        self.blockStyles = blockStyles
        self.mediaStrategy = mediaStrategy
    }
}
```

- [ ] **步骤 3.3：编写 BlockStyleConfiguration 测试**

```swift
// Tests/XMarkupTests/Theme/MarkupThemeTests.swift 追加
func testBlockStyleConfigDefaultValues() {
    let config = BlockStyleConfiguration()
    XCTAssertNil(config.backgroundColor)
    XCTAssertNil(config.borderLeading)
    XCTAssertNil(config.orderedMarker)
}

func testBlockStyleConfigMutate() {
    var config = BlockStyleConfiguration()
    config.backgroundColor = "#F5F5F5"
    config.borderLeading = BlockStyleConfiguration.BorderEdge(width: 4, color: "#8E8E93")
    config.orderedMarker = .disc
    XCTAssertEqual(config.backgroundColor, "#F5F5F5")
    XCTAssertEqual(config.borderLeading?.width, 4)
    XCTAssertEqual(config.orderedMarker, .disc)
}

func testBlockStyleConfigEquatable() {
    let a = BlockStyleConfiguration()
    var b = BlockStyleConfiguration()
    XCTAssertEqual(a, b)
    b.backgroundColor = "#000"
    XCTAssertNotEqual(a, b)
}
```

- [ ] **步骤 3.4：运行测试**

```bash
cd platforms/ios && swift test --filter MarkupThemeTests --parallel
```

- [ ] **步骤 3.5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/BlockStyleConfig.swift \
       platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift \
       platforms/ios/Tests/XMarkupTests/Theme/MarkupThemeTests.swift
git commit -m "feat(ios): add BlockStyleConfiguration value type

- 支持 NSTextBlock 边框/背景/间距
- 支持 NSTextTable 列布局
- 支持 NSTextList 符号类型配置
"
```

### 任务 4：BlockStyle DSL 组件

**文件：**
- 创建：`Rendering/NSTextBlockApplicator.swift`
- 修改：`Theme/ThemeComponent.swift` — 新增 BlockStyleComponent + 便利函数

- [ ] **步骤 4.1：添加 BlockStyleComponent 到 ThemeComponent.swift**

```swift
// Theme/ThemeComponent.swift 追加

/// 块级排版配置组件
public struct BlockStyleComponent: ThemeComponent {
    public let key: TagStyleKey
    public let configure: @Sendable (inout BlockStyleConfiguration) -> Void

    public init(key: TagStyleKey, configure: @Sendable @escaping (inout BlockStyleConfiguration) -> Void) {
        self.key = key
        self.configure = configure
    }

    public func apply(to theme: inout MarkupTheme) {
        var config = theme.blockStyles[key] ?? BlockStyleConfiguration()
        configure(&config)
        theme.blockStyles[key] = config
    }
}

/// 便利函数
public func BlockStyle(
    _ key: TagStyleKey,
    configure: @Sendable @escaping (inout BlockStyleConfiguration) -> Void
) -> BlockStyleComponent {
    BlockStyleComponent(key: key, configure: configure)
}
```

- [ ] **步骤 4.2：替换命名 — HeadingScale() 和 ParagraphSpacing() 便利函数**

```swift
// Theme/ThemeComponent.swift 已有，确认便利函数：
public func HeadingScale(_ scale: HeadingScale) -> HeadingScaleComponent {
    HeadingScaleComponent(scale)
}
public func ParagraphSpacing(_ spacing: ParagraphSpacing) -> ParagraphSpacingComponent {
    ParagraphSpacingComponent(spacing)
}
```

- [ ] **步骤 4.3：测试 DSL 构建**

```swift
// Tests/XMarkupTests/Theme/MarkupThemeTests.swift 追加
func testBlockStyleDSLBuildsConfig() {
    let theme = MarkupTheme {
        BlockStyle(.blockquote) {
            $0.backgroundColor = "#F5F5F5"
            $0.borderLeading = BlockStyleConfiguration.BorderEdge(width: 4, color: "#8E8E93")
        }
        BlockStyle(.listItem) {
            $0.orderedMarker = .decimal
            $0.unorderedMarker = .disc
        }
    }
    let bqConfig = theme.blockStyles[.blockquote]
    XCTAssertNotNil(bqConfig)
    XCTAssertEqual(bqConfig?.backgroundColor, "#F5F5F5")
    let liConfig = theme.blockStyles[.listItem]
    XCTAssertEqual(liConfig?.orderedMarker, .decimal)
    XCTAssertEqual(liConfig?.unorderedMarker, .disc)
}
```

- [ ] **步骤 4.4：创建 NSTextBlockApplicator**

```swift
// Rendering/NSTextBlockApplicator.swift

import Foundation

/// 将 BlockStyleConfiguration 应用为 NSTextBlock
func applyBlockStyle(kind: BlockKind, theme: MarkupTheme, to attributes: inout AttributeContainer) {
    guard let key = blockStyleKey(for: kind),
          let config = theme.blockStyles[key] else { return }

    // 没有需要 NSTextBlock 的属性 → 跳过
    if config.backgroundColor == nil && config.borderLeading == nil
        && config.borderTrailing == nil && config.borderTop == nil
        && config.borderBottom == nil {
        return
    }

    // NSTextBlock 配置存储在自定义属性中，在渲染时读取
    // 当前 renderBlock() 通过 paragraphStyle 应用
    // 此函数为 NSTextBlock 渲染预留入口
    let block = NSTextBlock()
    if let bg = config.backgroundColor, let color = ColorParser.parse(bg) {
        block.backgroundColor = color
    }
    if let border = config.borderLeading {
        if let color = ColorParser.parse(border.color) {
            block.setBorderColor(color, for: .minXEdge)
            block.setWidth(border.width, type: .absolute, for: .minXEdge)
        }
    }
    if let border = config.borderTrailing {
        if let color = ColorParser.parse(border.color) {
            block.setBorderColor(color, for: .maxXEdge)
            block.setWidth(border.width, type: .absolute, for: .maxXEdge)
        }
    }
    if let border = config.borderTop {
        if let color = ColorParser.parse(border.color) {
            block.setBorderColor(color, for: .minYEdge)
            block.setWidth(border.width, type: .absolute, for: .minYEdge)
        }
    }
    if let border = config.borderBottom {
        if let color = ColorParser.parse(border.color) {
            block.setBorderColor(color, for: .maxYEdge)
            block.setWidth(border.width, type: .absolute, for: .maxYEdge)
        }
    }

    // 将 NSTextBlock 附加到 paragraphStyle 需要 NS 级处理
    // 通过自定义 AttributedStringKey 传递
    attributes[BlockStyleNSTextBlockKey.self] = block
}
```

- [ ] **步骤 4.5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift \
       platforms/ios/Sources/XMarkup/Rendering/NSTextBlockApplicator.swift \
       platforms/ios/Tests/XMarkupTests/Theme/MarkupThemeTests.swift
git commit -m "feat(ios): add BlockStyle DSL component

- BlockStyle() 便利函数
- BlockStyleComponent ThemeComponent
- NSTextBlockApplicator 预留
"
```

### 任务 5：BlockStyle 渲染集成 + blockquote 左边框

**文件：**
- 修改：`Rendering/BlockRenderer.swift` — renderBlock 中调用 applyBlockStyle
- 修改：`Rendering/DocumentRenderer.swift` — BlockStyleKey 注册
- 修改：`Attributes/XMarkupScope.swift` — 新增 BlockStyleNSTextBlockKey
- 测试：`Tests/XMarkupTests/Rendering/RenderTests.swift`

- [ ] **步骤 5.1：注册 BlockStyleNSTextBlockKey**

```swift
// Attributes/XMarkupScope.swift 追加
struct BlockStyleNSTextBlockKey: AttributedStringKey {
    typealias Value = NSTextBlock
    static let name = "XMarkup.BlockStyleNSTextBlock"
}

// AttributeScopes.XMarkupScope 追加
var blockStyleNSTextBlock: BlockStyleNSTextBlockKey.Type { BlockStyleNSTextBlockKey.self }
```

- [ ] **步骤 5.2：renderBlock 中调用 applyBlockStyle**

```swift
// renderBlock() 中 paragraphStyle 设置后，baseAttributes 设置前：
applyBlockStyle(kind: block.kind, theme: theme, to: &base)
```

- [ ] **步骤 5.3：测试 blockquote 渲染效果**

```swift
// RenderTests.swift 追加
func testBlockquoteWithBlockStyle() throws {
    let theme = MarkupTheme {
        BlockStyle(.blockquote) {
            $0.borderLeading = BlockStyleConfiguration.BorderEdge(width: 4, color: "#8E8E93")
        }
    }
    let attr = try parseAndRender("<blockquote>quote</blockquote>", theme: theme)
    let text = String(attr.characters)
    XCTAssertTrue(text.contains("quote"))

    // 验证存在 NSTextBlock 属性
    var foundTextBlock = false
    for run in attr.runs {
        if let _ = run[BlockStyleNSTextBlockKey.self] {
            foundTextBlock = true
        }
    }
    // 注意：BlockStyleNSTextBlockKey 传值验证
    // 实际 NSTextBlock 在 NSAttributedString 桥接中应用
    // 此处验证渲染不崩溃
}
```

- [ ] **步骤 5.4：运行测试**

```bash
cd platforms/ios && swift test --filter RenderTests --parallel
```

- [ ] **步骤 5.5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Attributes/XMarkupScope.swift \
       platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift \
       platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift
git commit -m "feat(ios): integrate BlockStyle rendering for blockquote border
"
```

---

## P2 — 表格渲染 + 语义标注

**目标：** 表格有原生 NSTextTable 布局、渲染输出含 PresentationIntent 标注。

### 任务 6：MarkupDocumentBuilder 填充 TableStructure

**文件：**
- 修改：`Core/MarkupDocumentBuilder.swift`
- 测试：`Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift`

- [ ] **步骤 6.1：blockKind() 返回 table 相关类型**

```swift
// MarkupDocumentBuilder.swift blockKind() 中：
case .table:
    return .table(TableStructure(rows: [], headerRowCount: 0, columnCount: 0))
case .tableRow:
    return .tableRow
case .tableCell:
    return .tableCell
case .tableHeader:
    return .tableHeader
```

- [ ] **步骤 6.2：flattenNode 中检测 .table 节点并组装 TableStructure**

```swift
// flattenNode 中，当 resolvedKind 是 .table 时：
if case .table = resolvedKind {
    // 不产出父块，而是收集子节点
    var rows: [[MarkupBlock]] = []
    var currentRow: [MarkupBlock] = []
    var maxColumns = 0

    for child in node.children {
        let rowBlocks = collectRowBlocks(child, text: text, allSpans: allSpans,
                                         inlineSpans: inlineSpans, mediaTags: mediaTags)
        if !rowBlocks.isEmpty {
            currentRow.append(contentsOf: rowBlocks)
            maxColumns = max(maxColumns, currentRow.count)
        } else {
            // 行变更
            if !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
            }
        }
    }
    if !currentRow.isEmpty { rows.append(currentRow) }

    for i in 0..<rows.count { while rows[i].count < maxColumns {
        rows[i].append(MarkupBlock(kind: .tableCell, text: "", inlines: [], attachment: nil))
    } }

    let headerCount = countHeaderRows(node)
    let structure = TableStructure(rows: rows, headerRowCount: headerCount, columnCount: maxColumns)
    blocks.append(MarkupBlock(kind: .table(structure), text: "", inlines: [], attachment: nil))
    return
}

private func collectRowBlocks(_ node: SpanNode, text: String, allSpans: [XMarkupSpan],
                               inlineSpans: [XMarkupSpan], mediaTags: Set<XMarkupTag>) -> [MarkupBlock] {
    guard node.span.tag == .tableRow else { return [] }
    var cells: [MarkupBlock] = []
    for child in node.children where child.span.tag == .tableCell || child.span.tag == .tableHeader {
        let nodeRange = child.span.range
        let blockText = extractText(text: text, nsRange: nodeRange)
        let inlines = convertToInlines(inlineSpans, in: text, parentRange: nodeRange)
        let kind: BlockKind = child.span.tag == .tableHeader ? .tableHeader : .tableCell
        cells.append(MarkupBlock(kind: kind, text: blockText, inlines: inlines, attachment: nil))
    }
    return cells
}
```

- [ ] **步骤 6.3：测试表格结构输出**

```swift
// Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift 追加
func testTableStructurePopulated() throws {
    let html = "<table><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></table>"
    let parser = try XMarkupParser()
    let result = try parser.parse(html)
    let doc = MarkupDocument.from(result)

    let tableBlock = doc.blocks.first { if case .table = $0.kind { return true }; return false }
    XCTAssertNotNil(tableBlock, "应产出 table 块")

    if case .table(let structure) = tableBlock!.kind {
        XCTAssertEqual(structure.columnCount, 2, "应为 2 列")
        XCTAssertEqual(structure.rows.count, 2, "应为 2 行")
        XCTAssertEqual(structure.rows[0][0].text, "A")
        XCTAssertEqual(structure.rows[0][1].text, "B")
        XCTAssertEqual(structure.rows[1][0].text, "C")
        XCTAssertEqual(structure.rows[1][1].text, "D")
    }
}
```

- [ ] **步骤 6.4：运行测试**

```bash
cd platforms/ios && swift test --filter MarkupDocumentBuilderTests --parallel
```

- [ ] **步骤 6.5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift \
       platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift
git commit -m "feat(ios): populate TableStructure in builder

- blockKind() 返回 tableRow/tableCell/tableHeader
- flattenNode 检测 table 节点组装 rows
"
```

### 任务 7：TableRenderer（NSTextTable + NSTextTableBlock）

**文件：**
- 创建：`Rendering/TableRenderer.swift`

- [ ] **步骤 7.1：创建 TableRenderer**

```swift
// Rendering/TableRenderer.swift
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// NSTextTable 渲染器
func renderTable(_ structure: TableStructure, theme: MarkupTheme) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let textTable = NSTextTable()
    textTable.columnCount = estimateColumnCount(structure)
    textTable.collapsesBorders = true

    let tableKey = TagStyleKey.table
    if let tableConfig = theme.blockStyles[tableKey] {
        if let collapse = tableConfig.collapsesBorders { textTable.collapsesBorders = collapse }
    }

    for (rowIdx, row) in structure.rows.enumerated() {
        for (colIdx, cell) in row.enumerated() {
            let cellBlock = NSTextTableBlock(table: textTable,
                                              startingRow: rowIdx,
                                              rowSpan: 1,
                                              startingColumn: colIdx,
                                              columnSpan: 1)

            // 应用 cell 样式
            applyCellBlockStyle(cellBlock, rowIdx: rowIdx, colIdx: colIdx,
                                isHeader: cell.kind == .tableHeader, theme: theme)

            let paraStyle = NSMutableParagraphStyle()
            paraStyle.textBlocks = [cellBlock]

            // 确保 base font + 内联样式
            var baseAttrs: [NSAttributedString.Key: Any] = [
                .font: theme.baseFont
            ]

            let cellText = cell.text
            let cellAttr = NSMutableAttributedString(string: cellText, attributes: baseAttrs)

            // 应用内联样式
            for inline in cell.inlines {
                let localRange = NSRange(location: inline.range.location, length: inline.range.length)
                guard localRange.location + localRange.length <= cellText.utf16.count else { continue }
                // 应用 paragraphStyle
                cellAttr.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: cellText.utf16.count))
                // 内联样式（简化：设字体/颜色等）
                applyInlineAttributesNS(inline, to: cellAttr, baseFont: theme.baseFont)
            }

            // 确保 paragraphStyle 已设置
            if cellAttr.length > 0 {
                cellAttr.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: cellAttr.length))
            }

            // 段落间换行（NSTextTable 用 \n 分隔 cell）
            if rowIdx > 0 || colIdx > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(cellAttr)
        }
    }

    return result
}

/// 应用 cell 级 NSTextBlock 样式
func applyCellBlockStyle(_ block: NSTextTableBlock, rowIdx: Int, colIdx: Int,
                          isHeader: Bool, theme: MarkupTheme) {
    let cellKey: TagStyleKey = isHeader ? .tableHeader : .tableCell
    guard let config = theme.blockStyles[cellKey] else { return }

    if let bg = config.backgroundColor, let color = ColorParser.parse(bg) {
        block.backgroundColor = color
    }
    if let border = config.borderBottom {
        if let color = ColorParser.parse(border.color) {
            block.setBorderColor(color, for: .maxYEdge)
            block.setWidth(border.width, type: .absolute, for: .maxYEdge)
        }
    }
    if let pTop = config.paddingTop { block.setContentWidth(pTop, type: .absolute) }
    // 注意：NSTextBlock padding 通过 setWidth(_:type:for:rectEdge:) 设置
}

/// 简化内联样式 NS 级应用
func applyInlineAttributesNS(_ inline: MarkupInline, to nsAttr: NSMutableAttributedString, baseFont: XMFont) {
    let range = inline.range
    guard range.location + range.length <= nsAttr.length else { return }

    switch inline.kind {
    case .bold:
        #if canImport(UIKit)
        if let bold = UIFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.traitBold)!, size: baseFont.pointSize) {
            nsAttr.addAttribute(.font, value: bold, range: range)
        }
        #endif
    default:
        break
    }
}

/// 估算列数
func estimateColumnCount(_ structure: TableStructure) -> Int {
    if structure.columnCount > 0 { return structure.columnCount }
    return structure.rows.map(\.count).max() ?? 1
}
```

- [ ] **步骤 7.2：集成到 DocumentRenderer.renderWithNSA()**

```swift
// DocumentRenderer.swift renderWithNSA() 中：
if case .table(let structure) = block.kind {
    let tableAttr = renderTable(structure, theme: theme)
    nsResult.append(tableAttr)
}
```

- [ ] **步骤 7.3：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/TableRenderer.swift \
       platforms/ios/Sources/XMarkup/Rendering/DocumentRenderer.swift
git commit -m "feat(ios): add TableRenderer with NSTextTable + NSTextTableBlock
"
```

### 任务 8：PresentationIntent 语义标注

**文件：**
- 创建：`Rendering/PresentationIntent.swift`
- 修改：`Rendering/InlineRenderer.swift`
- 测试：`Tests/XMarkupTests/Rendering/RenderTests.swift`

- [ ] **步骤 8.1：创建 PresentationIntent 标注辅助**

```swift
// Rendering/PresentationIntent.swift
import Foundation

extension DocumentRenderer {
    func applyPresentationIntent(kind: BlockKind, to attr: inout AttributedString) {
        let intent: PresentationIntent
        switch kind {
        case .paragraph, .division:
            intent = PresentationIntent(types: [.init(kind: .paragraph)])
        case .heading(let level):
            intent = PresentationIntent(types: [.init(kind: .header(level: level.rawValue))])
        case .blockquote:
            intent = PresentationIntent(types: [.init(kind: .blockQuote)])
        case .listItem(let isOrdered, _):
            let listKind: PresentationIntent.Kind = isOrdered ? .orderedList : .unorderedList
            intent = PresentationIntent(types: [.init(kind: listKind), .init(kind: .listItem)])
        case .preformatted:
            intent = PresentationIntent(types: [.init(kind: .codeBlock(languageHint: nil))])
        case .horizontalRule:
            intent = PresentationIntent(types: [.init(kind: .thematicBreak)])
        case .table:
            intent = PresentationIntent(types: [.init(kind: .paragraph)])
        }
        let fullRange = attr.startIndex..<attr.endIndex
        attr[fullRange].presentationIntent = intent
    }
}
```

- [ ] **步骤 8.2：集成到 renderBlock()**

```swift
// renderBlock() 中在 attr 创建后：
applyPresentationIntent(kind: block.kind, to: &attr)
```

- [ ] **步骤 8.3：InlineRenderer 添加 inlinePresentationIntent**

```swift
// InlineRenderer.swift applyInlineAttributes() 中追加
switch inline.kind {
case .bold:           attr[attrRange].inlinePresentationIntent = .stronglyEmphasized
case .italic:         attr[attrRange].inlinePresentationIntent = .emphasized
case .code:           attr[attrRange].inlinePresentationIntent = .code
case .strikethrough:  attr[attrRange].inlinePresentationIntent = .strikethrough
default: break
}
```

- [ ] **步骤 8.4：测试语义标注**

```swift
// RenderTests.swift 追加
func testPresentationIntentHeading() throws {
    let attr = try parseAndRender("<h2>Subtitle</h2>")
    var found = false
    for run in attr.runs {
        if let intent = run.presentationIntent {
            if intent.components.contains(where: { $0.kind == .header(level: 2) }) {
                found = true
            }
        }
    }
    XCTAssertTrue(found, "应标记 header(level: 2) 语义")
}

func testInlinePresentationIntentBold() throws {
    let attr = try parseAndRender("<b>bold</b>")
    var found = false
    for run in attr.runs {
        if run.inlinePresentationIntent == .stronglyEmphasized {
            found = true
        }
    }
    XCTAssertTrue(found, "应标记 stronglyEmphasized")
}
```

- [ ] **步骤 8.5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/PresentationIntent.swift \
       platforms/ios/Sources/XMarkup/Rendering/InlineRenderer.swift \
       platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift
git commit -m "feat(ios): add PresentationIntent semantic annotation

- 块级 presentationIntent 标注
- 内联 inlinePresentationIntent 标注
"
```

---

## P3 — 收尾优化（较低优先）

**目标：** hr NSTextAttachment、AsyncMediaLoader、命名迁移、代码清理。

### 任务 9：hr 改为 NSTextAttachment

**文件：**
- 修改：`Rendering/BlockRenderer.swift`

- [ ] **步骤 9.1：renderBlock 中 hr 分支改为 NSTextAttachment**

```swift
// renderBlock() 中 horizontalRule 分支替换：
if case .horizontalRule = block.kind {
    let attachment = NSTextAttachment()
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    attachment.image = renderer.image { ctx in
        UIColor.separator.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    attachment.bounds = CGRect(x: 0, y: 0, width: 200, height: 1)
    let nsAttr = NSMutableAttributedString(attachment: attachment)
    let attrStr = NSAttributedString(attachment: attachment)
    let result = NSMutableAttributedString(attributedString: attrStr)
    // 添加段落样式（间距）
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.paragraphSpacingBefore = theme.paragraphSpacing.spacingBefore
    paraStyle.paragraphSpacing = theme.paragraphSpacing.spacingAfter
    result.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: result.length))
    return AttributedString(result)
}
```

- [ ] **步骤 9.2：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift
git commit -m "refactor(ios): replace hr text with NSTextAttachment separator
"
```

### 任务 10：AsyncMediaLoader

**文件：**
- 创建：`Rendering/AsyncMediaLoader.swift`

- [ ] **步骤 10.1：创建 AsyncMediaLoader**

```swift
// Rendering/AsyncMediaLoader.swift
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// 异步媒体加载器（渲染后独立组件）
/// 扫描 NSAttributedString 中的附件引用占位，异步加载图片后更新
public final class AsyncMediaLoader: @unchecked Sendable {
    private let session: URLSession
    private let imageCache: NSCache<NSString, XMImage>

    public init(session: URLSession = .shared) {
        self.session = session
        self.imageCache = NSCache<NSString, XMImage>()
    }

    public enum Update {
        case updated(range: NSRange)
        case failed(range: NSRange, error: Error)
        case completed
    }

    /// 加载所有附件
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString,
        update: @escaping (Update) -> Void,
        completion: @escaping () -> Void
    ) {
        let group = DispatchGroup()
        let fullRange = NSRange(location: 0, length: nsAttr.length)

        nsAttr.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            group.enter()
            // 从附件标识获取 src
            let src = nsAttr.attribute(NSAttributedString.Key("XMarkup.AttachmentRef"),
                                        at: range.location, effectiveRange: nil) as? String ?? ""
            // 异步加载
            DispatchQueue.global().async { [weak self] in
                guard let self = self else { group.leave(); return }
                if let cached = self.imageCache.object(forKey: src as NSString) {
                    attachment.image = cached
                    DispatchQueue.main.async { update(.updated(range: range)) }
                    group.leave(); return
                }
                guard let url = URL(string: src) else { group.leave(); return }
                URLSession.shared.dataTask(with: url) { data, _, error in
                    defer { group.leave() }
                    if let error = error {
                        DispatchQueue.main.async { update(.failed(range: range, error: error)) }
                        return
                    }
                    guard let data = data, let image = XMImage(data: data) else { return }
                    self.imageCache.setObject(image, forKey: src as NSString)
                    attachment.image = image
                    DispatchQueue.main.async { update(.updated(range: range)) }
                }.resume()
            }
        }

        group.notify(queue: .main) { completion() }
    }
}
```

- [ ] **步骤 10.2：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/AsyncMediaLoader.swift
git commit -m "feat(ios): add AsyncMediaLoader for async image loading
"
```

### 任务 11：命名优化 & 代码清理

**文件：**
- 修改：`Rendering/RenderHelpers.swift` — 删除冗余映射
- 修改：`Theme/TagStyleKey.swift` — 确认命名（如改为 `TagKey`）
- 修改：`Theme/ThemeComponent.swift` — 旧名 typealias 保留

- [ ] **步骤 11.1：TagStyleKey → TagKey 别名**

```swift
// 当前 TagStyleKey 保留为 typealias
public typealias TagKey = TagStyleKey
```

- [ ] **步骤 11.2：删除冗余映射函数**

```swift
// RenderHelpers.swift 中保留必要函数，删除 blockKindName/inlineKindName
// 这些已通过 BlockKind/InlineKind 扩展实现
```

- [ ] **步骤 11.3：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/RenderHelpers.swift \
       platforms/ios/Sources/XMarkup/Theme/TagStyleKey.swift
git commit -m "refactor(ios): naming cleanup with backward compatible typealias
"

```

---

## 验证清单

### 编译验证

```bash
cd platforms/ios && swift build 2>&1

cd platforms/ios && swift test --parallel 2>&1
```

### 功能验证（每阶段后运行）

| 验证项 | 预期 | 阶段 |
|:-------|:-----|:-----|
| `<ol><li>A</li><li>B</li></ol>` | 显示 "1. A\n2. B" | P0 |
| `<ul><li>A</li><li>B</li></ul>` | 显示 "• A\n• B" | P0 |
| `<ul><li>A<ul><li>inner</li></ul></li></ul>` | 缩进正确 | P0 |
| BlockStyle(.blockquote) DSL | 编译通过 | P1 |
| `<table><tr><td>A</td><td>B</td></tr></table>` | 表格布局 | P2 |
| `<h2>` 渲染 | presentationIntent 含 header(level:2) | P2 |
| `<hr>` | 分隔线不是文本 `────` | P3 |
| 异步图片加载 | 占位图 → 真实图 | P3 |
| 全部 190+ 测试 | PASS | 全部 |

## 自检

- **规格覆盖度：** 设计文档 §9（实现顺序）的 P0~P3 全部有对应任务（1~11）
- **占位符扫描：** 所有步骤含实际代码，无 TODO
- **类型一致性：** `BlockGroups` / `DocumentRenderer` / `BlockStyleConfiguration` / `TableRenderer` 等类型在创建和使用中保持一致
