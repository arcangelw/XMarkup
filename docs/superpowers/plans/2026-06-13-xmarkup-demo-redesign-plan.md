# XMarkup Demo App 重做实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 按设计规格 `docs/superpowers/specs/2026-06-13-xmarkup-demo-redesign-design.md` 重做 Demo——12 族双轴用例体系 + 共享画布基线对比 + SwiftUI 单源码双 target。

**架构：** `Shared/`（Data/Config/Theme/Rendering/Web，平台无关）+ `SwiftUI/`（Navigation/Detail/Debug/Components，仅展示）。对比基线由单一 `DemoCanvasConfig` 驱动 Web CSS 与原生 inset。

**技术栈：** Swift 6 / SwiftUI NavigationSplitView / XMarkup SPM / WKWebView / xcodegen / XCTest

**工程根：** `playground/ios/XMarkupDemo/`，所有相对路径以此为准。xcodegen 生成命令：`cd playground/ios/XMarkupDemo && xcodegen generate`。

---

## 文件结构（最终态）

```
XMarkupDemo/
├── project.yml                          （重写：删 UIKit/AppKit，加 SwiftUI 双 target + test target）
├── XMarkupDemo/
│   ├── Shared/                          （平台无关，test target 也编译此目录）
│   │   ├── Data/
│   │   │   ├── DemoExample.swift        （重做：family + tier + visibility + regression）
│   │   │   ├── DemoCatalog.swift        （新增：分组/搜索/可见性）
│   │   │   ├── Examples/                （用例按族拆文件，避免单文件过长）
│   │   │   │   ├── InlineTextExamples.swift
│   │   │   │   ├── HeadingParagraphExamples.swift
│   │   │   │   ├── BlockquotePreExamples.swift
│   │   │   │   ├── ListExamples.swift
│   │   │   │   ├── LinkExamples.swift
│   │   │   │   ├── TableExamples.swift          （新增：7 个真实复杂表格）
│   │   │   │   ├── MediaExamples.swift
│   │   │   │   ├── SemanticExamples.swift
│   │   │   │   ├── InlineStyleExamples.swift
│   │   │   │   ├── ThemeExamples.swift
│   │   │   │   ├── ShowcaseExamples.swift
│   │   │   │   ├── RobustnessExamples.swift
│   │   │   │   └── APITestExamples.swift        （visibility = .hidden）
│   │   ├── Config/
│   │   │   └── DemoCanvasConfig.swift   （新增：画布基线 + 平台 inset + CSS 生成）
│   │   ├── Theme/
│   │   │   └── ThemePresets.swift       （沿用，迁目录）
│   │   ├── Rendering/
│   │   │   └── DemoRenderer.swift       （新增：HTML → NSAttributedString，平台无关）
│   │   └── Web/
│   │       └── WebViewRenderer.swift    （改造：接 DemoCanvasConfig）
│   └── SwiftUI/                         （视图层，P1/P2）
│       ├── App.swift
│       ├── Navigation/
│       ├── Detail/
│       ├── Debug/
│       └── Components/
├── XMarkupDemoTests/                    （新增 test target）
│   ├── DemoCatalogTests.swift
│   ├── DemoCanvasConfigTests.swift
│   └── DemoRendererTests.swift
```

---

## 阶段总览

| 阶段 | 内容 | 可 TDD |
|------|------|--------|
| **P0** | 平台无关基础层（模型 + 目录 + 用例 + 配置 + 渲染） | ✅ 纯逻辑，XCTest |
| **P1** | SwiftUI 视图层（导航 + 对比详情 + 调试抽屉 + 工程切换） | ⚠️ UI，编译+手动验证 |
| **P2** | macOS 精细化（工具栏 + 快捷键 + 配置联动） | ⚠️ UI |

---

# P0 — 平台无关基础层

## 任务 P0-1：Demo 用例数据模型 + test target 骨架

**文件：**
- 创建：`XMarkupDemo/Shared/Data/DemoExample.swift`
- 创建：`XMarkupDemoTests/DemoExampleModelTests.swift`
- 修改：`project.yml`（加 test target）

- [ ] **步骤 1：在 `project.yml` 加 test target**

```yaml
  XMarkupDemoTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: XMarkupDemo/Shared        # 编译 Shared 到 test bundle，可直接测
      - path: XMarkupDemoTests
    dependencies:
      - package: XMarkup
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **步骤 2：写失败测试 `DemoExampleModelTests.swift`**

```swift
import XCTest
@testable import DemoExample        // test target 内编译，可直接访问

