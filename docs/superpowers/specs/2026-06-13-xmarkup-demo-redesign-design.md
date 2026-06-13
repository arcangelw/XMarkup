# XMarkup Demo App 重做设计规格

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:writing-plans` 创建实现计划。本文档为规格说明（what & why），具体实现步骤（文件、代码、测试）由 writing-plans 阶段产出。

**目标：** 重做 XMarkup Demo App——以「HTML → 富文本渲染对标」为核心，建立原生 vs Web 的可信对比基线，按 HTML 标签族重组用例体系。仅保留 SwiftUI 单套源码（iOS + macOS 双 target 共享），分层抽离平台无关逻辑以便后期迁移 UIKit/AppKit。

**架构：** 数据层与渲染逻辑层平台无关（`Shared/`），SwiftUI 仅做展示；用例按 **12 族 ×「基础/嵌套/边界」二级分层**；原生与 Web 共享同一份 `DemoCanvasConfig` 基线配置；对比详情区自适应（`regular` 并排可拖拽 / `compact` 堆叠）。

**技术栈：** Swift 6 / SwiftUI（`NavigationSplitView`）/ XMarkup SPM / WKWebView / xcodegen

---

## 1. 背景与问题诊断

当前 Demo（`playground/ios/XMarkupDemo/`）三端并存（SwiftUI/UIKit/AppKit），存在三个核心问题：

### 1.1 对比基线不一致（"对比不明显"根因）

原生与 Web 各自定义画布参数，无共享基线：

| 维度 | Web（`WebViewRenderer.styledHTML`） | 原生（`NativeTextViewRepresentable`） |
|------|------|------|
| 左右 padding | `body { padding: 16px }` | iOS `UIEdgeInsets(8,16,8,16)` / macOS `NSSize(16,8)` |
| 垂直 padding | 16px | 8px |
| 行距 | `line-height: 1.6`（倍数语义） | `ParagraphTheme.lineSpacing: 3`（绝对值语义） |
| 字体 | `-apple-system` 默认 16px | `theme.baseFont` |

后果：padding/行高/字体全不一致，并排对比时差异被"配置噪音"淹没；且采用 **Tab 切换**（非同屏），需脑内记忆。

### 1.2 列表单层平铺过长

15 个 `Section` 直接堆在一个 `List` 里，71 个用例一屏看不完。

### 1.3 分类散乱、用例不全面

`basic`/`mixed`/`complex`/`scenario` 边界模糊；完全缺失**表格**用例（核心引擎已支持 `BlockNode.table`）；`apiTest` 需暂时下线但保留扩展。

---

## 2. 设计决策汇总

| # | 决策点 | 选择 | 理由 |
|---|--------|------|------|
| 1 | 分类轴 | **双轴**：一级标签族 + 二级「基础/嵌套/边界」 | 既对齐 HTML 规范，又保留回归用例的边界层 |
| 2 | 一级族数量 | **12 族**（9 标签族 + 主题对比 + 综合实战 + 容错与边界） | 覆盖 HTML 实用子集 + 功能维度 |
| 3 | 容错用例归属 | **独立第 12 族集中放** | 输入侧通用容错，便于回归扫一遍 |
| 4 | 表格用例 | **补全真实复杂场景** | 填补空白，验证 `BlockNode.table` |
| 5 | 对比基线 | **共享 `DemoCanvasConfig`**，Web/原生同源 | 强制基线一致，差异 = 渲染器真实行为 |
| 6 | 基线方向 | **Web 为基准**，原生对齐 Web | 浏览器 = ground truth |
| 7 | 对比形态 | **自适应**：`regular` 并排（`HSplitView` 可拖拽）/ `compact` 堆叠 | macOS/iPad 并排，iPhone 堆叠 |
| 8 | 调试视图 | **抽屉降级**（源码/Span/日志），`apiTest` 可见性开关隐藏 | 不抢主对比舞台 |
| 9 | 改造范围 | **SwiftUI 先行**，UIKit/AppKit 删除 target | 数据层一次到位，UI 先打磨一套 |
| 10 | 迁移友好 | **分层抽离**：渲染/配置逻辑平台无关，SwiftUI 仅展示 | 后期 UIKit/AppKit 回归只换视图层 |
| 11 | 工程 | **xcodegen 双 target 单源码**（iOS 16+ / macOS 13+） | 部署目标/Info.plist 不同需分 target，源码同一份 |

---

## 3. 数据模型设计

### 3.1 一级族枚举

```swift
/// 用例一级分类 — 对齐 HTML 标签族 + 少量功能维度
enum ExampleFamily: String, CaseIterable {
    // —— 标签族（9 个，覆盖 HTML 实用子集）——
    case inlineText       = "内联文本"      // b/i/u/s/em/strong/sub/sup/code/mark
    case headingParagraph = "标题与段落"    // h1-h6 / p / br / hr / 段落间距
    case blockquotePre    = "引用与预格式"  // blockquote / pre
    case list             = "列表"          // ol / ul / li / dl / dt / dd
    case link             = "链接"          // a
    case table            = "表格"          // table / thead / tbody / tfoot / tr / th / td
    case media            = "媒体"          // img / video / audio / source / figure
    case semantic         = "语义容器"      // div / article / section / nav / aside / header / footer / address
    case inlineStyle      = "内联样式"      // span style（color / background / font-size / weight）
    // —— 功能族（3 个，非纯标签）——
    case theme            = "主题对比"      // customTheme / themeVariants / 段落间距配置驱动
    case showcase         = "综合实战"      // 长文 / 复杂结构 / 真实场景
    case robustness       = "容错与边界"    // 跨族通用容错（集中）

