# XMarkup Demo App 重新配置设计规格

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:writing-plans` 创建实现计划。

**目标：** 重新配置 Demo App（UIKit/SwiftUI/AppKit 三端），新增 WebView 对比 Tab，扩展测试用例覆盖，建立三端统一设计规范。

**架构：** 四 Tab 结构（HTML 源码 / 渲染效果 / WebView / Span 数据），各平台使用各自原生组件渲染 AttributedString，新增约 13 个示例覆盖边界/排版/长内容/API 测试。

**技术栈：** UIKit (UITextView) / SwiftUI (Text+AttributedString) / AppKit (NSTextView) / WKWebView / SPM

---

## 1. 三端统一设计规范

### 1.1 核心原则

1. **视觉一致**：三端展示相同内容时，用户感知的排版、间距、颜色、字体应尽可能一致
2. **交互一致**：Tab 切换、列表导航、分组折叠等交互模式统一
3. **数据一致**：三端共享同一份 `DemoExamples.swift`，使用相同的解析和渲染 API
4. **平台原生**：各平台使用自己的原生组件，不跨平台桥接渲染视图
5. **允许差异**：平台特有的交互范式（如 macOS 侧边栏、iOS 手势返回）不强制统一

### 1.2 组件映射表

| 功能 | UIKit | SwiftUI | AppKit |
|------|-------|---------|--------|
| Tab 切换 | `UISegmentedControl` | `Picker(.segmented)` | `NSSegmentedControl` |
| AttributedString 渲染 | `UITextView`（不可编辑） | 原生 `Text(AttributedString)` | `NSTextView`（不可编辑） |
| WebView | `WKWebView` | `UIViewRepresentable`/`NSViewRepresentable` | `WKWebView` |
| 数据列表 | `UITableView` | `List` | `NSTableView` |
| 分组列表 | `UICollectionView`（分区） | `List` + `Section` | `NSOutlineView` 或 `NSTableView`（分组） |
| 导航 | `UINavigationController` | `NavigationStack` | `NSWindow` + toolbar |
| 代码高亮 | `UITextView` + 手动着色 | `Text` + foregroundColor | `NSTextView` + 手动着色 |
| 错误展示 | `UILabel` + 红色 | `Label` + `.red` | `NSTextField` + 红色 |
| 加载状态 | `UIActivityIndicatorView` | `ProgressView` | `NSProgressIndicator` |

### 1.3 Tab 结构（四端统一）

```
┌──────────────────────────────────────────────────┐
│  HTML 源码  │  渲染效果  │  WebView  │  Span 数据  │
├──────────────────────────────────────────────────┤
│                                                  │
│              [当前 Tab 内容区域]                   │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Tab 名称统一**：三端使用相同的标签文字和顺序：
- Tab 0：`HTML 源码`
- Tab 1：`渲染效果`
- Tab 2：`WebView`
- Tab 3：`Span 数据`

### 1.4 间距/边距规范

| 属性 | 值 |
|------|-----|
| Tab 控件顶部间距 | 8pt |
| Tab 控件水平边距 | 16pt |
| 内容区域与 Tab 间距 | 8pt |
| 内容区域水平内边距 | 16pt |
| 内容区域垂直内边距 | 8pt |
| WebView 页面边距 | 16px（通过 CSS body padding） |

### 1.5 颜色规范

| 元素 | UIKit | SwiftUI | AppKit |
|------|-------|---------|--------|
| 背景 | `.systemBackground` | 默认 | `.windowBackgroundColor` |
| 代码高亮 | `.systemGray6` 背景 | `.gray.opacity(0.1)` | `.controlBackgroundColor` |
| 链接色 | `.systemBlue` | `.blue` | `.linkColor` |
| 错误文字 | `.systemRed` | `.red` | `.systemRed` |
| 次要文字 | `.secondaryLabel` | `.secondary` | `.secondaryLabelColor` |

### 1.6 字体规范

