# iOS Swift 桥接层修复优化计划

> **面向 AI Agent 执行者：** 按任务顺序执行。每个任务先修改代码，再补充对应测试。
> 步骤使用 `- [ ]` 语法跟踪进度。

**目标：** 修复 iOS 桥接层中 4 类关键问题 + 补全 CSS/sub/sup 渲染 + 完善自定义系统

**架构：**
- `MarkupDocumentBuilder` — C 核心 span → Swift 块/内联模型，问题在去重逻辑
- `InlineRenderer` — Swift 内联 → `AttributedString` attributes，问题在跳过的渲染项
- `BlockRenderer` — Swift 块 → `AttributedString` attributes
- `MarkupTheme` + `TagStyleKey` — 用户自定义系统的 DSL，问题在缺 key

**技术栈：** Swift 6+, AttributedString/NSAttributedString, UIKit/AppKit

---

## 任务 1：修复块级去重导致语义容器丢失

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift:40-55`
- 新增测试：`platforms/ios/Tests/XMarkupTests/Core/MarkupDocumentBuilderTests.swift`

### 问题分析

当前 `blockSpans` 去重逻辑移除所有包含子块（不同标签）的父块。

```
输入: <blockquote><p>text</p></blockquote>
→ blockquote(0,5) 和 p(0,5) 同时被含判断移除 → 0 个块 → 降级为纯段落
→ blockquote 样式丢失!
```

同理影响：`<article>`, `<section>`, `<header>`, `<footer>`, `<table>` 等所有含子块的容器标签。
纯容器 `<div>` 去重是合理的（防 `<div><p>text</p></div>` 内容重复）。

### 修复方案

只对纯容器标签（div/span）执行去重，其他语义容器全部保留：

- [ ] **步骤 1：添加可安全去重的容器白名单**

```swift
private static let dedupSafeContainers: Set<XMarkupTag> = [
    .division, .span,
]
```

放在 `MarkupDocumentBuilder.swift` 的 `from()` 方法附近。

- [ ] **步骤 2：修改 filter 逻辑**

```swift
// 修改前
blockSpans = blockSpans.filter { outer in
    ...
    return !hasChild
}

// 修改后
blockSpans = blockSpans.filter { outer in
    guard Self.dedupSafeContainers.contains(outer.tag) else {
        return true  // 语义容器（blockquote/article 等）直接保留
    }
    ...
    return !hasChild
}
```

**运行测试：** `swift test --filter MarkupDocumentBuilderTests`

## 任务 2：实现 4 个 CSS 属性渲染

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Rendering/InlineRenderer.swift` — 实现 fontWeight/lineHeight/letterSpacing/textAlign
- 新增测试：`platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift`

### 2a）fontWeight

`InlineStyle.fontWeight(String)` — 字符串可能是 `"bold"`, `"700"`, `"normal"`

- [ ] **步骤 1：编写失败的测试**

RenderTests.swift 中新增：
```swift
func testCSSCustomFontWeightBold() {
    let html = "<span style=\"font-weight:bold\">bold text</span>"
    // 验证 NSAttributedString 中对应范围的字体包含 bold trait
}
```

- [ ] **步骤 2：实现 fontWeight 渲染**

在 `InlineRenderer.swift` 的 `applyInlineStyle` 中添加：

```swift
case .fontWeight(let weight):
    for run in attr[range].runs {
        #if canImport(UIKit)
        let currentFont = run.uiKit.font ?? theme.baseFont
        if weight == "bold" || weight == "700" {
            attr[run.range].uiKit.font = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .bold)
        } else if weight == "normal" || weight == "400" {
            attr[run.range].uiKit.font = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .regular)
        } else if let w = Float(weight), w >= 600 {
            attr[run.range].uiKit.font = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .bold)
        } else if let w = Float(weight), w <= 300 {
            attr[run.range].uiKit.font = UIFont.systemFont(ofSize: currentFont.pointSize, weight: .light)
        }
        #elseif canImport(AppKit)
        // AppKit 同理
        #endif
    }
```

**注意：** `applyInlineStyle` 当前没有 `theme` 参数，需要给 `applyFontTrait` 和 `applyInlineStyle` 传递 theme 或 baseFont。

### 2b）letterSpacing

`InlineStyle.letterSpacing(Float)` — 已在 C++ 核心换算为 px 数值。

- [ ] **步骤 3：实现 letterSpacing 渲染**

```swift
case .letterSpacing(let spacing):
    #if canImport(UIKit)
    attr[range].uiKit.kern = CGFloat(spacing)
    #elseif canImport(AppKit)
    attr[range].appKit.kern = CGFloat(spacing)
    #endif
```

### 2c）lineHeight

`InlineStyle.lineHeight(Float)` — 数值（如 1.5 是倍数，24 是 px）。