    /// 侧边栏图标（SF Symbol）
    var symbol: String { /* 每族配一个 SF Symbol */ }
}
```

### 3.2 二级分层枚举

```swift
/// 用例二级分层 — 仅适用于标签族（1-9）；功能族（10-12）不强制分层
enum ExampleTier: String, CaseIterable {
    case basic    = "基础"   // 单标签 / 最简用法
    case nested   = "嵌套"   // 组合 / 嵌套 / 多级 / 多属性
    case boundary = "边界"   // 该族特定边界（空标签 / 非法值 / 族内未闭合）
}
```

### 3.3 可见性

```swift
/// 用例可见性 — 支持 API 等功能暂时下线但数据保留
enum ExampleVisibility {
    case visible   // 正常展示
    case hidden    // 暂时下线（如 apiTest），数据保留便于后期恢复
}
```

### 3.4 用例模型（重做）

```swift
/// 单个 Demo 用例
struct DemoExample: Identifiable {
    let id: String
    let title: String
    let summary: String                       // 一句话说明（原 description）
    let html: String
    let family: ExampleFamily
    let tier: ExampleTier                     // 功能族可填 .basic 占位
    var visibility: ExampleVisibility = .visible
    var isRegression: Bool = false            // 回归用例标记（帮你发现问题的，列表标 ⓘ）
    var note: String? = nil                   // 验证点 / 已知差异说明（对比页展示）
    var themeOverride: MarkupTheme? = nil     // 单主题覆盖（渲染时传入）
    var themeVariants: [MarkupTheme]? = nil   // 多主题并排（主题对比族专用）
    var appendHTML: String? = nil             // 拼接第二段 HTML（appending 场景）
}
```

> **变更说明：** 原 `category` 单层枚举 → `family` + `tier` 双轴；新增 `visibility`/`isRegression`/`note`/`themeVariants`；`customTheme` → `themeOverride`，`secondHTML` → `appendHTML`（语义更清晰）。

### 3.5 用例目录（索引 + 搜索）

```swift
/// 用例目录 — 提供按族/层索引、搜索、可见性过滤
enum DemoCatalog {
    /// 全部用例（含 hidden，数据完整保留）
    static let all: [DemoExample] = [ /* 12 族用例 */ ]

    /// 可见用例（过滤 hidden，列表展示用）
    static var visible: [DemoExample] { all.filter { $0.visibility == .visible } }

    /// 按族分组（保留 ExampleFamily 定义顺序，仅含可见用例）
    static func groupedByFamily() -> [(family: ExampleFamily, tiers: [ExampleTier: [DemoExample]])]

