# iOS 层架构重设计

> **设计目标：** 解决当前 iOS 层在列表（NSTextList 实例不共享导致有序列表不编号）、表格（NSTextTable 原生能力未利用）、块级样式（blockquote 左侧竖线）三个核心问题，同时增强 DSL 自定义体系。

**范围：** iOS 平台（`platforms/ios/Sources/XMarkup/`），涉及 Core/Data Model 调整 + Rendering 层重写 + Theme/DSL 增强。

**状态：** 设计文档，待实现。

---

## 1. 背景与问题分析

### 1.1 当前架构

```
C++ Core → XMarkupResult → MarkupDocumentBuilder.from() → MarkupDocument
                                                              ↓
                                              render(theme:) → AttributedString
                                                              ↓
                                              NSAttributedStringRenderer → NSAttributedString
```

### 1.2 已知问题

| # | 问题 | 根因 | 严重度 |
|:--|:-----|:-----|:------:|
| 1 | 有序列表不显示编号 | 每个 `<li>` 独立创建 `NSTextList` 实例，文本系统无法识别同组列表 | P0 |
| 2 | 表格无布局，td 作为扁平段落渲染 | `NSTextTable` + `NSTextTableBlock` 原生能力未利用 | P1 |
| 3 | blockquote 无左侧竖线效果 | `NSTextBlock` 边框能力未利用 | P2 |
| 4 | `<hr>` 使用文本 `────` 模拟 | 应使用 `NSTextAttachment` 渲染真正的分隔线 | P2 |
| 5 | DSL 无法配置块级排版属性 | `TagStyleComponent` 仅限于 `AttributeContainer`，无法覆盖 `NSTextBlock`/`NSTextList.MarkerFormat` | P1 |
| 6 | 列表符号类型硬编码 | `<ol type="a">`（字母序号）无法配置 | P2 |
| 7 | 媒体加载同步阻塞 | `imageProvider` 闭包是同步的，无法支持网络图片异步加载 | P2 |

### 1.3 Apple 原生能力确认

通过 Apple 官方文档确认：