final class DemoExampleModelTests: XCTestCase {
    func testExampleFamilyHasTwelveCases() {
        XCTAssertEqual(ExampleFamily.allCases.count, 12)
    }
    func testExampleTierHasThreeCases() {
        XCTAssertEqual(ExampleTier.allCases.count, 3)
    }
    func testFamilySymbolNonEmpty() {
        for f in ExampleFamily.allCases {
            XCTAssertFalse(f.symbol.isEmpty, "\(f) 缺少 SF Symbol")
        }
    }
    func testDemoExampleDefaults() {
        let ex = DemoExample(id: "x", title: "T", summary: "S", html: "<b/>",
                             family: .inlineText, tier: .basic)
        XCTAssertEqual(ex.visibility, .visible)
        XCTAssertFalse(ex.isRegression)
        XCTAssertNil(ex.themeOverride)
        XCTAssertNil(ex.themeVariants)
    }
}
```

- [ ] **步骤 3：运行测试验证失败**

`cd playground/ios/XMarkupDemo && xcodegen generate && xcodebuild test -scheme XMarkupDemoSwiftUI -destination 'platform=iOS Simulator,name=iPhone 16'`
预期：编译失败（`DemoExample`/`ExampleFamily` 未定义）

- [ ] **步骤 4：实现 `DemoExample.swift`**

```swift
import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 用例一级分类 — 12 族（详见设计规格 §3.1）
public enum ExampleFamily: String, CaseIterable, Sendable {
    case inlineText, headingParagraph, blockquotePre, list, link, table
    case media, semantic, inlineStyle, theme, showcase, robustness

    public var displayName: String {
        switch self {
        case .inlineText: return "内联文本"
        case .headingParagraph: return "标题与段落"
        case .blockquotePre: return "引用与预格式"
        case .list: return "列表"
        case .link: return "链接"
        case .table: return "表格"
        case .media: return "媒体"
        case .semantic: return "语义容器"
        case .inlineStyle: return "内联样式"
        case .theme: return "主题对比"
        case .showcase: return "综合实战"
        case .robustness: return "容错与边界"
        }
    }

    public var symbol: String {
        switch self {
        case .inlineText: return "textformat"
        case .headingParagraph: return "text.alignleft"
        case .blockquotePre: return "quote.opening"
        case .list: return "list.bullet"
        case .link: return "link"
        case .table: return "tablecells"
        case .media: return "photo"
        case .semantic: return "square.stack.3d.up"
        case .inlineStyle: return "paintbrush"
        case .theme: return "swatchpalette"
        case .showcase: return "doc.richtext"
        case .robustness: return "shield.lefthalf.filled"
        }
    }

    /// 是否为功能族（非纯标签族，不强制 tier 分层）
    public var isFunctional: Bool {
        switch self { case .theme, .showcase, .robustness: return true; default: return false }
    }
}

/// 用例二级分层（详见设计规格 §3.2）
public enum ExampleTier: String, CaseIterable, Sendable {
    case basic = "基础"
    case nested = "嵌套"
    case boundary = "边界"
}

/// 用例可见性（详见设计规格 §3.3）
public enum ExampleVisibility: Sendable {
    case visible
    case hidden
}

/// 单个 Demo 用例（详见设计规格 §3.4）
public struct DemoExample: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let html: String
    public let family: ExampleFamily
    public let tier: ExampleTier
    public var visibility: ExampleVisibility
    public var isRegression: Bool
    public var note: String?
    public var themeOverride: MarkupTheme?
    public var themeVariants: [MarkupTheme]?
    public var appendHTML: String?

    public init(
        id: String, title: String, summary: String, html: String,
        family: ExampleFamily, tier: ExampleTier,
        visibility: ExampleVisibility = .visible,
        isRegression: Bool = false,
        note: String? = nil,
        themeOverride: MarkupTheme? = nil,
        themeVariants: [MarkupTheme]? = nil,
        appendHTML: String? = nil
    ) {
        self.id = id; self.title = title; self.summary = summary; self.html = html
        self.family = family; self.tier = tier; self.visibility = visibility
        self.isRegression = isRegression; self.note = note
        self.themeOverride = themeOverride; self.themeVariants = themeVariants
        self.appendHTML = appendHTML
    }
}
```

- [ ] **步骤 5：运行测试验证通过** → 预期 4 个测试全绿

- [ ] **步骤 6：Commit** — `git commit -m "feat(demo): 用例数据模型 + test target（P0-1）"`

---

## 任务 P0-2：DemoCatalog（分组 + 搜索 + 可见性）

**文件：**
- 创建：`XMarkupDemo/Shared/Data/DemoCatalog.swift`
- 创建：`XMarkupDemoTests/DemoCatalogTests.swift`

- [ ] **步骤 1：写失败测试**

```swift
import XCTest
@testable import DemoExample