    /// 跨族搜索（匹配 title / summary / id / html）
    static func search(_ query: String) -> [DemoExample]
}
```

### 3.6 画布基线配置（对比基线核心）

```swift
/// 对比画布基线 — Web 端 CSS 与原生端 textContainerInset 同源读取，强制基线一致
/// 默认值取 Web 当前合理值（Web 为基准，原生对齐）
struct DemoCanvasConfig: Equatable {
    // —— 内边距（pt / px 等价）——
    var paddingTop: CGFloat = 16
    var paddingLeading: CGFloat = 16
    var paddingBottom: CGFloat = 16
    var paddingTrailing: CGFloat = 16
    // —— 行距（Web line-height 倍数语义）——
    var lineHeight: CGFloat = 1.6
    // —— 基础字体 ——
    var baseFontSize: CGFloat = 16
    var baseFontFamily: String = "-apple-system"

    /// 原生文本视图内边距（条件编译）
    #if canImport(UIKit)
    var textContainerInset: UIEdgeInsets {
        UIEdgeInsets(top: paddingTop, left: paddingLeading,
                     bottom: paddingBottom, right: paddingTrailing)
    }
    #elseif canImport(AppKit)
    var textContainerInset: NSSize {
        NSSize(width: paddingLeading, height: paddingTop) // NSTextView 横纵不对称，纵向由段落间距补
    }
    #endif

    /// 生成 Web 端 CSS 片段（注入 WebViewRenderer）
    func cssString() -> String {
        """
        body { font-family: \(baseFontFamily), sans-serif;
               padding: \(paddingTop)px \(paddingTrailing)px \(paddingBottom)px \(paddingLeading)px;
               margin: 0; line-height: \(lineHeight);
               font-size: \(baseFontSize)px; }
        """
    }