- [ ] **步骤 4：实现 lineHeight 渲染**

```swift
case .lineHeight(let height):
    for run in attr[range].runs {
        var paraStyle = (run.uiKit.paragraphStyle ?? NSParagraphStyle.default).mutableCopy() as! NSMutableParagraphStyle
        paraStyle.minimumLineHeight = CGFloat(height)
        paraStyle.maximumLineHeight = CGFloat(height)
        #if canImport(UIKit)
        attr[run.range].uiKit.paragraphStyle = paraStyle
        #elseif canImport(AppKit)
        attr[run.range].appKit.paragraphStyle = paraStyle
        #endif
    }
```

### 2d）textAlign

`InlineStyle.textAlign(String)` — "left", "center", "right", "justify"

- [ ] **步骤 5：实现 textAlign 渲染**

```swift
case .textAlign(let alignment):
    var paraStyle = (run.uiKit.paragraphStyle ?? NSParagraphStyle.default).mutableCopy() as! NSMutableParagraphStyle
    switch alignment {
    case "center": paraStyle.alignment = .center
    case "right": paraStyle.alignment = .right
    case "justify": paraStyle.alignment = .justified
    default: paraStyle.alignment = .left
    }
```

- [ ] **步骤 6：解除 `break`**

删除 `InlineRenderer.swift:224` 的行：
```swift
case .fontWeight, .lineHeight, .letterSpacing, .textAlign:
    break  // 删除这 2 行
```

**运行测试：** `swift test --filter RenderTests`

## 任务 3：实现 sub/sup 标签渲染

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Rendering/InlineRenderer.swift`
- 新增测试：`platforms/ios/Tests/XMarkupTests/Rendering/RenderTests.swift`

### 渲染策略

sub/sup 需要：字号缩小 + baseline offset ↑↓

- [ ] **步骤 1：编写失败的测试**

```swift
func testSubscriptRendering() {
    let html = "<p>H<sub>2</sub>O</p>"
    // 验证 NSAttributedString 中 sub 范围的 baselineOffset < 0
}
```

- [ ] **步骤 2：实现渲染**

```swift
case .subscriptText:
    for run in attr[range].runs {
        #if canImport(UIKit)
        if let font = run.uiKit.font {
            let smallFont = UIFont(descriptor: font.fontDescriptor, size: font.pointSize * 0.65)
            attr[run.range].uiKit.font = smallFont
            attr[run.range].uiKit.baselineOffset = -font.pointSize * 0.2
        }
        #elseif canImport(AppKit)
        // AppKit 同理
        #endif
    }

case .superscript:
    for run in attr[range].runs {
        #if canImport(UIKit)
        if let font = run.uiKit.font {
            let smallFont = UIFont(descriptor: font.fontDescriptor, size: font.pointSize * 0.65)
            attr[run.range].uiKit.font = smallFont
            attr[run.range].uiKit.baselineOffset = font.pointSize * 0.35
        }
        #elseif canImport(AppKit)
        // AppKit 同理
        #endif
    }
```

**运行测试：** `swift test --filter RenderTests`

## 任务 4：补充 TagStyleKey + attachment 修正

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Theme/TagStyleKey.swift`
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift`
- 修改：`platforms/ios/Sources/XMarkup/Rendering/RenderHelpers.swift`

- [ ] **步骤 1：TagStyleKey 补充 sub/sup/table case**

```swift
public enum TagStyleKey: String, ... {
    // ... 已有 case ...
    case subscriptText      // <sub>
    case superscript        // <sup>
    case table              // <table>
    case tableRow           // <tr>
    case tableCell          // <td>
    case tableHeader        // <th>
}
```

- [ ] **步骤 2：blockStyleKey / inlineStyleKey 映射补充**

`RenderHelpers.swift` 的 `blockStyleKey` 添加 `.table` → `.table`
`RenderHelpers.swift` 的 `inlineStyleKey` 添加 `.subscriptText` → `.subscript`, `.superscript` → `.superscript`

- [ ] **步骤 3：修复 attachmentContent 的 default 分支**

`MarkupDocumentBuilder.swift:321-331`：

```swift
// 修改前
default:
    return .image(src: src ?? "")

// 修改后
default:
    return .custom(type: "unknown", metadata: ["src": src ?? ""])
```

- [ ] **步骤 4：补充对应单元测试**

`TagStyleKeyTests.swift` 或 `RenderHelpersTests.swift` 中验证新增 case。

**运行测试：** `swift test --filter TagStyleKeyTests`

## 验证

```bash
# 全部测试
swift test

# 指定模块
swift test --filter MarkupDocumentBuilderTests
swift test --filter RenderTests
swift test --filter TagStyleKeyTests
```
