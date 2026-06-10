# iOS Swift 渲染完整一致性修复计划

> **目标：** 补齐 C++ 核心 47 个标签 + 11 个样式的 Swift 渲染缺口，
> 使 NSAttributedString 渲染与 HTML 浏览器默认样式一致。

---

## 审计结果：待修复 11 项

| 优先级 | 标签/样式 | C++ 核心 | Swift 渲染 | 缺口 |
|:--:|:--|:--:|:--:|:--|
| 🔴 P0 | `<mark>` | 高亮 | **break** 无渲染 | 需黄色背景 |
| 🔴 P0 | `<hr>` | 插入 U+FFFC | **break** 无渲染 | 需分隔线 |
| 🔴 P0 | `<table>/<tr>/<td>/<th>` | 块级元素 | 全部 fallback → **paragraph** | 需 blockKind 映射 |
| 🔴 P0 | `<pre>` 空白 | 核心内留空白 | **强行修剪换行** | 需保留空白 |
| 🟠 P1 | `<blockquote>` 缩进 | +`\n` 隔 | 无缩进 | 需 `headIndent` |
| 🟠 P1 | `<ul>/<ol>` 列表符号 | 语义已解析 | 纯文本 | 需 •/1. 前缀 |
| 🟡 P2 | `<code>` 样式 | 段落 | 等宽字体 | 缺背景色 |
| 🟡 P2 | `<h1>`~`<h6>` 上下间距 | 条块 | 无间距 | 需 `paragraphSpacing` |
| 🟡 P2 | `<a>` 链接 式样 | href | 蓝色+下划线 | `linkColor` ✅已够 |
| 🟢 P3 | `<table>` 表格布局 | 标签/行/栏 | 直接 | 远期再优化 |
| 🟢 P3 | 语义块(article/section...) | 标签 | 全映射 division | 远期可区分 |

---

## 执行顺序

### 任务 1：`<mark>` 高亮渲染

**文件：** `InlineRenderer.swift`

当前第 72 行：`case .mark: break`

```swift
case .mark:
    #if canImport(UIKit)
    attr[attrRange].uiKit.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
    #elseif canImport(AppKit)
    attr[attrRange].appKit.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.3)
    #endif
```

测试：
- `<mark>highlight</mark>` → 渲染后对应范围含黄色背景

---

### 任务 2：`<hr>` 水平分隔线

**文件：** `BlockRenderer.swift`

当前 `applyBlockKindAttributes` 中：`case .horizontalRule: break`

```swift
case .horizontalRule:
    #if canImport(UIKit)
    attributes.uiKit.foregroundColor = UIColor.systemGray3
    #elseif canImport(AppKit)
    attributes.appKit.foregroundColor = NSColor.systemGray
    #endif
```

且在 `renderBlock` 中，对 `horizontalRule` 设置最小高度和分隔线字符：

```swift
// renderBlock，在构建 attr 之前
if case .horizontalRule = block.kind {
    var attr = AttributedString("\u{2003}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2003}", attributes: baseAttributes)
    // 应用主题覆盖
    return attr
}
```

测试：
- `<hr>` → 渲染后包含分隔线

---

### 任务 3：`<table>`/`<tr>`/`<td>`/`<th>` blockKind 映射

**文件：** `MarkupDocumentBuilder.swift`

当前 `blockKind()` 无 table 系列 case，全部 fall 到 `default: return .paragraph`。

新增：

```swift
case .table:
    return .table(TableStructure(rows: [], headerRowCount: 0, columnCount: 0))
case .tableRow:
    return .division
case .tableCell:
    return .division
case .tableHeader:
    return .division
```

> `BlockKind.table(TableStructure)` 已定义但从未使用，此处先赋予但不构建复杂结构。
> 单元格都先用 .division 占位，避免 fallthrough 到 .paragraph 丢失语义。
> 远期可构建真正的 TableStructure。

同时 `blockStyleKey` 映射表（已新增 TagStyleKey.table/tableRow/tableCell/tableHeader）才能生效。

测试：
- `<table><tr><td>cell</td></tr></table>` → block.kind 正确（不再为 .paragraph）

---

### 任务 4：`<pre>` 空白保留

**文件：** `MarkupDocumentBuilder.swift` + `BlockRenderer.swift`

#### 4a. extractText 不修剪 pre 尾部换行

```swift
private static func extractText(text: String, nsRange: NSRange, preserveTrailingNewlines: Bool = false) -> String {
    let raw = // ... substring
    if preserveTrailingNewlines { return raw }
    return raw.trimmingTrailingNewlines
}
```

调用处：

```swift
let blockText = extractText(text: text, nsRange: spanRange,
    preserveTrailingNewlines: span.tag == .preformatted)
```

#### 4b. convertToInlines 不修剪

`convertToInlines` 加参数 `preserveTrailingNewlines: Bool`，跳过 `trimmedBlockEnd` 计算。

#### 4c. blockRenderer 阻止空白压缩