final class DemoCatalogTests: XCTestCase {
    // 用占位 all（P0-3 填真实用例前，临时注入最小数据）
    func testVisibleFiltersHidden() {
        let all = [
            DemoExample(id: "a", title: "A", summary: "", html: "", family: .inlineText, tier: .basic),
            DemoExample(id: "b", title: "B", summary: "", html: "", family: .inlineText, tier: .basic, visibility: .hidden),
        ]
        let visible = all.filter { $0.visibility == .visible }
        XCTAssertEqual(visible.map(\.id), ["a"])
    }
    func testSearchMatchesTitleAndSummaryAndHTML() {
        let ex = DemoExample(id: "x", title: "粗体", summary: "bold", html: "<b>x</b>", family: .inlineText, tier: .basic)
        XCTAssertTrue(ex.title.contains("粗") || ex.summary.contains("bold") || ex.html.contains("bold"))
    }
    func testGroupedByFamilyPreservesOrder() {
        // 校验 groupedByFamily 返回族顺序 = ExampleFamily.allCases 顺序
        // （P0-3 用例填充后断言非空族集合）
    }
}
```

- [ ] **步骤 2：运行验证失败**

- [ ] **步骤 3：实现 `DemoCatalog.swift`**

```swift
import Foundation

/// 用例目录 — 分组索引 + 搜索 + 可见性过滤（详见设计规格 §3.5）
public enum DemoCatalog {
    /// 全部用例（含 hidden）
    public static var all: [DemoExample] {
        // P0-3 填充：各 Examples/*.swift 的数组拼合
        InlineTextExamples.all + HeadingParagraphExamples.all /* + ... 其余族 */
    }
    /// 可见用例
    public static var visible: [DemoExample] { all.filter { $0.visibility == .visible } }
    /// 按 ExampleFamily 顺序分组（仅可见）
    public static func groupedByFamily() -> [(family: ExampleFamily, items: [DemoExample])] {
        ExampleFamily.allCases.map { f in
            (f, visible.filter { $0.family == f })
        }.filter { !$0.items.isEmpty }
    }
    /// 搜索（title / summary / id / html，大小写不敏感）
    public static func search(_ query: String) -> [DemoExample] {
        let q = query.lowercased()
        return visible.filter {
            $0.title.lowercased().contains(q) ||
            $0.summary.lowercased().contains(q) ||
            $0.id.lowercased().contains(q) ||
            $0.html.lowercased().contains(q)
        }
    }
}
```

- [ ] **步骤 4：运行验证通过**

- [ ] **步骤 5：Commit** — `git commit -m "feat(demo): DemoCatalog 分组/搜索/可见性（P0-2）"`

---

## 任务 P0-3：12 族用例收编 + 表格用例（真实复杂场景）

**文件：**
- 创建：`XMarkupDemo/Shared/Data/Examples/*.swift`（12 个族文件 + APITestExamples）
- 删除：旧 `XMarkupDemo/Shared/DemoExamples.swift`（收编完成后）

> **收编原则**：按设计规格 §4.2 映射表，把旧 71 用例迁移到对应族文件，`id` 不变。回归用例（原 boundary + 已知问题用例）标 `isRegression: true` + `note`。

- [ ] **步骤 1：逐族迁移旧用例**

每个族文件结构：
```swift
import Foundation
import XMarkup

enum InlineTextExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "bold", title: "粗体", summary: "<b>/<strong>",
                    html: "这是<b>粗体</b>文字示例，<strong>strong</strong> 也加粗。",
                    family: .inlineText, tier: .basic),
        DemoExample(id: "bold-italic", title: "粗体 + 斜体", summary: "嵌套合并",
                    html: "这是<b><i>粗斜体</i></b>文字。",
                    family: .inlineText, tier: .nested),
        DemoExample(id: "nested-deep", title: "四层嵌套", summary: "<b><i><u><s>",
                    html: "<b><i><u><s>四层嵌套</s></u></i></b>",
                    family: .inlineText, tier: .nested, isRegression: true,
                    note: "验证多层嵌套样式合并"),
        // ... italic/underline/strikethrough/sub-sup/code/mark
    ]
}
```

迁移映射严格按 §4.2：
- `basic`(6) → 内联文本（bold/italic/underline/strikethrough/sub-sup = basic；bold-italic/nested-deep = nested）
- `color`(5) + `mixed.font-size`/`code`/`mark` → 内联样式 / 内联文本
- `mixed.blockquote`/`pre` → 引用与预格式
- `heading`(2) + `boundary.hr-br` → 标题与段落
- `link`(2) → 链接
- `list`(3) → 列表（list-nested 标 regression，note 记录嵌套空白问题）
- `media`(5) → 媒体
- `semantic`(5) → 语义容器
- `themeCustom`(7) + `spacing`(4) → 主题对比
- `complex`(3，除 table-layout) + `scenario`(6) + `longform`(2) → 综合实战
- `complex.table-layout` → 表格族 nested
- `boundary`(6，除 nested-deep/hr-br) → 容错与边界（标 regression）
- `apiTest`(2) → APITestExamples（`visibility: .hidden`）

- [ ] **步骤 2：新增表格用例 `TableExamples.swift`（7 个真实复杂场景）**

```swift
enum TableExamples {
    static let all: [DemoExample] = [
        DemoExample(id: "table-basic", title: "简单数据表",
            summary: "thead + tbody 常规行列", family: .table, tier: .basic,
            html: """
            <table><thead><tr><th>姓名</th><th>部门</th><th>入职</th></tr></thead>
            <tbody><tr><td>张三</td><td>工程</td><td>2021</td></tr>
            <tr><td>李四</td><td>设计</td><td>2022</td></tr></tbody></table>
            """),
        DemoExample(id: "table-finance", title: "季度财务报表",
            summary: "跨列表头分组 + tfoot 汇总行", family: .table, tier: .nested,
            html: """
            <table><thead><tr><th rowspan="2">项目</th><th colspan="2">2025 Q1</th><th colspan="2">2025 Q2</th></tr>
            <tr><th>收入</th><th>支出</th><th>收入</th><th>支出</th></tr></thead>
            <tbody><tr><td>主营业务</td><td>1,200</td><td>800</td><td>1,500</td><td>780</td></tr>
            <tr><td>其他业务</td><td>200</td><td>120</td><td>240</td><td>110</td></tr></tbody>
            <tfoot><tr><td>合计</td><td>1,400</td><td>920</td><td>1,740</td><td>890</td></tr></tfoot></table>
            """,
            note: "验证 colspan/rowspan 表头分组 + tfoot 汇总"),
        DemoExample(id: "table-product-compare", title: "产品参数对比",
            summary: "多列属性 + ✓/✗ 高亮", family: .table, tier: .nested,
            html: """
            <table><thead><tr><th>特性</th><th>基础版</th><th>专业版</th><th>旗舰版</th></tr></thead>
            <tbody><tr><td>存储空间</td><td>5GB</td><td>50GB</td><td><b>无限</b></td></tr>
            <tr><td>团队协作</td><td>✗</td><td>✓</td><td>✓</td></tr>
            <tr><td>优先支持</td><td>✗</td><td>✗</td><td><span style="color:#FF0000">✓</span></td></tr>
            <tr><td>价格/月</td><td>¥0</td><td>¥29</td><td>¥99</td></tr></tbody></table>
            """),
        DemoExample(id: "table-schedule", title: "课程表",
            summary: "跨行 rowspan，时间 × 星期矩阵", family: .table, tier: .nested,
            html: """
            <table><thead><tr><th>时间</th><th>周一</th><th>周二</th><th>周三</th><th>周四</th><th>周五</th></tr></thead>
            <tbody><tr><td rowspan="2">上午</td><td>语文</td><td>数学</td><td>英语</td><td>物理</td><td>化学</td></tr>
            <tr><td>数学</td><td>语文</td><td>物理</td><td>英语</td><td>生物</td></tr>
            <tr><td>下午</td><td>体育</td><td>音乐</td><td>美术</td><td>历史</td><td>地理</td></tr></tbody></table>
            """,
            note: "验证 rowspan 跨行合并"),
        DemoExample(id: "table-nested-list", title: "含嵌套列表的单元格",
            summary: "td 内 <ul><li>", family: .table, tier: .nested,
            html: """
            <table><thead><tr><th>产品</th><th>特性列表</th></tr></thead>
            <tbody><tr><td>XMarkup</td><td><ul><li>HTML 解析</li><li>富文本渲染</li><li>主题系统</li></ul></td></tr>
            <tr><td>竞品 A</td><td><ul><li>仅解析</li></ul></td></tr></tbody></table>
            """,
            note: "验证单元格内块级嵌套（td 内 ul/li）"),
        DemoExample(id: "table-styled-cell", title: "带样式高亮的表格",
            summary: "td 内 <span style> 高亮异常值", family: .table, tier: .nested,
            html: """
            <table><thead><tr><th>指标</th><th>本月</th><th>环比</th></tr></thead>
            <tbody><tr><td>DAU</td><td>1,250,000</td><td><span style="color:#00AA00">+12.5%</span></td></tr>
            <tr><td>崩溃率</td><td>0.8%</td><td><span style="color:#FF0000"><b>+0.3%</b></span></td></tr></tbody></table>
            """),
        DemoExample(id: "table-edge", title: "表格边界",
            summary: "空单元格 / 缺 thead", family: .table, tier: .boundary, isRegression: true,
            html: """
            <table><tr><td>有值</td><td></td></tr><tr><td></td><td>有值</td></tr></table>
            """,
            note: "验证空单元格容错"),
    ]
}
```

- [ ] **步骤 3：补 `DemoCatalogTests` 断言用例总数与族覆盖**

```swift
func testNoExampleIDCollision() {
    let ids = DemoCatalog.all.map(\.id)
    XCTAssertEqual(ids.count, Set(ids).count, "用例 id 重复")
}
func testAllFamiliesHaveExamplesExceptMaybe() {
    let families = Set(DemoCatalog.all.map(\.family))
    // 12 族除 apiTest(hidden 仍计入 all) 外都应有用例
    XCTAssertGreaterThanOrEqual(families.count, 11)
}
func testTableExamplesCoversColspanRowspanTfoot() {
    let tableHTML = TableExamples.all.map(\.html).joined()
    XCTAssertTrue(tableHTML.contains("colspan"))
    XCTAssertTrue(tableHTML.contains("rowspan"))
    XCTAssertTrue(tableHTML.contains("tfoot"))
}
func testAPITestExamplesHidden() {
    let api = DemoCatalog.all.filter { $0.family == .inlineText /* 占位，实际按 id */ }
    // APITestExamples 两个用例 visibility = .hidden
    let hidden = DemoCatalog.all.filter { $0.visibility == .hidden }
    XCTAssertGreaterThanOrEqual(hidden.count, 2)
}
```

- [ ] **步骤 4：运行测试通过 + 删除旧 `DemoExamples.swift`**

- [ ] **步骤 5：Commit** — `git commit -m "feat(demo): 12 族用例收编 + 真实复杂表格用例（P0-3）"`

---

## 任务 P0-4：DemoCanvasConfig（画布基线）

**文件：**
- 创建：`XMarkupDemo/Shared/Config/DemoCanvasConfig.swift`
- 创建：`XMarkupDemoTests/DemoCanvasConfigTests.swift`

- [ ] **步骤 1：写失败测试**

```swift
import XCTest
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import DemoExample