    /// 对齐到 MarkupTheme.baseFont（原生端用同一字号）
    var baseFont: XMFont { XMFont.systemFont(ofSize: baseFontSize) }
}
```

> **行距对齐说明：** Web `line-height: 1.6` 是相对 font-size 的倍数；原生通过 `DemoRenderer` 将其换算为 `NSParagraphStyle` 行距设置。具体换算策略（`lineSpacing` 绝对值 vs `lineHeightMultiple`）在实现阶段验证视觉效果后确定，设计层面保证「同一配置源驱动两端」。

---

## 4. 用例体系

### 4.1 12 族定义与覆盖标签

| # | 族 | 覆盖标签 | 二级分层示例 |
|---|------|---------|------|
| 1 | 内联文本 | `b/i/u/s/em/strong/sub/sup/code/mark` | 基础=单标签 / 嵌套=四层组合 / 边界=族内未闭合 |
| 2 | 标题与段落 | `h1-h6/p/br/hr` | 基础=各级标题+hr/br / 嵌套=标题内含样式 / 边界=空段落 |
| 3 | 引用与预格式 | `blockquote/pre` | 基础=单层引用+pre / 嵌套=引用内列表 / 边界=空 pre |
| 4 | 列表 | `ol/ul/li/dl/dt/dd` | 基础=单级 / 嵌套=多级混合 / 边界=空 li·非连续序号 |
| 5 | 链接 | `a` | 基础=纯文本链 / 嵌套=链内含样式 / 边界=空 href |
| 6 | **表格（新增）** | `table/thead/tbody/tfoot/tr/th/td` | 基础=简单表 / 嵌套=跨列跨行 / 边界=空单元格 |
| 7 | 媒体 | `img/video/audio/source/figure` | 基础=单图/音视频 / 嵌套=图文混排 / 边界=损坏 src |
| 8 | 语义容器 | `div/article/section/nav/aside/header/footer/address` | 基础=单容器 / 嵌套=容器套容器 / 边界=空 div |
| 9 | 内联样式 | `span style` | 基础=单属性 / 嵌套=多属性 / 边界=非法颜色值 |
| 10 | 主题对比 | `themeOverride`/`themeVariants` 驱动 | 多主题并排 + 段落间距配置（spacing 系列） |
| 11 | 综合实战 | 长文 / 复杂结构 / 真实场景 | 技术文章 / 商品详情 / 聊天 / 通知 / 社交动态 / 长页 |
| 12 | 容错与边界 | 跨族通用容错（集中） | 空文档 / 纯文本 / Unicode 混合 / HTML 实体 / 未闭合标签 / 纯 Emoji |

### 4.2 旧用例收编映射（71 个，全部保留不丢失）

| 旧分类 | 旧用例 id | → 新族 | 新层 |
|--------|----------|--------|------|
| basic | bold / italic / underline / strikethrough / sub-sup | 内联文本 | basic |
| basic | bold-italic | 内联文本 | nested |
| boundary | nested-deep | 内联文本 | nested（四层嵌套归此） |
| color | text-color / bg-color / color-named | 内联样式 | basic |
| color | combined-color / color-rgb | 内联样式 | nested |
| mixed | font-size | 内联样式 | nested |
| mixed | code / mark | 内联文本 | basic（code/mark 是内联） |
| mixed | blockquote / pre | 引用与预格式 | basic |
| heading | headings | 标题与段落 | basic |
| heading | heading-with-inline | 标题与段落 | nested |
| boundary | hr-br | 标题与段落 | basic（hr/br 基本用法） |
| spacing | spacing-default / compact / relaxed / none | 主题对比 | ——（段落间距配置驱动） |
| link | link | 链接 | basic |
| link | link-styled | 链接 | nested |
| list | list-unordered / list-ordered | 列表 | basic |
| list | list-nested | 列表 | nested |
| media | image-single / video-single / audio-single | 媒体 | basic |
| media | video-source / media-mix | 媒体 | nested |
| semantic | semantic-article / semantic-nav-aside | 语义容器 | basic |
| semantic | semantic-figure / semantic-dl / semantic-address | 语义容器 | nested |
| themeCustom | theme-dark / theme-custom-code / theme-mark-link / theme-heading-override / theme-dynamic-resolve / theme-custom-prefor / theme-pipeline | 主题对比 | —— |
| complex | rich-text / product-card / edge-cases | 综合实战 | —— |
| complex | table-layout | 表格 | nested（移入表格族） |
| scenario | article / chat-msg / notification / api-doc / social-post / product-detail | 综合实战 | —— |
| longform | long-article / gallery | 综合实战 | —— |
| boundary | emoji-only / empty-doc / plain-text / unicode-mix / html-entities / unclosed-tags | 容错与边界 | ——（跨族容错集中） |
| apiTest | api-append / api-themes | （隐藏）`visibility = .hidden` | —— |

> **回归标记：** 所有原 `boundary` 用例 + 之前发现问题的用例（嵌套列表空白、非连续序号、bullet-code 重叠等）标记 `isRegression = true`，列表中显示 `ⓘ`，对比页展示 `note`。

### 4.3 表格族新增用例（真实复杂场景）

| id | 标题 | 场景 | 验证点 |
|----|------|------|--------|
| `table-basic` | 简单数据表 | thead + tbody，常规行列 | 基础表格渲染 |
| `table-finance` | 季度财务报表 | thead 跨列表头分组 + tbody + **tfoot 汇总行** | 跨列 colspan、表头分组、表尾 |
| `table-product-compare` | 产品参数对比 | 多列属性、`✓`/`✗`、加粗高亮 | 多列对齐、单元格内联样式 |
| `table-schedule` | 课程表 / 排班表 | **跨行 rowspan**，时间 × 星期矩阵 | rowspan 合并 |
| `table-nested-list` | 含嵌套列表的单元格 | td 内 `<ul><li>` | 单元格内块级嵌套 |
| `table-styled-cell` | 带样式高亮的表格 | td 内 `<span style>` 高亮异常值 | 单元格内 inlineStyle |
| `table-edge` | 表格边界 | 空单元格、colspan 越界、缺 thead | 容错（族内 boundary） |

---

## 5. 分层架构（迁移友好）

**核心原则：SwiftUI 只做"展示"，所有"渲染 + 配置"逻辑下沉到平台无关层。** 后期 UIKit/AppKit 回归时，`Shared/` 一行不改，只重写视图层。

```
Shared/                              ← 平台无关（纯 Swift + Foundation + XMarkup）
├── Data/
│   ├── DemoExample.swift            数据模型（family + tier + visibility + regression）
│   ├── DemoCatalog.swift            用例目录（分组索引 + 搜索 + 可见性过滤）
│   └── TableExamples.swift          新增：真实复杂表格用例
├── Config/
│   └── DemoCanvasConfig.swift       画布基线（padding/lineHeight/baseFont）+ 平台 inset 转换
├── Theme/
│   └── ThemePresets.swift           主题预设（沿用现有 spacingCompact 等）
├── Rendering/                       ← 渲染逻辑，不依赖任何 UI 框架
│   └── DemoRenderer.swift           HTML → NSAttributedString（封装 XMarkup，含多主题）
└── Web/
    └── WebViewRenderer.swift        HTML → 完整文档（纯字符串，注入 config CSS）

