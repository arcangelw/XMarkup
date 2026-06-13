# iOS 富文本 HTML 风格一致性优化计划

> **目标：** 修复 Swift 层渲染与 HTML 默认样式之间的视觉差异，
> 让 `<pre>`/`<blockquote>`/`<h1>`~`<h6>`/`<ul>`/`<ol>` 等标签
> 在 NSAttributedString 渲染时表现与 HTML 浏览器一致的默认样式。

---

## 背景：当前差异汇总

| 标签 | HTML 默认行为 | Swift 当前行为 | 差距 |
|:--|:--|:--|:--:|
| `<pre>` | 空白保留 + 等宽 + 不自动换行 | 等宽字体 ✅，但尾部空白被修剪 ❌ | 🔴 |
| `<blockquote>` | 左缩进 + 左竖线/背景 | 无缩进，纯文本 | 🔴 |
| `<h1>`~`<h6>` | 文本前后大间距 + 加粗 | 仅有字号缩放 | 🟡 |
| `<ul>`/`<ol>` | 缩进 + 符号/编号 | 纯文本段落，无标记 | 🔴 |
| `<code>` | 等宽字体 + 浅色背景 | 使用 baseFont，无特殊样式 | 🟡 |
| `<hr>` | 水平分隔线 | `MarkupBlock` 但无渲染实现 | 🟡 |
| `<table>` | 网格布局 | 扁平段落，无结构 | 🔴 |
| 段落间距 | 上下 ~1em 外边距 | `ParagraphSpacing` 可配，默认值可能不同 | 🟡 |

---

## 任务列表

### 任务 1：`<pre>` 空白保留

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift`
- 修改：`platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift`
- 新增测试：`RenderTests.swift`

#### 1a. extractText 不修剪 pre 块的尾部换行

`MarkupDocumentBuilder.swift:180` 的 `extractText` 需要感知 block kind：

```swift
// 修改前
private static func extractText(text: String, nsRange: NSRange) -> String

// 修改后：传 blockKind，对 preformatted 不修剪
private static func extractText(text: String, nsRange: NSRange, preserveTrailingNewlines: Bool = false) -> String
```

`preserveTrailingNewlines` 在调用处根据 blockKind 设置：

```swift
let blockText = extractText(text: text, nsRange: spanRange, 
    preserveTrailingNewlines: span.tag == .preformatted)
```

#### 1b. convertToInlines 中 pre 块不做尾部修剪

`convertToInlines` 内部的 `trimmedBlockEnd` 计算对 pre 块应跳过：

```swift
// 对 pre 块跳过尾部换行修剪
let trimmedBlockEnd: Int
if blockTags.contains(.preformatted) { // 或传参
    trimmedBlockEnd = parentEnd
} else {
    trimmedBlockEnd = parentRange.location + trimmedParentLength
}
```

优化方案：给 `convertToInlines` 加 `preserveTrailingNewlines` 参数。

#### 1c. BlockRenderer 阻止空白压缩

`BlockRenderer.swift` 在 `renderBlock` 中，当 `kind == .preformatted` 时，将内联属性中的空白压缩行为设为不压缩：

```swift
if case .preformatted = block.kind {
    // 阻止系统空白压缩（多个空格合并）
    let paraStyle = NSMutableParagraphStyle()
    // 设置合适的换行模式
    #if canImport(UIKit)
    paraStyle.lineBreakMode = .byCharWrapping
    #endif
    // 应用到 baseAttributes
}
```

#### 1d. 测试

验证：
- `<pre>  spaced  </pre>` 渲染后前后空格保留
- `<pre>line1\n\nline3</pre>` 空行保留
- `<pre>code</pre>` 使用等宽字体

### 任务 2：`<blockquote>` 缩进

**文件：**
- 修改：`BlockRenderer.swift`

HTML 默认 `<blockquote>` 有 40px 左外边距。Swift 中用 `NSParagraphStyle.headIndent` 实现：

```swift
case .blockquote:
    let paraStyle = NSMutableParagraphStyle()
    paraStyle.headIndent = 20  // 左边距
    paraStyle.firstLineHeadIndent = 20
    #if canImport(UIKit)
    attributes.uiKit.paragraphStyle = paraStyle
    #elseif canImport(AppKit)
    attributes.appKit.paragraphStyle = paraStyle
    #endif
```

如需要竖线（类似 CSS border-left），可以用 `NSTextAttachment` 或自定义背景视图在桥接层实现。

### 任务 3：`<ul>`/`<ol>` 列表符号

**文件：**
- 修改：`BlockRenderer.swift`

当前列表项渲染为纯文本段落，HTML 默认样式包含：
- `<ul>`：项目符号（•）
- `<ol>`：数字编号（1. 2. 3.）
- 左缩进

方案：在渲染列表项时，在文本前面插入符号：

```swift
case .listItem(let isOrdered, let indentLevel):
    let marker: String
    if isOrdered {
        // 需要知道序号，从 blocks 中查前序兄弟
        marker = "1. "  // 简化
    } else {
        marker = "• "   // Unfilled bullet
    }
    // 在文本前追加符号
    baseText = marker + baseText
```

复杂度：有序列表需要索引上下文，因为 `BlockKind.listItem(isOrdered:indentLevel:)` 没有序号信息。需要：

1. 在 `MarkupDocumentBuilder` 中为 `listItem` 块添加序号属性
2. 或者传入当前块的序号位置

### 任务 4：`<hr>` 水平分隔线渲染

**文件：**
- 修改：`BlockRenderer.swift`

当前 `horizontalRule` 的 `applyBlockKindAttributes` 直接 `break`，什么都不做。
需要渲染为一条水平线：

```swift
case .horizontalRule:
    // 用 NSTextAttachment 占位 + 渲染为一条线
    // 或设置 NSAttributedString.Key 供桥接层处理
```

最小实现：用 `\n———————\n` 文本代替。

### 任务 5：`<code>` 等宽字体 + 浅色背景

**文件：**
- 修改：`InlineRenderer.swift`

当前 `<code>` 设为等宽字体但没有背景：

```swift
case .code:
    // 现有：等宽字体
    attr[attrRange].uiKit.font = ...
    // 新增：浅灰背景
    attr[attrRange].uiKit.backgroundColor = UIColor.systemGray6
```

### 任务 6：`<h1>`~`<h6>` 段落间距

**文件：**
- 修改：`BlockRenderer.swift`

HTML 中标题上下有默认间距：
- `<h1>`: 上下 ~0.67em
- `<h2>`: 上下 ~0.83em
- `<h3>`: 上下 ~1em

在 `applyBlockKindAttributes` 中添加：

```swift
case .heading(let level):
    let spacingScale: CGFloat
    switch level {
    case .h1: spacingScale = 0.67
    case .h2: spacingScale = 0.83
    case .h3: spacingScale = 1.0
    case .h4: spacingScale = 1.33
    case .h5: spacingScale = 1.67
    case .h6: spacingScale = 2.0
    }
    let headingSpacing = theme.baseFont.pointSize * spacingScale
    paraStyle.paragraphSpacingBefore = headingSpacing
    paraStyle.paragraphSpacing = headingSpacing * 0.5
```

### 任务 7：`<table>` 表格渲染

P3 远期规划，当前可以：
1. 不破坏现有扁平段落流程
2. 将 `TagStyleKey.table` 映射到 `blockStyleKey` 使主题系统可覆盖样式

### 验证

```bash
swift test

# 手动验证：
# 构建 Demo App 查看预渲染效果
```