| 元素 | 字体 |
|------|------|
| 源码/代码 | `.monospacedSystemFont` / `.monospaced` |
| 正文 | system default |
| Tab 标签 | system default（跟随系统） |

---

## 2. Tab 详情

### 2.1 HTML 源码 Tab

展示原始 HTML 字符串，基础语法着色（标签蓝色、属性绿色、文本默认）。

- **UIKit**：`UITextView`，不可编辑，monospaced 字体
- **SwiftUI**：`ScrollView` + `Text`，`.monospaced` 字体
- **AppKit**：`NSTextView`，不可编辑，monospaced 字体

### 2.2 渲染效果 Tab

XMarkup 解析 → `MarkupDocument.from()` → `render(theme:)` → 平台原生展示。

- **UIKit**：`UITextView`（不可编辑），通过 `NSAttributedStringRenderer.render()` 获取 `NSAttributedString`
- **SwiftUI**：原生 `Text(attributedString)`，直接使用 `AttributedString`
- **AppKit**：`NSTextView`（不可编辑），通过 `NSAttributedStringRenderer.render()` 获取 `NSAttributedString`

对于 `spacing` 分类的示例，自动应用对应的 `MarkupTheme`：
```swift
let theme: MarkupTheme = example.customTheme ?? .default
let attr = document.render(theme: theme)
```

### 2.3 WebView Tab（新增）

使用 `WKWebView` 加载原始 HTML，展示浏览器渲染效果作为对比基准。

- **UIKit**：`WKWebView` 直接使用
- **SwiftUI**：`UIViewRepresentable` 包装 `WKWebView`（无原生 SwiftUI WebView）
- **AppKit**：`WKWebView` 直接使用

注入基础 CSS 确保可读性：
```css
body {
    font-family: -apple-system, sans-serif;
    padding: 16px;
    margin: 0;
    line-height: 1.6;
}
img { max-width: 100%; height: auto; }
a { color: #0066CC; }
code { background: #f5f5f5; padding: 2px 4px; border-radius: 3px; }
```

### 2.4 Span 数据 Tab

展示结构化数据：blocks 列表 + 每个 block 的 inlines/attachment 详情。

- **UIKit**：`UITableView`（分组样式），block 为 section，inline 为 row
- **SwiftUI**：`List` + `Section` + `DisclosureGroup`
- **AppKit**：`NSTableView`（分组样式）

---

## 3. DemoExamples 扩展

### 3.1 新增分类

在现有 8 个分类基础上新增 4 个：

```swift
enum Category: String, CaseIterable {
    case basic = "基础格式"        // 已有
    case color = "颜色"           // 已有
    case heading = "标题"          // 已有
    case link = "链接"            // 已有
    case mixed = "混合样式"        // 已有
    case complex = "复杂 HTML"     // 已有
    case scenario = "场景实战"      // 已有
    case media = "媒体"           // 已有
    case boundary = "边界用例"      // 新增
    case spacing = "段落排版"       // 新增
    case longform = "长内容"        // 新增
    case apiTest = "API 测试"      // 新增
}
```

### 3.2 边界用例（boundary）— 6 个

| ID | 标题 | HTML 要点 |
|----|------|-----------|
| `emoji-only` | 纯 Emoji | 🔄❤️🎉✨👀💬🔥💡🚀 |
| `empty-doc` | 空文档 | `""` |
| `plain-text` | 纯文本无标签 | 一段没有任何 HTML 标签的纯文字 |
| `unicode-mix` | Unicode 混合 | `مرحبا 你好 こんにちは 안녕하세요 🌍 Héllo wörld` |
| `nested-deep` | 多层嵌套 | `<b><i><u><s>四层</s></u></i></b>` |
| `html-entities` | HTML 实体转义 | `&amp; &lt; &gt; &quot; &#x1F600;` |

### 3.3 段落排版（spacing）— 4 个