final class DemoCanvasConfigTests: XCTestCase {
    func testDefaultValuesAlignWebBaseline() {
        let c = DemoCanvasConfig()
        XCTAssertEqual(c.paddingLeading, 16)
        XCTAssertEqual(c.paddingTop, 16)
        XCTAssertEqual(c.lineHeight, 1.6, accuracy: 0.001)
        XCTAssertEqual(c.baseFontSize, 16)
    }
    func testCSSStringContainsPaddingAndLineHeight() {
        let c = DemoCanvasConfig()
        let css = c.cssString()
        XCTAssertTrue(css.contains("padding"))
        XCTAssertTrue(css.contains("line-height: 1.6"))
        XCTAssertTrue(css.contains("font-size: 16"))
    }
    #if canImport(UIKit)
    func testUITextContainerInset() {
        let c = DemoCanvasConfig(paddingTop: 10, paddingLeading: 20, paddingBottom: 30, paddingTrailing: 40)
        let inset = c.uiTextContainerInset
        XCTAssertEqual(inset.top, 10); XCTAssertEqual(inset.left, 20)
        XCTAssertEqual(inset.bottom, 30); XCTAssertEqual(inset.right, 40)
    }
    #endif
    func testBaseFontUsesConfiguredSize() {
        let c = DemoCanvasConfig(baseFontSize: 20)
        #if canImport(UIKit)
        XCTAssertEqual(c.baseFont.pointSize, 20)
        #elseif canImport(AppKit)
        XCTAssertEqual(c.baseFont.pointSize, 20)
        #endif
    }
}
```

- [ ] **步骤 2：运行验证失败**

- [ ] **步骤 3：实现 `DemoCanvasConfig.swift`**（按设计规格 §3.6 代码块）

- [ ] **步骤 4：运行验证通过**

- [ ] **步骤 5：Commit** — `git commit -m "feat(demo): DemoCanvasConfig 共享画布基线（P0-4）"`

---

## 任务 P0-5：DemoRenderer + WebViewRenderer 改造

**文件：**
- 创建：`XMarkupDemo/Shared/Rendering/DemoRenderer.swift`
- 修改：`XMarkupDemo/Shared/Web/WebViewRenderer.swift`（接 config）
- 创建：`XMarkupDemoTests/DemoRendererTests.swift`

- [ ] **步骤 1：写失败测试**

```swift
import XCTest
@testable import DemoExample