SwiftUI/                             ← 视图层（后期迁移时整体替换为 UIKit/ / AppKit/）
├── App.swift                        入口（iOS/macOS 条件编译）
├── Navigation/                      三栏导航（Sidebar 12 族 + 用例列表 + 搜索 + 回归标记）
│   ├── DemoRootView.swift           NavigationSplitView 根
│   ├── FamilySidebar.swift          侧边栏（12 族 + SF Symbol）
│   └── ExampleListView.swift        用例列表（按 tier 分组 Section）
├── Detail/                          对比详情（自适应并排/堆叠）
│   ├── CompareDetailView.swift      详情容器（regular HSplitView / compact VStack）
│   ├── NativeRenderView.swift       原生渲染（NativeTextRepresentable + config inset）
│   └── WebRenderView.swift          Web 渲染（WKWebView Representable + config CSS）
├── Debug/                           调试抽屉
│   ├── DebugDrawer.swift            底部抽屉容器
│   ├── HTMLSourceView.swift         HTML 源码（语法着色）
│   ├── SpanDataView.swift           结构化 blocks/inlines 数据
│   └── LogView.swift                解析/渲染日志
└── Components/
    ├── NativeTextRepresentable.swift  UITextView/NSTextView 包装（读 config inset）
    └── WebViewRepresentable.swift     WKWebView 包装（读 config CSS）
```

### 5.1 迁移契约（关键接口，平台无关）

```swift
// Shared/Rendering/DemoRenderer.swift
enum DemoRenderer {
    /// 单主题渲染：HTML → NSAttributedString（UIKit/AppKit/SwiftUI 统一调用）
    static func render(example: DemoExample, config: DemoCanvasConfig) throws -> NSAttributedString

    /// 多主题并排（主题对比族）
    static func renderVariants(example: DemoExample, config: DemoCanvasConfig) throws -> [NSAttributedString]

    /// 结构化数据（Span 数据视图用）
    static func parse(_ example: DemoExample) throws -> MarkupDocument
}