| ID | 标题 | theme 配置 |
|----|------|-----------|
| `spacing-default` | 默认间距 | `.default`（8/8/0） |
| `spacing-compact` | 紧凑排版 | `spacingBefore:2, spacingAfter:2` |
| `spacing-relaxed` | 宽松排版 + 行距 | `spacingBefore:16, spacingAfter:16, lineSpacing:6` |
| `spacing-none` | 零间距 | `spacingBefore:0, spacingAfter:0` |

HTML 内容统一为多段落文本（4-5 个 `<p>`），方便对比不同间距效果。

`DemoExample` 结构体新增可选的 `customTheme` 字段：
```swift
struct DemoExample {
    let id: String
    let title: String
    let description: String
    let html: String
    let category: Category
    let customTheme: MarkupTheme?  // 新增：该示例使用的自定义主题
}
```

### 3.4 长内容（longform）— 2 个

| ID | 标题 | 内容 |
|----|------|------|
| `long-article` | 完整技术文章 | ~1000 字，含 h1-h4、p、blockquote、code、a、ul/li |
| `gallery` | 多媒体相册 | 6+ 张图片混合文字描述，展示图片占位和间距 |

### 3.5 API 测试（apiTest）— 2 个

| ID | 标题 | 测试内容 |
|----|------|---------|
| `api-append` | appending() 拼接 | 两段独立 HTML 分别解析，append 后渲染 |
| `api-themes` | 多主题对比 | 同一 HTML 内容在不同 theme 下渲染（default/chat/article） |

---

## 4. 文件变更

### 新建文件

| 文件 | 说明 |
|------|------|
| `Shared/WebViewRenderer.swift` | 共享 WebView HTML 加载 + 基础 CSS 注入 |
| `Shared/ThemePresets.swift` | spacing 分类示例对应的自定义 theme 定义 |
| `UIKit/WebViewViewController.swift` | UIKit WKWebView 控制器 |
| `SwiftUI/WebViewPreviewView.swift` | SwiftUI UIViewRepresentable/NSViewRepresentable 包装 |
| `AppKit/WebViewViewController.swift` | AppKit WKWebView 控制器 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `Shared/DemoExamples.swift` | 新增 ~14 个示例 + 4 个分类 + customTheme 字段 |
| `UIKit/ExampleDetailViewController.swift` | 新增 WebView Tab |
| `UIKit/RenderedTextViewController.swift` | 支持 customTheme |
| `SwiftUI/ExampleDetailView.swift` | 新增 WebView Tab |
| `SwiftUI/RenderedTextView.swift` | 原生 `Text(AttributedString)` + customTheme |
| `AppKit/ExampleDetailViewController.swift` | 新增 WebView Tab |
| `AppKit/RenderedTextViewController.swift` | 支持 customTheme |

---

## 5. 示例分类总览

| 分类 | 数量 | 说明 |
|------|------|------|
| 基础格式 | 5 | bold/italic/underline/strikethrough/嵌套 |
| 颜色 | 3 | 前景色/背景色/组合 |
| 标题 | 1 | h1-h6 |
| 链接 | 2 | 基础链接/带颜色链接 |
| 混合样式 | 3 | 字号/代码/高亮 |
| 复杂 HTML | 3 | 富文本/商品卡片/边界 |
| 场景实战 | 7 | 文章/聊天/通知/文档/社交/商品/媒体混排 |
| 媒体 | 1 | 图文音视频 |
| **边界用例** | **6** | **emoji/空文档/纯文本/Unicode/嵌套/实体** |
| **段落排版** | **4** | **默认/紧凑/宽松/零间距** |
| **长内容** | **2** | **技术文章/相册** |
| **API 测试** | **2** | **append/多主题** |
| **合计** | **~39** | |

---

## 6. 验证标准

- 三端 Tab 数量、名称、顺序一致
- 所有 39 个示例在三端均可正常展示
- WebView Tab 能加载并渲染所有 HTML 示例
- 渲染效果 Tab 展示的排版与 WebView 对比可直观看出差异
- spacing 分类的 4 个示例清晰展示不同段落间距效果
- API 测试示例正确演示 appending 和多主题功能