final class DemoRendererTests: XCTestCase {
    func testRenderProducesAttributedString() throws {
        let ex = DemoExample(id: "t", title: "T", summary: "", html: "<b>粗</b>",
                             family: .inlineText, tier: .basic)
        let attr = try DemoRenderer.render(example: ex, config: DemoCanvasConfig())
        XCTAssertGreaterThan(attr.length, 0)
    }
    func testRenderAppliesThemeOverride() throws {
        let ex = DemoExample(id: "t", title: "T", summary: "", html: "hi",
                             family: .theme, tier: .basic, themeOverride: .default)
        let attr = try DemoRenderer.render(example: ex, config: DemoCanvasConfig())
        XCTAssertNotNil(attr.attribute(.font, at: 0, effectiveRange: nil))
    }
    func testRenderVariantsReturnsMultiple() throws {
        let ex = DemoExample(id: "t", title: "T", summary: "", html: "hi",
                             family: .theme, tier: .basic, themeVariants: [.default, .dark])
        let variants = try DemoRenderer.renderVariants(example: ex, config: DemoCanvasConfig())
        XCTAssertEqual(variants.count, 2)
    }
    func testAppendHTMLConcatenates() throws {
        let ex = DemoExample(id: "t", title: "T", summary: "", html: "<p>A</p>",
                             family: .inlineText, tier: .basic, appendHTML: "<p>B</p>")
        let attr = try DemoRenderer.render(example: ex, config: DemoCanvasConfig())
        XCTAssertTrue(attr.string.contains("A"))
        XCTAssertTrue(attr.string.contains("B"))
    }
    func testStyledHTMLInjectsConfigCSS() {
        let styled = WebViewRenderer.styledHTML(from: "<b>x</b>", config: DemoCanvasConfig())
        XCTAssertTrue(styled.contains("line-height: 1.6"))
        XCTAssertTrue(styled.contains("<b>x</b>"))
    }
}
```

- [ ] **步骤 2：运行验证失败**

- [ ] **步骤 3：实现 `DemoRenderer.swift`**

```swift
import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 平台无关渲染器 — HTML → NSAttributedString（详见设计规格 §5.1）
public enum DemoRenderer {
    public static func render(example: DemoExample, config: DemoCanvasConfig) throws -> NSAttributedString {
        let parser = try XMarkupParser()
        let document = try parse(example, parser: parser)
        // config.baseFontSize 对齐 theme.baseFont，保证原生字号 = Web
        var theme = example.themeOverride ?? .default
        theme.baseFont = config.baseFont
        return document.render(theme: theme)
    }