// Shared/Web/WebViewRenderer.swift（改造）
enum WebViewRenderer {
    /// 注入 config CSS 的完整 HTML 文档
    static func styledHTML(from html: String, config: DemoCanvasConfig) -> String
}
```

> **迁移保证：** UIKit/AppKit 回归时，`DemoRenderer.render()` / `DemoCanvasConfig.textContainerInset` / `WebViewRenderer.styledHTML(from:config:)` 签名不变，视图层（`UITextView`/`NSTextView`/`WKWebView`）直接调用。

---

## 6. UI 设计

### 6.1 列表入口（NavigationSplitView 三栏自适应）

**regular（iPad/macOS/横屏）— 三栏并排：**

```
┌─ 工具栏 ──────────────────────────────────────────────────────┐
│  [🔍 搜索]        [对比: 并排▾]  [画布配置▾]  [主题▾]  [调试]  │
├──────────┬──────────────┬─────────────────────────────────────┤
│ 侧边栏    │ 用例列表      │ 对比详情                             │
│ (12 族)  │ (按 tier 分组) │                                     │
│ ▾ 内联文本│ • 基础-粗体   │  （见 6.2 对比详情）                 │
│ ▾ 标题段落 │ • 嵌套-四层 ⓘ │                                     │
│ ▾ 列表    │ • 边界-未闭合⚠│                                     │
│ ▾ 表格    │              │                                     │
│ ...      │              │                                     │
└──────────┴──────────────┴─────────────────────────────────────┘
```

**compact（iPhone 竖屏）— 折叠为 push 导航：**
`12 族列表` →（tap）→ `用例列表（tier 分组）` →（tap）→ `对比详情`

- 侧边栏每族配 SF Symbol 图标
- 用例列表按 `tier`（基础/嵌套/边界）分 `Section`
- 回归用例标 `ⓘ`，容错/边界族用例标 `⚠️`
- 顶部搜索框跨族跨层搜索

### 6.2 对比详情（自适应并排/堆叠）

**regular — `HSplitView` 可拖拽分屏：**

```
┌────────────────────┬────────────────────┐
│ 原生渲染 (XMarkup) │ Web 渲染 (WKWebView)│
│                    │                    │
│   UITextView /     │   WKWebView        │
│   NSTextView       │   (config CSS)     │
│                    │                    │
│   ⟵ 可拖拽分隔条（HSplitView）⟶          │
└────────────────────┴────────────────────┘
▾ HTML 源码（折叠条，点开为调试抽屉）
```

**compact — `VStack` 上下堆叠：**

```
┌────────────────────────┐
│ 原生渲染 (XMarkup)      │
│   UITextView            │
├────────────────────────┤
│ Web 渲育 (WKWebView)    │
│   WKWebView             │
└────────────────────────┘
```

- 两端共享同一 `DemoCanvasConfig` → padding/行高/字体对齐
- 若用例有 `note`，对比区顶部显示一行验证点提示
- `themeVariants` 用例（主题对比族）→ 原生区显示多主题纵向并排

### 6.3 macOS 专属优化

- **工具栏集中操作**：对比模式切换（并排/堆叠 `Segmented`）、画布配置 popover（实时调 padding/字体/行高）、主题切换 popover、调试入口
- **可拖拽分屏**：`HSplitView` 原生 | Web，分隔条可拖动调比例
- **键盘快捷键**：`⌘F` 搜索 / `⌘1` 并排 / `⌘2` 堆叠 / `⌘D` 调试 / `⌘,` 画布配置
- **菜单栏**：标准 macOS 菜单（视图/窗口/关于）
- **侧边栏**：`.sidebar` 列宽样式，可折叠

### 6.4 调试抽屉

`HTML 源码 / Span 数据 / 日志` 三项移出主对比区，收入详情页底部抽屉（iOS sheet / macOS popover）：

- **HTML 源码**：原始 HTML + 基础语法着色（标签蓝/属性绿）
- **Span 数据**：结构化 `blocks` + 每 block 的 `inlines`/`attachment`（`DisclosureGroup` 展开）
- **日志**：解析/渲染过程日志（`LogCollector`）

---

## 7. 工程结构（xcodegen 双 target 单源码）

### 7.1 目录调整

- **删除**：`XMarkupDemo/UIKit/`、`XMarkupDemo/AppKit/` 整个目录
- **重构**：`XMarkupDemo/Shared/` 拆为 `Data/`、`Config/`、`Theme/`、`Rendering/`、`Web/`
- **重构**：`XMarkupDemo/SwiftUI/` 拆为 `Navigation/`、`Detail/`、`Debug/`、`Components/`
- **保留**：`project.yml`（重写 targets）

### 7.2 project.yml 目标结构（草案）

```yaml
name: XMarkupDemo
options:
  bundleIdPrefix: com.xmarkup.demo
  deploymentTarget:
    iOS: "16.0"
    macOS: "13.0"           # NavigationSplitView 三栏需 macOS 13+
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

packages:
  XMarkup:
    path: ../../..

settings:
  base:
    SWIFT_VERSION: "6.0"

targets:
  XMarkupDemoSwiftUI:         # iOS
    type: application
    platform: iOS
    sources:
      - path: XMarkupDemo/Shared
      - path: XMarkupDemo/SwiftUI
    dependencies:
      - package: XMarkup
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: "XMarkup Demo"
        MARKETING_VERSION: "2.0.0"      # 重做版本号
        CURRENT_PROJECT_VERSION: "1"
        PRODUCT_BUNDLE_IDENTIFIER: com.xmarkup.demo.swiftui

  XMarkupDemoSwiftUIMac:      # macOS（共享同一套源码）
    type: application
    platform: macOS
    sources:
      - path: XMarkupDemo/Shared
      - path: XMarkupDemo/SwiftUI
    dependencies:
      - package: XMarkup
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: "XMarkup Demo"
        MARKETING_VERSION: "2.0.0"
        CURRENT_PROJECT_VERSION: "1"
        PRODUCT_BUNDLE_IDENTIFIER: com.xmarkup.demo.swiftui.mac
        CODE_SIGN_IDENTITY: "-"