```swift
case .preformatted:
    // 现有：等宽字体
    // 新增：防止空白压缩
    let paraStyle = NSMutableParagraphStyle()
    #if canImport(UIKit)
    paraStyle.lineBreakMode = .byCharWrapping
    #endif
    // 需要合并到已设置的 paragraphStyle
```

测试：
- `<pre>  code  </pre>` → 保持前导尾随空格
- `<pre>line1\n\nline3</pre>` → 空行保留

---

### 任务 5：`<blockquote>` 缩进

**文件：** `BlockRenderer.swift`

在 `applyBlockKindAttributes` 中：

```swift
case .blockquote:
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.headIndent = 24
    paraStyle.firstLineHeadIndent = 24
    // 可选竖线效果用 NSTextAttachment
```

但这里的问题是 `baseAttributes` 已经设置了 `paragraphStyle`（来自 `ParagraphSpacing`），需要合并而非覆盖。

实际做法：在 `renderBlock` 函数中，对 `.blockquote` case 追加 paragraphStyle 修改：

```swift
if case .blockquote = block.kind {
    if let existing = baseAttributes.uiKit.paragraphStyle {
        let merged = existing.mutableCopy() as! NSMutableParagraphStyle
        merged.headIndent = 24
        baseAttributes.uiKit.paragraphStyle = merged
    }
}
```

测试：
- `<blockquote>text</blockquote>` → 渲染后有左缩进

---

### 任务 6：`<ul>`/`<ol>` 列表符号

**文件：** `BlockRenderer.swift`

在 `renderBlock` 函数中，构建 `block.text` 之前添加前缀：

```swift
if case .listItem(let isOrdered, let indentLevel) = block.kind {
    // 添加上下文符号
    // 简化版：统计同级列表中当前是第几项
    let marker: String
    if isOrdered {
        marker = "\(/* index */). "
    } else {
        marker = "• "
    }
    // 在 block 文本前插入符号
    let prefix = String(repeating: "  ", count: indentLevel) + marker
    blockText = prefix + blockText
}
```

复杂度：有序列表需要知道当前项的序号。有两种做法：

**方案 A：在 MarkupDocumentBuilder 中计算序号**
给 `MarkupBlock` 加 `listOrder` 字段或修改 `BlockKind.listItem` 带序号。

**方案 B：在 blockRenderer 中扫描 blocks**
渲染时扫描前序兄弟 block 计算序号。

推荐方案 A，改动最小：

```swift
// MarkupDocumentBuilder.swift
case .listItem:
    // ... 现有 isOrdered 逻辑 ...
    // 新增：收集前序 li 块的数量作为序号
    let precedingCount = blocks.filter { ... }.count + 1
    return .listItem(isOrdered: isOrdered, indentLevel: 0)
```

---

### 任务 7：`<code>` 灰色背景

**文件：** `InlineRenderer.swift`

```swift
case .code:
    // 现有
    attr[attrRange].uiKit.font = UIFont.monospacedSystemFont(ofSize: ..., weight: .regular)
    // 新增
    attr[attrRange].uiKit.backgroundColor = UIColor.systemGray6
```

AppKit 同理：`NSColor.controlBackgroundColor` 或 `NSColor.systemGray`。

---

### 任务 8：`<h1>`~`<h6>` 段落间距

**文件：** `BlockRenderer.swift`

在 `applyBlockKindAttributes` 中，heading 字号已缩放但无上下间距。

在 `renderBlock` 的 `paragraphStyle` 基础上追加：

```swift
case let .heading(level):
    let spacingScale: CGFloat
    switch level {
    case .h1: spacingScale = 0.67
    case .h2: spacingScale = 0.83
    case .h3: spacingScale = 1.0
    case .h4: spacingScale = 1.33
    case .h5: spacingScale = 1.67
    case .h6: spacingScale = 2.0
    }
    let spacing = theme.baseFont.pointSize * spacingScale
    paragraphStyle.paragraphSpacingBefore = spacing
    paragraphStyle.paragraphSpacing = spacing * 0.5
```

---

## 验证

```bash
# Swift 全量测试
swift test

# Demo App 手动验证
# Bundle run Demo target → 逐个查看标签样式
```

---

## 文件变更汇总

| 文件 | 修改内容 | 涉及任务 |
|:--|:--|:--:|
| `InlineRenderer.swift` | mark/ 注解加粗 缩放/ 上标下标√ | 1, 7 |
| `MarkupDocumentBuilder.swift` | extractText pre 保留换行/ convertToInlines pre 保留/ blockKind 加 table/tr/td/th | 3, 4 |
| `BlockRenderer.swift` | hr 分隔线/ blockquote 缩进/ listItem 符号/ heading 上下间距/ pre 空白控制 | 2, 4, 5, 6, 8 |
| `RenderHelpers.swift` | blockStyleKey 加 table（已有）、inlineStyleKey 加 subscript/superscript（已有） | 已完 |

测试文件：`RenderTests.swift` 各任务对应新增测试。