- **NSTextList**（iOS 7+）：`textLists` 属性支持 `.disc`/`.decimal`/`.circle`/`.lowercaseAlpha`/`.uppercaseRoman` 等 15+ 种标记格式。**关键约束：** 同一列表所有 item 必须共享同一个 NSTextList 实例。
- **NSTextTable**（iOS 6+）：通过 `NSTextTable` + `NSTextTableBlock` 实现原生表格布局。每个 cell = 1 个 paragraph，通过 `paragraphStyle.textBlocks` 挂载。Apple 有专用指南 [Adding tables to attributed strings in UIKit](https://developer.apple.com/documentation/uikit/adding-tables-to-attributed-strings)。
- **NSTextBlock**（iOS 6+）：支持 `backgroundColor`、`setBorderColor(_:for:)`、`setWidth(_:type:for:rectEdge:)`，可以为 blockquote 实现左侧竖线效果。

---

## 2. 目标架构

```
C++ Core → XMarkupResult → MarkupDocumentBuilder.from()
                                              ↓
                                       MarkupDocument
                                      [blocks: [MarkupBlock]]
                                              ↓
                              ┌───────────────────────────┐
                              │  MarkupDocumentRenderer    │
                              │                           │
                              │  Phase 1: analyzeGroups() │
                              │  ├── 连续 listItem → Group │
                              │  │   (共享 NSTextList)    │
                              │  └── table → TableGroup   │
                              │       (共享 NSTextTable)  │
                              │                           │
                              │  Phase 2: renderBlocks()  │
                              │  ├── 普通块 → swift       │
                              │  │   AttributedString      │
                              │  ├── 列表 → 设 shared     │
                              │  │   textLists            │
                              │  ├── 表格 → NSMutable     │
                              │  │   AttributedString +   │
                              │  │   NSTextTableBlock     │
                              │  └── blockquote →         │
                              │      NSTextBlock 边框     │
                              └──────────┬────────────────┘
                                         ↓
                                  AttributedString
                                         ↓
                              NSAttributedStringRenderer
                                         ↓
                               NSAttributedString
                                         ↓
                              AsyncMediaLoader (独立组件)
                              ├── 扫描附件属性
                              ├── 异步加载图片
                              └── 更新 NSTextAttachment + 刷新布局
```

### 2.1 核心变更

1. **数据模型层**：`MarkupDocumentBuilder` 真正填充 `TableStructure`
2. **渲染层**：从纯函数 `renderBlock(block, theme)` 改为两阶段 `MarkupDocumentRenderer`
3. **DSL 层**：新增 `BlockStyle` 组件 + 统一命名
4. **媒体层**：新增独立 `AsyncMediaLoader` 组件

---

## 3. 数据模型变更

### 3.1 TableStructure 填充

#### 当前问题

```swift
// MarkupDocumentBuilder.swift:blockKind()
case .table:
    return .table(TableStructure(rows: [], headerRowCount: 0, columnCount: 0)) // 空！
case .tableRow:
    return .division  // 扁平化，失去表格结构
case .tableCell:
    return .division
case .tableHeader:
    return .division
```

#### 修复方案

在 `MarkupDocumentBuilder.flattenNode()` 中增加表格检测：

```
SpanNode 树:
  table(0,30)
    ├── tr(0,30)
    │   ├── td(0,15) → 叶子节点 (block: MarkupBlock)
    │   └── td(15,30) → 叶子节点 (block: MarkupBlock)
    └── tr(30,60)
        ├── th(30,45) → 叶子节点 (block: MarkupBlock)
        └── td(45,60) → 叶子节点 (block: MarkupBlock)

flattenNode 检测 .table 节点时:
  1. 递归 flatten 子节点（tr → td/th），但不添加到全局 blocks 列表
  2. 收集子节点产出的 MarkupBlock 按行/列组装
  3. 产出 1 个 MarkupBlock(kind: .table(structure), text: "", inlines: [], attachment: nil)
```

**`TableStructure` 数据模型保持不变：**

```swift
public struct TableStructure: Sendable, Equatable {
    public let rows: [[MarkupBlock]]       // 每行每列的块
    public let headerRowCount: Int        // 表头行数
    public let columnCount: Int           // 列数
}
```

`MarkupBlock.text` 对于表格块为空字符串（内容在 `TableStructure.rows` 中）。

#### 实现要点

1. 在 `flattenNode` 中，当 `resolvedKind == .table(...)` 时，子节点遍历不输出到 blocks 列表，而是收集到临时数组
2. 修改 `blockKind()` 中的 `.tableRow`/`.tableCell`/`.tableHeader` 返回对应类型（不再返回 `.division`）
3. 保证 `.tableRow` 节点也参与树构建和递归（当前 `.division` 返回值不会影响树结构，但类型语义更准确）

---

## 4. 渲染层重设计

### 4.1 当前问题核心

`renderBlock(block, theme)` 是纯函数：

```swift
func renderBlock(_ block: MarkupBlock, theme: MarkupTheme) -> AttributedString {
    // 每个 block 独立创建 NSTextList
    case .listItem:
        let list = NSTextList(markerFormat: .decimal, options: 0) // ← 新实例
        // 不同 li 的 list 实例不同 → 文本系统无法关联 → 不编号
}
```

### 4.2 新架构：两阶段渲染

```
MarkupDocumentRenderer
  │
  ├── Phase 1: analyzeBlockGroups()
  │   输入: [MarkupBlock]
  │   输出: BlockGroups { listGroups: [ListGroup], tableMap: [Int: TableGroup] }
  │
  │   ListGroup 识别逻辑:
  │   扫描 blocks 中的连续 listItem：
  │   - 相同 indentLevel
  │   - 相同 isOrdered
  │   - 无间隔非列表块
  │   → 同一组共享同一个 NSTextList 数组
  │
  │   TableGroup 识别逻辑:
  │   扫描 blocks 中的 table 块
  │   → 构建 NSTextTable 实例
  │
  └── Phase 2: renderBlocks()
       输入: [MarkupBlock] + BlockGroups + MarkupTheme
       输出: AttributedString（内部使用 NSMutableAttributedString 处理复杂场景）
```

### 4.3 组分析算法

```swift
struct BlockGroups {
    /// 对于列表块，按块索引对应共享的 textLists 数组
    var listTextLists: [Int: [NSTextList]] = [:]
    /// key = block index in blocks array, value = list instances for that block
    /// 同一个列表组的所有 blocks 共享同一组 NSTextList 实例
}

func analyzeBlockGroups(_ blocks: [MarkupBlock]) -> BlockGroups {
    var groups = BlockGroups()
    var currentGroup: [Int] = []
    var currentIsOrdered: Bool?
    var currentIndent: Int?
    
    for (i, block) in blocks.enumerated() {
        guard case .listItem(let isOrdered, let indent) = block.kind else {
            // 非列表块 → 结束当前组
            finalizeGroup(&currentGroup, &groups, isOrdered: currentIsOrdered, indent: currentIndent)
            currentGroup = []
            currentIsOrdered = nil
            currentIndent = nil
            continue
        }
        
        if currentGroup.isEmpty {
            currentGroup = [i]
            currentIsOrdered = isOrdered
            currentIndent = indent
        } else if isOrdered == currentIsOrdered && indent == currentIndent {
            currentGroup.append(i) // 同组
        } else {
            finalizeGroup(&currentGroup, &groups, isOrdered: currentIsOrdered, indent: currentIndent)
            currentGroup = [i]
            currentIsOrdered = isOrdered
            currentIndent = indent
        }
    }
    finalizeGroup(&currentGroup, &groups, isOrdered: currentIsOrdered, indent: currentIndent)
    return groups
}

func finalizeGroup(_ group: inout [Int], _ groups: inout BlockGroups, 
                   isOrdered: Bool?, indent: Int?) {
    guard !group.isEmpty, let ordered = isOrdered, let ind = indent else { return }
    // 创建共享 instances
    var lists: [NSTextList] = []
    for level in 0...ind {
        let fmt: NSTextList.MarkerFormat = (level == 0) 
            ? (ordered ? .decimal : .disc) 
            : (ordered ? .decimal : .circle)
        lists.append(NSTextList(markerFormat: fmt, options: 0))
    }
    for idx in group {
        groups.listTextLists[idx] = lists
    }
    group = []
}
```

### 4.4 渲染阶段

```swift
extension MarkupDocument {
    public func render(theme: MarkupTheme = .default) -> AttributedString {
        let renderer = MarkupDocumentRenderer(theme: theme)
        return renderer.render(blocks)
    }
}

struct MarkupDocumentRenderer {
    let theme: MarkupTheme
    
    func render(_ blocks: [MarkupBlock]) -> AttributedString {
        let groups = analyzeBlockGroups(blocks)
        // 对于包含 NSTextTable 的 block，需要用 NSMutableAttributedString 桥接
        let needsTable = blocks.contains { if case .table = $0.kind { return true }; return false }
        
        if needsTable {
            return renderWithNS(blocks, groups: groups)
        } else {
            return renderWithAttributedString(blocks, groups: groups)
        }
    }
}
```

#### 普通块渲染（AttributedString 路径）

```swift
func renderWithAttributedString(_ blocks: [MarkupBlock], groups: BlockGroups) -> AttributedString {
    var result = AttributedString("")
    for (index, block) in blocks.enumerated() {
        if index > 0 { result.append(AttributedString("\n")) }
        var attr = renderSingleBlock(block, groupContext: groups.listTextLists[index], theme: theme)
        result.append(attr)
    }
    return result
}

func renderSingleBlock(_ block: MarkupBlock, 
                       sharedTextLists: [NSTextList]?,
                       theme: MarkupTheme) -> AttributedString {
    var baseAttributes = AttributeContainer()
    baseAttributes.uiKit.font = theme.baseFont
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacingBefore = theme.paragraphSpacing.spacingBefore
    paragraphStyle.paragraphSpacing = theme.paragraphSpacing.spacingAfter
    
    switch block.kind {
    case .listItem(let isOrdered, let indentLevel):
        if let shared = sharedTextLists {
            paragraphStyle.textLists = shared  // ← 同组共享实例
        } else {
            // 独立 list item（非连续组中的）
            paragraphStyle.textLists = buildTextLists(isOrdered: isOrdered, indentLevel: indentLevel)
        }
        paragraphStyle.headIndent = CGFloat(indentLevel + 1) * 24
        paragraphStyle.firstLineHeadIndent = CGFloat(indentLevel + 1) * 24
        
    case .blockquote:
        paragraphStyle.headIndent = 24
        paragraphStyle.firstLineHeadIndent = 24
        // NSTextBlock 边框在 applyBlockKindAttributes 中设置
        
    case .heading(let level):
        let spacingScale: CGFloat = headingSpacingScale(level)
        let headingSpacing = theme.baseFont.pointSize * spacingScale
        paragraphStyle.paragraphSpacingBefore = headingSpacing
        paragraphStyle.paragraphSpacing = headingSpacing * 0.5
        
    case .preformatted:
        paragraphStyle.lineBreakMode = .byCharWrapping
        
    default:
        break
    }
    
    baseAttributes.uiKit.paragraphStyle = paragraphStyle
    applyBlockKindAttributes(kind: block.kind, theme: theme, to: &baseAttributes)
    
    // 应用 BlockStyle 配置（NSTextBlock 边框/背景）
    applyBlockStyle(kind: block.kind, theme: theme, to: &baseAttributes)
    
    let blockText = blockText(for: block)
    var attr = AttributedString(blockText, attributes: baseAttributes)
    
    for inline in block.inlines {
        applyInlineAttributes(inline, theme: theme, to: &attr, blockText: block.text)
    }
    
    return attr
}
```

#### 块级样式应用（NSTextBlock）

```swift
func applyBlockStyle(kind: BlockKind, theme: MarkupTheme, to attributes: inout AttributeContainer) {
    guard let key = blockStyleKey(for: kind),
          let config = theme.blockStyles[key] else { return }
    
    // NSTextBlock 不能在 AttributedString 中直接表达
    // 需要在 rendering 时通过 NSMutableParagraphStyle.textBlocks 设置
    // 此函数在纯 AttributedString 路径中标记，在 NS 路径中实际构建
    // 
    // 实现方式：通过自定义 AttributedStringKey 传递 BlockStyle 引用
    attributes[BlockStyleKey.self] = config
}
```

#### 表格渲染（NSMutableAttributedString 路径）

```swift
func renderTable(_ structure: TableStructure, theme: MarkupTheme) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let textTable = NSTextTable()
    textTable.columnCount = structure.columnCount
    textTable.collapsesBorders = true
    
    // 从 theme.blockStyles 读取表格样式
    if let tableConfig = theme.blockStyles[.table] {
        if tableConfig.collapsesBorders { textTable.collapsesBorders = true }
    }
    
    for (rowIndex, row) in structure.rows.enumerated() {
        for (colIndex, cell) in row.enumerated() {
            let cellBlock = NSTextTableBlock(table: textTable, 
                                              startingRow: rowIndex, 
                                              rowSpan: 1,
                                              startingColumn: colIndex, 
                                              columnSpan: 1)
            
            // 从 theme.blockStyles 读取 cell 样式
            applyCellStyle(cellBlock, for: rowIndex, colIndex, structure: structure, theme: theme)
            
            // 构建 cell 段落
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.textBlocks = [cellBlock]
            
            let cellAttr = NSMutableAttributedString(string: cell.text)
            cellAttr.addAttribute(.paragraphStyle, value: paraStyle, 
                                  range: NSRange(location: 0, length: cell.text.utf16.count))
            
            // 应用内联样式
            // ...
            
            if colIndex > 0 || rowIndex > 0 {
                // paragraph 之间用 lineSeparator 避免额外段落间距
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(cellAttr)
        }
    }
    
    return result
}
```

---

## 5. DSL 完整设计

### 5.1 组件总览

| DSL 组件 | 作用域 | 当前状态 | 变更 |
|:---------|:-------|:---------|:-----|
| `BaseFont` | 全局 | 有 | 不变 |
| `HeadingScale` | 全局 | 有（`HeadingScaleComponent`） | 重命名 |
| `ParagraphSpacing` | 全局 | 有（`ParagraphSpacingComponent`） | 重命名 |
| `Tag` | 文本级 | 有 | 不变 |
| `BlockStyle` | 块级排版 | 无 | **新增** |
| `Media` | 媒体 | 有 | 不变 |

### 5.2 ThemeComponent 协议调整

```swift
public protocol ThemeComponent: Sendable {
    func apply(to theme: inout MarkupTheme)
}
```

协议不变。新增 `BlockStyleComponent` 遵循此协议。

### 5.3 新增：BlockStyleConfiguration

```swift
/// 块级排版配置（值类型，Sendable + Equatable）
/// 用于配置 NSTextBlock（背景/边框/边距）和 NSTextList（符号类型）
public struct BlockStyleConfiguration: Sendable, Equatable {
    // MARK: - NSTextBlock（blockquote, pre, division）
    public var backgroundColor: String?             // hex: "#F5F5F5"
    public var borderLeading: BorderEdge?           // 左边框（blockquote 竖线）
    public var borderTrailing: BorderEdge?
    public var borderTop: BorderEdge?
    public var borderBottom: BorderEdge?            // 下边框（table cell 分隔线）
    public var paddingTop: CGFloat?
    public var paddingBottom: CGFloat?
    public var paddingLeading: CGFloat?
    public var paddingTrailing: CGFloat?
    
    // MARK: - NSTextTable（table）
    public var collapsesBorders: Bool?
    public var layoutAlgorithm: TableLayoutAlgorithm?
    
    // MARK: - NSTextList（listItem）
    public var orderedMarker: MarkerFormatType?         // 默认 .decimal
    public var unorderedMarker: MarkerFormatType?       // 默认 .disc
    public var nestedOrderedMarker: MarkerFormatType?   // 默认 .decimal
    public var nestedUnorderedMarker: MarkerFormatType? // 默认 .circle
    
    // MARK: - Nested types
    
    public struct BorderEdge: Sendable, Equatable {
        public var width: CGFloat
        public var color: String  // hex: "#8E8E93"
    }
    
    public enum TableLayoutAlgorithm: String, Sendable, Equatable {
        case automatic
        case fixed
    }
    
    public enum MarkerFormatType: String, Sendable, Equatable, CaseIterable {
        case disc, circle, square, decimal
        case lowerAlpha, upperAlpha
        case lowerRoman, upperRoman
        case hyphen, check, box, diamond
        
        public var toNSTextListFormat: NSTextList.MarkerFormat {
            switch self {
            case .disc: return .disc
            case .circle: return .circle
            case .square: return .square
            case .decimal: return .decimal
            case .lowerAlpha: return .lowercaseAlpha
            case .upperAlpha: return .uppercaseAlpha
            case .lowerRoman: return .lowercaseRoman
            case .upperRoman: return .uppercaseRoman
            case .hyphen: return .hyphen
            case .check: return .check
            case .box: return .box
            case .diamond: return .diamond
            }
        }
    }
}
```

### 5.4 新增：BlockStyle DSL 组件

```swift
/// BlockStyle 便利函数
public func BlockStyle(
    _ key: TagStyleKey,
    configure: @Sendable @escaping (inout BlockStyleConfiguration) -> Void
) -> BlockStyleComponent {
    BlockStyleComponent(key: key, configure: configure)
}

public struct BlockStyleComponent: ThemeComponent {
    public let key: TagStyleKey
    public let configure: @Sendable (inout BlockStyleConfiguration) -> Void
    
    public func apply(to theme: inout MarkupTheme) {
        var config = theme.blockStyles[key] ?? BlockStyleConfiguration()
        configure(&config)
        theme.blockStyles[key] = config
    }
}
```

### 5.5 MarkupTheme 扩展

```swift
public struct MarkupTheme: @unchecked Sendable, Equatable {
    public var baseFont: XMFont
    public var headingScale: HeadingScale
    public var paragraphSpacing: ParagraphSpacing
    public var tagStyles: [TagStyleKey: AttributeContainer]
    public var blockStyles: [TagStyleKey: BlockStyleConfiguration]  // 新增
    public var mediaStrategy: MediaRenderingStrategy
}
```

### 5.6 重命名：现有组件

```swift
// 当前                          →  改为
HeadingScaleComponent(scale)    →  HeadingScale(scale) 作为便利函数
ParagraphSpacingComponent(spacing) →  ParagraphSpacing(spacing) 作为便利函数

// 保持向后兼容
public func HeadingScale(_ scale: HeadingScale) -> HeadingScaleComponent { ... }
public func ParagraphSpacing(_ spacing: ParagraphSpacing) -> ParagraphSpacingComponent { ... }
```

### 5.7 用户最终用法

```swift
let theme = MarkupTheme {
    // 全局
    BaseFont(.systemFont(ofSize: 17))
    HeadingScale(.default)
    ParagraphSpacing(spacingBefore: 12, spacingAfter: 12)

    // 文本级（不变）
    Tag(.code)  { $0.uiKit.font = .monospacedSystemFont(ofSize: 14, weight: .regular) }
    Tag(.link)  { $0.uiKit.foregroundColor = .systemBlue }
    Tag(.mark)  { $0.uiKit.backgroundColor = .systemYellow.withAlphaComponent(0.3) }
    Tag(.heading) { $0.uiKit.foregroundColor = .label }
    
    // 块级（新增）
    BlockStyle(.blockquote) {
        $0.backgroundColor = "#F5F5F5"
        $0.borderLeading = (width: 4, color: "#8E8E93")
    }
    BlockStyle(.tableCell) {
        $0.borderBottom = (width: 1, color: "#C6C6C8")
        $0.padding = (top: 4, bottom: 4, leading: 8, trailing: 8)
    }
    BlockStyle(.listItem) {
        $0.orderedMarker = .decimal
        $0.unorderedMarker = .disc
        $0.nestedOrderedMarker = .lowerAlpha
        $0.nestedUnorderedMarker = .circle
    }

    // 媒体（不变）
    Media(.imageProvider { ImageCache.shared.load($0) })
}
```

---

## 6. 精准控制（后处理模式）

DSL 是全局主题，精准控制特定内容通过后处理实现：

```swift
let attr = document.render(theme: theme)

// 找到特定位置的 <code> 标签
for run in attr.runs {
    guard run[XMarkupTagKey.self] == "code" else { continue }
    let text = String(attr[run.range].characters)
    if text.contains("dangerous") {
        attr[run.range].uiKit.foregroundColor = .red
        attr[run.range].uiKit.backgroundColor = .yellow.withAlphaComponent(0.2)
    }
}

// 找到特定标题级别
for run in attr.runs {
    guard run[XMarkupHeadingLevelKey.self] == 1 else { continue }
    attr[run.range].uiKit.foregroundColor = .systemIndigo
}
```

所有自定义属性在渲染时已标记在 `AttributedString` 中，包括：

| 属性 Key | 类型 | 示例值 |
|:---------|:-----|:-------|
| `XMarkupTagKey` | String | `"bold"`, `"heading2"`, `"code"` |
| `XMarkupBlockKindKey` | String | `"paragraph"`, `"listItem"` |
| `XMarkupLinkURLKey` | String | `"https://..."` |
| `XMarkupHeadingLevelKey` | Int | `1` ~ `6` |
| `XMarkupListItemInfoKey` | String | `"ordered:0"`, `"unordered:1"` |
| `XMarkupAttachmentRefKey` | String | `"image:photo.jpg"` |

---

## 7. 异步媒体加载（独立组件）

### 7.1 设计原则

渲染器（`MarkupDocumentRenderer`）保持同步，只产出带占位图的 `AttributedString`。

异步媒体加载由独立的 `AsyncMediaLoader` 组件在渲染后执行。

### 7.2 用法

```swift
// 1. 渲染（同步，占位图）
let attr = document.render(theme: theme)
let nsAttr = NSAttributedStringRenderer().render(attr)
textView.attributedText = nsAttr

// 2. 异步加载（独立组件）
let loader = AsyncMediaLoader()
loader.loadAttachments(in: nsAttr) { [weak textView] result in
    switch result {
    case .updated(let range):
        // NSTextAttachment.image 已更新
        textView?.layoutManager.invalidateDisplay(for: range)
    case .completed:
        print("所有媒体加载完成")
    }
}
```

### 7.3 AsyncMediaLoader 设计

```swift
public class AsyncMediaLoader: @unchecked Sendable {
    private let session: URLSession
    private let imageCache: NSCache<NSString, XMImage>
    
    public init(session: URLSession = .shared) { ... }
    
    /// 扫描 NSAttributedString 中的附件引用，异步加载
    /// - Parameters:
    ///   - nsAttr: 已渲染的 NSAttributedString
    ///   - update: 每加载完成一个附件回调一次（含 NSRange）
    ///   - completion: 全部完成后回调
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString,
        update: @escaping (AsyncMediaUpdate) -> Void,
        completion: @escaping () -> Void
    ) { ... }
}

public enum AsyncMediaUpdate {
    case updated(range: NSRange)
    case failed(range: NSRange, error: Error)
    case skipped(range: NSRange)
    case completed
}
```

---

## 8. 文件变更清单

### 8.1 新增文件

| 文件 | 职责 |
|:-----|:-----|
| `Rendering/MarkupDocumentRenderer.swift` | 两阶段渲染器（组分析 + 渲染） |
| `Rendering/TableRenderer.swift` | NSTextTable + NSTextTableBlock 封装 |
| `Rendering/ListRenderer.swift` | NSTextList 组管理与构建 |
| `Rendering/BlockStyleApplicator.swift` | BlockStyleConfiguration → NSTextBlock 应用 |
| `Rendering/AsyncMediaLoader.swift` | 异步图片加载器（独立组件） |
| `Theme/BlockStyleConfiguration.swift` | BlockStyleConfiguration 值类型定义 |
| `Theme/BlockStyleComponent.swift` | BlockStyle DSL 组件 |

### 8.2 修改文件

| 文件 | 变更 |
|:-----|:-----|
| `Core/MarkupDocumentBuilder.swift` | 填充 `TableStructure`；`blockKind()` 返回 `.tableRow`/`.tableCell`/`.tableHeader` |
| `Core/MarkupDocument.swift` | `render(theme:)` 委派给 `MarkupDocumentRenderer` |
| `Core/BlockKind.swift` | 无变更（`TableStructure` 已足够） |
| `Rendering/BlockRenderer.swift` | 重构为 `MarkupDocumentRenderer` 的一部分；段落样式 + 块级属性分离 |
| `Rendering/InlineRenderer.swift` | 无变更（内联样式逻辑保持不变） |
| `Rendering/MarkupDocument+Render.swift` | 删除或委派给 `MarkupDocumentRenderer` |
| `Rendering/AttachmentRenderer.swift` | 无变更（附件占位逻辑不变） |
| `Rendering/NSAttributedStringRenderer.swift` | 无变更（桥接逻辑不变） |
| `Theme/MarkupTheme.swift` | 新增 `blockStyles: [TagStyleKey: BlockStyleConfiguration]` |
| `Theme/ThemeComponent.swift` | 新增 `HeadingScale`/`ParagraphSpacing` 便利函数 |
| `Theme/PresetThemes.swift` | 无变更 |

### 8.3 可能删除的文件

| 文件 | 理由 |
|:-----|:-----|
| `Rendering/RenderHelpers.swift` | 部分映射函数可合并到渲染器中 |
| `Rendering/MarkupDocument+Render.swift` | 业务迁移到 `MarkupDocumentRenderer` |

---

## 9. 实现顺序

| 阶段 | 任务 | 依赖 | 预期效果 |
|:----|:-----|:-----|:---------|
| **P0** | 渲染器两阶段重构 | 无 | 有序列表编号恢复正常 |
| P0.1 | 创建 `MarkupDocumentRenderer`，实现 `analyzeBlockGroups()` | - | - |
| P0.2 | 列表项渲染改为共享 `textLists` | P0.1 | - |
| P0.3 | 验证列表编号（有序/无序/嵌套） | P0.2 | 测试 + Demo 确认 |
| **P1** | `BlockStyle` DSL + `BlockStyleConfiguration` | P0 | 可自定义块级属性 |
| P1.1 | 定义 `BlockStyleConfiguration` 值类型 | - | - |
| P1.2 | 添加 `BlockStyle` DSL 组件 | P1.1 | - |
| P1.3 | 渲染器读取 `blockStyles` 构建 NSTextBlock | P1.2 | - |
| **P2** | `TableStructure` 填充 | P0 | 表格渲染可用 |
| P2.1 | `blockKind()` 返回正确 table 类型 | - | - |
| P2.2 | `flattenNode` 检测 table 节点，组装 `TableStructure` | P2.1 | - |
| P2.3 | 创建 `TableRenderer`（NSTextTable + NSTextTableBlock） | P0 | - |
| P2.4 | 验证表格渲染（行/列/表头） | P2.2 + P2.3 | 测试 + Demo |
| **P3** | blockquote `NSTextBlock` 边框 | P1 | blockquote 左侧竖线 |
| **P3** | `<hr>` `NSTextAttachment` 替代文本 | P0 | 真正分隔线 |
| **P3** | `AsyncMediaLoader` 独立组件 | P2 | 异步图片加载 |
| **P3** | DSL 组件名称统一 | P1 | 向后兼容重命名 |

---

## 10. 兼容性说明

- **旧` HeadingScaleComponent` 和 `ParagraphSpacingComponent`**：保留为 typealias 保持编译兼容
- **旧 `render(theme:)` 签名**: 不变，返回 `AttributedString`
- **`MarkupBlock` 数据模型**: 不变，外部 consumer 无需修改
- **`MarkupTheme` 新 `blockStyles` 字段**: 默认空字典，现有代码不受影响
- **测试**: 所有现有 191 个 Swift 测试应继续保持通过