```

> 平台差异靠源码内 `#if os(macOS)` + `@Environment(\.horizontalSizeClass)` 处理，源码同一份。

---

## 8. 分阶段实现计划概要

> 详细步骤（文件/代码/测试）由 `superpowers:writing-plans` 产出。此处仅给阶段划分与依赖。

### P0 — 平台无关基础层（先做，三端共享受益）

1. **数据模型**：`DemoExample` 新模型（family/tier/visibility/regression）+ `ExampleFamily`/`ExampleTier`/`ExampleVisibility` 枚举
2. **用例目录**：`DemoCatalog`（分组/搜索/可见性）+ 12 族用例重排（收编 71 旧用例）
3. **表格用例**：`TableExamples.swift`（7 个真实复杂表格用例）
4. **画布配置**：`DemoCanvasConfig`（含平台 inset 转换 + CSS 生成）
5. **渲染逻辑层**：`DemoRenderer`（封装 XMarkup，含多主题）+ `WebViewRenderer` 改造（接 config）

### P1 — SwiftUI 视图层（核心体验）

6. **导航骨架**：`NavigationSplitView` 三栏 + 侧边栏 12 族 + 用例列表（tier 分组 + 搜索 + 回归标记）
7. **对比详情**：`CompareDetailView`（regular `HSplitView` / compact `VStack`）+ `NativeRenderView` + `WebRenderView`
8. **调试抽屉**：`DebugDrawer` + 源码/Span/日志三视图
9. **工程切换**：删除 UIKit/AppKit，重写 `project.yml` 双 target，`xcodegen generate` 验证编译

### P2 — macOS 精细化 + 打磨

10. **macOS 工具栏**：对比模式/画布配置/主题/调试 popover
11. **键盘快捷键** + 菜单栏
12. **画布配置实时联动**：调参即时重渲染原生+Web
13. **回归标记 + note 提示**完善

---

## 9. 验证标准

- [ ] 12 族全部有可见用例，原 71 用例无丢失（收编映射可追溯）
- [ ] 表格族 7 个用例覆盖 colspan/rowspan/tfoot/嵌套列表/内联样式/边界
- [ ] `DemoCanvasConfig` 单一配置源驱动 Web CSS 与原生 inset，对比区 padding/行高/字体肉眼对齐
- [ ] `regular`（iPad/macOS）原生 | Web 可拖拽并排；`compact`（iPhone）上下堆叠
- [ ] macOS 工具栏（对比模式/画布配置/主题/调试）+ 键盘快捷键可用
- [ ] 调试抽屉收纳源码/Span/日志；`apiTest` 用例 `visibility = .hidden` 不出现在列表但数据保留
- [ ] `Shared/` 层无 SwiftUI/UIKit/AppKit import（`DemoRenderer`/`DemoCanvasConfig`/`DemoCatalog` 纯平台无关）
- [ ] iOS + macOS 双 target 共享同一套源码，`xcodegen generate` 后均能编译运行
- [ ] 回归用例（`isRegression`）列表标 `ⓘ`，对比页显示 `note`

---

## 10. 范围边界

- **本期只做渲染对比**：API 功能展示（`apiTest`）暂时下线（`visibility = .hidden`），数据保留便于后期恢复
- **本期只做 SwiftUI**：UIKit/AppKit 删除 target，但 `Shared/` 分层保证后期迁移只换视图层
- **Web 为对比基准**：不追求原生"超过"Web，而追求"忠实还原"Web 渲染，差异即待优化项
- **行距换算策略**：`lineHeight` → 原生 `NSParagraphStyle` 的具体映射（`lineSpacing` vs `lineHeightMultiple`）在 P0 实现阶段视觉验证后确定
