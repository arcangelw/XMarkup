# iOS 原生富文本能力对比与架构调整

## 问题

当前 Swift 层手动构造了本应由 iOS 原生渲染系统处理的内容：

| 功能 | 当前做法 | 问题 |
|:--|:--|:--|
| 列表符号 | 文本前拼 `•\t` / `1.\t` | 改写了文本内容，复制/选中异常 |
| `<hr>` 分隔线 | 文本 `────` | 不是真正的分隔线 |
| `<blockquote>` 左竖线 | 无 | 原生无法表达 |
| `<table>` 表格 | 扁平段落 | 原生不支持表格布局 |

## iOS 原生富文本能力全景

### `NSParagraphStyle` 原生支持的

| 属性 | 对应场景 | 是否已用 |
|:--|:--|:--|
| `alignment` | 水平对齐 | ✅ `textAlign` |
| `headIndent` | 缩进 | ✅ `blockquote` |
| `firstLineHeadIndent` | 首行缩进 | ✅ `blockquote` |
| `paragraphSpacingBefore` | 标题上下间距 | ✅ `heading` |
| `paragraphSpacing` | 段间距 | ✅ `theme` 级别 |
| `lineSpacing` | 行距 | ✅ `theme` 级别 |
| `lineBreakMode` | 换行模式 | ❌ 未用（pre 可用） |
| `tabStops` | 制表位对齐 | ❌ 未用（列表需要） |

### `NSTextList`（iOS 15+）原生列表

`NSTextList` 无需修改文本内容即可渲染列表符号：

```swift
let list = NSTextList(markerFormat: .disc, options: 0)  // •
paragraphStyle.textLists = [list]
paragraphStyle.headIndent = 24
paragraphStyle.firstLineHeadIndent = 24
paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: 24)]
```

| 格式 | 枚举 | 效果 |
|:--|:--|:--|
| 无序 | `.disc` | • |
| 有序 | `.decimal` | 1. 2. 3. |
| 嵌套 | 多级 `.textLists` | 自动缩进 + 符号变化 |

**优势：**
- 不修改文本内容 → 复制、选中、朗读无障碍
- 自动编号 → 不需要在 builder 中计数前序兄弟
- 嵌套自动处理 → 多级 `.textLists` 数组即可
- 字体/颜色自动继承周围文本

### 非原生支持的（需自定义）

| 功能 | 方案 |
|:--|:--|
| `<table>` 表格布局 | `NSTextAttachment` + 自定义渲染 / `UICollectionView` |
| `<blockquote>` 左侧竖线 | 在 `UITextView` 的 delegate 回调中绘制背景或使用 `NSTextAttachment` |
| `<hr>` 水平分隔线 | `NSTextAttachment` 绘制灰色矩形条 |
| `<pre>` 灰底背景 | `NSAttributedString.Key.backgroundColor` ✅ |

## 架构调整方案

### 改动 1：移除手动列表符号，改用 NSTextList

**删除：** `applyListMarker()` 和所有 `•\t` / `1.\t` 文本拼接逻辑
**删除：** inline range 的 markerLen 偏移调整
**修改：** `BlockRenderer.swift` 中 `.listItem` 设置 `textLists`
**修改：** `MarkupDocumentBuilder.swift` 的 `blockKind` 计算 `indentLevel`（从树深度推导）

### 改动 2：NSTextAttachment 替代文本占位

`<hr>` 和 `<table>` 改为使用 `NSTextAttachment` 或自定义 NSAttributedString key 供渲染层处理。

### 改动 3：SwiftUI/UIKit 渲染层

当前 `MarkupDocument+Render.swift` 使用纯 AttributedString 渲染。
对于 `<table>` 和 `<blockquote>` 竖线效果，需要在 `UITextViewDelegate` 或自定义布局中处理。

---

## 执行优先级

| 任务 | 优先级 | 文件 | 难度 |
|:--|:--:|:--|:--:|
| 1. 改用 NSTextList 替代手动符号 | 🔴 P0 | `BlockRenderer.swift` + `MarkupDocumentBuilder.swift` | 中 |
| 2. blockquote 左竖线背景 | 🟡 P2 | `MarkupDocument+Render.swift` | 高 |
| 3. hr 改 NSTextAttachment | 🟡 P2 | `MarkupDocument+Render.swift` | 中 |
| 4. table 布局 | 🟢 P3 | 新建 `TableAttachmentRenderer.swift` | 高 |