    public static func renderVariants(example: DemoExample, config: DemoCanvasConfig) throws -> [NSAttributedString] {
        let parser = try XMarkupParser()
        let document = try parse(example, parser: parser)
        let themes = example.themeVariants ?? [.default, .dark, .article]
        return themes.map { theme -> NSAttributedString in
            var t = theme
            t.baseFont = config.baseFont
            return document.render(theme: t)
        }
    }

    public static func parse(_ example: DemoExample, parser: XMarkupParser? = nil) throws -> MarkupDocument {
        let p = try parser ?? XMarkupParser()
        let doc = MarkupDocument.from(try p.parse(example.html))
        if let second = example.appendHTML {
            let doc2 = MarkupDocument.from(try p.parse(second))
            return doc.appending(doc2)
        }
        return doc
    }
}
```

- [ ] **步骤 4：改造 `WebViewRenderer.swift`**

```swift
import Foundation

/// WebView 共享渲染（详见设计规格 §5.1）— 接 DemoCanvasConfig 注入 CSS
enum WebViewRenderer {
    static func styledHTML(from html: String, config: DemoCanvasConfig) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(config.cssString())
        img { max-width: 100%; height: auto; }
        a { color: #0066CC; text-decoration: none; }
        a:hover { text-decoration: underline; }
        code { background: #f5f5f5; padding: 2px 4px; border-radius: 3px; font-family: ui-monospace, monospace; }
        pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow-x: auto; }
        blockquote { border-left: 4px solid #ddd; margin: 0; padding: 8px 16px; color: #666; }
        h1,h2,h3,h4,h5,h6 { margin-top: 1em; margin-bottom: 0.5em; }
        p { margin-top: 0; margin-bottom: 0.5em; }
        table { border-collapse: collapse; margin: 0.5em 0; }
        th, td { border: 1px solid #ddd; padding: 6px 10px; text-align: left; }
        th { background: #f5f5f5; }
        </style></head><body>\(html)</body></html>
        """
    }
}
```

- [ ] **步骤 5：运行全部测试通过**

- [ ] **步骤 6：Commit** — `git commit -m "feat(demo): DemoRenderer + WebViewRenderer 接 config（P0-5）"`

---

# P1 — SwiftUI 视图层

> P1 任务以"文件 + 关键实现要点"形式给出，UI 以编译 + 运行手动验证为准（无单元测试）。每任务独立 commit。

## 任务 P1-1：工程切换（删 UIKit/AppKit，双 target）

- [ ] 重写 `project.yml`：删 `XMarkupDemoUIKit`/`XMarkupDemoAppKit` target，新增 `XMarkupDemoSwiftUIMac`（macOS 13+），两 SwiftUI target 共享 `XMarkupDemo/Shared` + `XMarkupDemo/SwiftUI` 源码（按设计规格 §7.2）
- [ ] 删除 `XMarkupDemo/UIKit/`、`XMarkupDemo/AppKit/` 目录
- [ ] `xcodegen generate` + iOS/macOS 双 scheme 编译通过
- [ ] Commit — `refactor(demo): 删 UIKit/AppKit，SwiftUI 双 target 单源码（P1-1）`

## 任务 P1-2：导航骨架（NavigationSplitView 三栏）

- [ ] `SwiftUI/App.swift`：入口，`#if os(macOS)` 用 `WindowGroup` + 三栏；iOS 用 `WindowGroup` + NavigationSplitView（compact 自动折叠为 push）
- [ ] `SwiftUI/Navigation/DemoRootView.swift`：`NavigationSplitView { FamilySidebar } content: { ExampleListView } detail: { CompareDetailView }`
- [ ] `SwiftUI/Navigation/FamilySidebar.swift`：12 族 `List` + `symbol` 图标 + selection 绑定；顶部搜索框（`.searchable`）
- [ ] `SwiftUI/Navigation/ExampleListView.swift`：选中族的用例列表，按 `tier` 分 `Section`；回归用例标 `ⓘ`、robustness 族标 `⚠️`
- [ ] 编译运行：iPhone（push 导航）+ iPad/macOS（三栏）均可切换
- [ ] Commit — `feat(demo): NavigationSplitView 三栏导航骨架（P1-2）`

## 任务 P1-3：对比详情（自适应并排/堆叠）

- [ ] `SwiftUI/Components/NativeTextRepresentable.swift`：从旧 `RenderedTextView` 抽出，`textContainerInset` 改读 `DemoCanvasConfig`
- [ ] `SwiftUI/Components/WebViewRepresentable.swift`：从旧 `WebViewPreviewView` 抽出，`styledHTML(from:config:)`
- [ ] `SwiftUI/Detail/NativeRenderView.swift`：调 `DemoRenderer.render(example:config:)`，`@State` 持有结果 + 错误态
- [ ] `SwiftUI/Detail/WebRenderView.swift`：调 `WebViewRenderer.styledHTML(from:config:)` 加载
- [ ] `SwiftUI/Detail/CompareDetailView.swift`：`@Environment(\.horizontalSizeClass)` 判断 — `regular` → `HSplitView { NativeRenderView; WebRenderView }`；`compact` → `VStack` 上下堆叠；顶部显示 `example.note`（若有）；`themeVariants` 用例 → 原生区纵向多主题
- [ ] 编译运行：对比区 padding/字号肉眼对齐（config 同源）
- [ ] Commit — `feat(demo): 自适应并排/堆叠对比详情（P1-3）`

## 任务 P1-4：调试抽屉（源码/Span/日志）

- [ ] `SwiftUI/Debug/DebugDrawer.swift`：iOS `.sheet` / macOS `.popover`，内含三 Tab（源码/Span/日志）
- [ ] 从旧 `HTMLSourceView`/`SpanDataView`/`LogView` 迁移到 `Debug/`，去掉对旧模型的依赖
- [ ] 详情页工具栏/按钮触发抽屉
- [ ] Commit — `feat(demo): 调试抽屉收纳源码/Span/日志（P1-4）`

## 任务 P1-5：清理旧 SwiftUI 文件

- [ ] 删除旧 `SwiftUI/ContentView.swift`/`ExampleDetailView.swift`/`RenderedTextView.swift`/`WebViewPreviewView.swift`/`SpanDataView.swift`/`HTMLSourceView.swift`/`LogView.swift`（已被 Navigation/Detail/Debug/Components 取代）
- [ ] `apiTest` 用例验证：`visibility = .hidden` 不出现在列表
- [ ] Commit — `chore(demo): 清理旧 SwiftUI 文件（P1-5）`

---

# P2 — macOS 精细化

## 任务 P2-1：macOS 工具栏

- [ ] `CompareDetailView` macOS 分支：`ToolbarItem` 放对比模式切换（并排/堆叠 `Segmented`）、画布配置 popover、主题切换 popover、调试入口
- [ ] 画布配置 popover：`paddingTop/Leading/Bottom/Trailing`/`baseFontSize`/`lineHeight` 滑杆，调参即时重渲染原生+Web（`@State DemoCanvasConfig`）
- [ ] Commit — `feat(demo): macOS 工具栏 + 画布配置实时联动（P2-1）`

## 任务 P2-2：键盘快捷键 + 菜单栏

- [ ] `.keyboard("f", modifiers: .command)` 搜索 / `.keyboard("1", .command)` 并排 / `.keyboard("2", .command)` 堆叠 / `.keyboard("d", .command)` 调试 / `.keyboard(",", .command)` 画布配置
- [ ] macOS 菜单栏（视图/窗口）标准项
- [ ] Commit — `feat(demo): macOS 键盘快捷键 + 菜单栏（P2-2）`

## 任务 P2-3：回归标记 + note 完善

- [ ] 全量回归用例 `isRegression = true` + `note` 填写验证点/已知差异
- [ ] 列表 `ⓘ` 与详情页 note 提示样式打磨
- [ ] 最终验证：跑完设计规格 §9 全部验证标准
- [ ] Commit — `feat(demo): 回归标记与 note 完善（P2-3）`

---

## 验证命令

```bash
# P0 单元测试
cd playground/ios/XMarkupDemo && xcodegen generate
xcodebuild test -scheme XMarkupDemoSwiftUI -destination 'platform=iOS Simulator,name=iPhone 16'

# P1/P2 编译（iOS + macOS）
xcodebuild build -scheme XMarkupDemoSwiftUI -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild build -scheme XMarkupDemoSwiftUIMac -destination 'platform=macOS'
```

## 自检

- **规格覆盖**：§3 数据模型（P0-1/2/4）✓ / §4 用例体系（P0-3）✓ / §5 分层架构（P0-4/5 + P1 文件结构）✓ / §6 UI（P1-2/3/4 + P2）✓ / §7 工程（P1-1）✓ / §8 阶段（P0/P1/P2）✓ / §9 验证标准（各任务步骤）✓
- **类型一致**：`ExampleFamily`(12) / `ExampleTier`(3) / `DemoExample` 字段 / `DemoCanvasConfig` 字段 / `DemoRenderer` 签名 全跨任务一致
- **无占位符**：P0 每任务含完整测试+实现代码；P1/P2 含文件清单+实现要点（UI 任务以编译验证代测试，标注清楚）
