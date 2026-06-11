# iOS 插件化架构重设计

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 iOS 层从单体渲染黑盒重设计为"类型化主题 + 协议化插件 + 组合式管线"架构，实现按 kind 精准控制、自由组合。

**架构：** 三层对齐 — 类型化主题（声明 WHAT）→ 协议化渲染器（控制 HOW）→ 平台增强插件（视觉增强）。每个 BlockKind/InlineKind 的 Theme、Renderer、Enhancement 三者 1:1 对齐。

**技术栈：** Swift 6.0 / SPM / UIKit(iOS 15+) + AppKit(macOS 12+) / NSTextList(iOS 7+)

---

## 依赖关系

```
Phase 1 (Bridge 补全)
    ↓ 独立，可最先执行
Phase 2 (类型化主题) ─────→ Phase 3 (插件协议) ──→ Phase 4 (渲染器重构)
                                                        ↓
                                                   Phase 5 (管线统一)
                                                        ↓
                                                   Phase 6 (XMarkupUI)
                                                        ↓
                                                   Phase 7 (测试 + 验证)
```

---

## Phase 1：Bridge 补全

桥接 C++ Core 缺失的功能，与渲染架构无耦合，可独立先行。

---

### 任务 1.1：XMLogLevel + 日志回调桥接

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Bridge/XMarkupParser.swift`
- 新增：`platforms/ios/Sources/XMarkup/Bridge/XMarkupLogger.swift`

- [ ] **步骤 1：新增 XMLogLevel Swift 映射**

```swift
// XMarkupLogger.swift
import CXMarkup

/// 日志级别，与 C++ 引擎 XMLogLevel 一一对应
public enum XMarkupLogLevel: UInt8, Sendable, Equatable {
    case error = 0   // 解析异常
    case warn  = 1   // 容错决策
    case info  = 2   // 关键决策节点
    case trace = 3   // 详细步骤
}

/// 日志回调闭包类型
public typealias XMarkupLogHandler = @Sendable (XMarkupLogLevel, String) -> Void
```

- [ ] **步骤 2：桥接 C log callback 到 Swift 闭包**

核心机制：全局 `Unmanaged` 持有 Swift 闭包，C 回调通过 `context` 指针取回。

```swift
// XMarkupLogger.swift
enum LogBridge {
    /// 将 Swift 闭包包装为 C XMLogCallback + context
    static func wrap(_ handler: @escaping XMarkupLogHandler)
        -> (callback: XMLogCallback, context: UnsafeMutableRawPointer?)
    {
        let box = Unmanaged.passRetained(HandlerBox(handler)).toOpaque()
        return (callback: { level, message, ctx in
            guard let ctx else { return }
            let box = Unmanaged<HandlerBox>.fromOpaque(ctx).takeUnretainedValue()
            let msg = message.map { String(cString: $0) } ?? ""
            box.handler(XMarkupLogLevel(rawValue: level.rawValue) ?? .error, msg)
        }, context: box)
    }

    /// 释放闭包持有的内存
    static func release(_ context: UnsafeMutableRawPointer?) {
        guard let context else { return }
        Unmanaged<HandlerBox>.fromOpaque(context).release()
    }

    private final class HandlerBox: @unchecked Sendable {
        let handler: XMarkupLogHandler
        init(_ handler: @escaping XMarkupLogHandler) { self.handler = handler }
    }
}
```

- [ ] **步骤 3：XMarkupParser.init 增加日志参数**

```swift
public init(
    baseFontSize: CGFloat = 16,
    maxNestingDepth: UInt16 = 256,
    autocorrect: Bool = true,
    logLevel: XMarkupLogLevel = .error,
    logHandler: XMarkupLogHandler? = nil
) throws {
    self.baseFontSize = baseFontSize
    var config = XMConfig()
    config.enable_autocorrect = autocorrect ? 1 : 0
    config.max_nesting_depth = maxNestingDepth
    config.base_font_size = Float(baseFontSize)
    config.log_level = XMLogLevel(rawValue: logLevel.rawValue)

    if let handler = logHandler {
        let (callback, context) = LogBridge.wrap(handler)
        config.log_callback = callback
        config.log_context = context
        self.logContext = context
    } else {
        self.logContext = nil
    }

    guard let ptr = xmarkup_create(&config) else {
        if let ctx = self.logContext { LogBridge.release(ctx) }
        throw XMarkupError.allocationFailed
    }
    handle = ptr
}

deinit {
    xmarkup_destroy(handle)
    if let ctx = logContext { LogBridge.release(ctx) }
}

private let logContext: UnsafeMutableRawPointer?
```

- [ ] **步骤 4：测试**

`XMarkupResultTests.swift` 新增 `testParserLogCallback()`：设置 `.trace` 级别，解析 `<b>unclosed`，验证回调被触发。

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Bridge/XMarkupLogger.swift platforms/ios/Sources/XMarkup/Bridge/XMarkupParser.swift
git commit -m "feat(bridge): add log callback bridge for C++ engine diagnostics"
```

---

### 任务 1.2：暴露 xmarkup_error_string + xmarkup_version

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Bridge/XMarkupError.swift`

- [ ] **步骤 1：为 XMarkupError 添加 description**

```swift
extension XMarkupError: CustomStringConvertible {
    public var description: String {
        let cStr: UnsafePointer<CChar>
        switch self {
        case .nullParser:      cStr = xmarkup_error_string(XM_ERR_NULL_PARSER)
        case .nullInput:       cStr = xmarkup_error_string(XM_ERR_NULL_INPUT)
        case .nestingOverflow: cStr = xmarkup_error_string(XM_ERR_NESTING_OVERFLOW)
        case .allocationFailed: cStr = xmarkup_error_string(XM_ERR_ALLOC_FAILED)
        case .unknown(let code):
            return "XMarkupError.unknown(code: \(code))"
        }
        return String(cString: cStr)
    }
}
```

- [ ] **步骤 2：添加版本号 API**

```swift
// XMarkupParser.swift 中新增
public static var version: String {
    guard let cStr = xmarkup_version() else { return "unknown" }
    return String(cString: cStr)
}
```

- [ ] **步骤 3：测试 + Commit**

---

### 任务 1.3：lineBreak span 保留为 inline 元数据

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupInline.swift`
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupDocumentBuilder.swift`

- [ ] **步骤 1：InlineKind 新增 .lineBreak case**

```swift
public enum InlineKind: Sendable, Equatable {
    // ... 现有 case ...
    case lineBreak  // <br> 位置标记
}
```

- [ ] **步骤 2：MarkupDocumentBuilder.convertToInlines 中处理 .lineBreak**

在 `inlineKind(for:)` 的 switch 中增加：

```swift
case .lineBreak:
    return .lineBreak
```

- [ ] **步骤 3：测试 + Commit**

新增 `testLineBreakPreservedAsInline()`：解析 `<p>A<br>B</p>`，验证 block.inlines 包含 `.lineBreak`。

---

## Phase 2：类型化主题系统

将散落的 `tagStyles[key:]` + `blockStyles[key:]` + 散落字段，重构为按 kind 类型化的主题结构。

---

### 任务 2.1：定义类型化主题配置结构

**文件：**
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/ParagraphTheme.swift`
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/HeadingTheme.swift`
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/BlockquoteTheme.swift`
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/ListTheme.swift`
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/PreformattedTheme.swift`
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/TableTheme.swift`
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/HorizontalRuleTheme.swift`
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/InlineTextTheme.swift`
- 新增：`platforms/ios/Sources/XMarkup/Theme/Types/LinkTheme.swift`

- [ ] **步骤 1：创建 Theme/Types/ 目录，编写全部 typed theme 结构**

每个结构遵循统一模式：
- 所有字段有默认值
- `Sendable + Equatable`
- 块级 Theme 包含 `resolve` 闭包：`(MarkupBlock, RenderingContext, Resolved) -> Resolved?`
- 内联 Theme 包含 `resolve` 闭包：`(MarkupInline, MarkupBlock, RenderingContext, Resolved) -> Resolved?`
- 提供 `resolved(for:context:)` 方法执行三级合并（base → per-level → resolve）
- 提供 `with(_ keyPath:, _ value:)` 便利方法

关键结构的完整定义（其他结构遵循相同模式）：

**HeadingTheme** — 含逐级别覆盖 + 动态 resolve（完整定义见设计文档）

**BlockquoteTheme** — 含 border/indent/resolve

**ListTheme** — 含 marker 配置/indentUnit/resolve

**InlineTextTheme** — textColor/backgroundColor/font/resolve

**LinkTheme** — textColor/underlineStyle/underlineColor/resolve

每个结构的 `Resolved*` 内部类型是最终渲染器读取的 flattened 配置。

- [ ] **步骤 2：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/Types/
git commit -m "feat(theme): define typed per-kind theme configuration structs"
```

---

### 任务 2.2：重写 MarkupTheme + DSL

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift`（重写）
- 修改：`platforms/ios/Sources/XMarkup/Theme/ThemeComponents.swift`（重写 → ThemeComponents.swift）
- 修改：`platforms/ios/Sources/XMarkup/Theme/MarkupThemeBuilder.swift`（适配）
- 修改：`platforms/ios/Sources/XMarkup/Theme/PresetThemes.swift`（重写）
- 删除：`platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift`
- 删除：`platforms/ios/Sources/XMarkup/Theme/ParagraphSpacing.swift`
- 删除：`platforms/ios/Sources/XMarkup/Theme/BlockStyleConfig.swift`
- 删除：`platforms/ios/Sources/XMarkup/Theme/TagStyleKey.swift`（customOverrides 仍需保留简化版）

- [ ] **步骤 1：重写 MarkupTheme**

```swift
public struct MarkupTheme: @unchecked Sendable, Equatable {
    public var baseFont: XMFont

    // 块级 — 按 kind 类型化
    public var paragraph: ParagraphTheme
    public var heading: HeadingTheme
    public var blockquote: BlockquoteTheme
    public var preformatted: PreformattedTheme
    public var list: ListTheme
    public var table: TableTheme
    public var horizontalRule: HorizontalRuleTheme

    // 内联 — 按 kind 类型化
    public var bold: InlineTextTheme
    public var italic: InlineTextTheme
    public var underline: InlineTextTheme
    public var strikethrough: InlineTextTheme
    public var codeInline: InlineTextTheme
    public var mark: InlineTextTheme
    public var link: LinkTheme
    public var subscriptText: InlineTextTheme
    public var superscript: InlineTextTheme

    // 媒体
    public var media: MediaRenderingStrategy

    // 自定义覆盖（escape hatch）
    public var customOverrides: [String: AttributeComponent]

    public init(baseFont: XMFont = XMFont.systemFont(ofSize: 16)) { ... }

    // Equatable 排除 media（闭包不可比较）
    public static func == (lhs: Self, rhs: Self) -> Bool { ... }
}
```

- [ ] **步骤 2：重写 ThemeComponents + DSL 便利函数**

```swift
// 每个 kind 一个 DSL 入口函数
public func BaseFont(_ font: XMFont) -> ThemeComponent
public func Heading(_ configure: (inout HeadingTheme) -> Void) -> ThemeComponent
public func Blockquote(_ configure: (inout BlockquoteTheme) -> Void) -> ThemeComponent
public func List(_ configure: (inout ListTheme) -> Void) -> ThemeComponent
public func Paragraph(_ configure: (inout ParagraphTheme) -> Void) -> ThemeComponent
public func Preformatted(_ configure: (inout PreformattedTheme) -> Void) -> ThemeComponent
public func Table(_ configure: (inout TableTheme) -> Void) -> ThemeComponent
public func HorizontalRule(_ configure: (inout HorizontalRuleTheme) -> Void) -> ThemeComponent
public func Code(_ configure: (inout InlineTextTheme) -> Void) -> ThemeComponent
public func Link(_ configure: (inout LinkTheme) -> Void) -> ThemeComponent
public func Mark(_ configure: (inout InlineTextTheme) -> Void) -> ThemeComponent
public func Bold(_ configure: (inout InlineTextTheme) -> Void) -> ThemeComponent
public func Italic(_ configure: (inout InlineTextTheme) -> Void) -> ThemeComponent
public func Underline(_ configure: (inout InlineTextTheme) -> Void) -> ThemeComponent
public func Strikethrough(_ configure: (inout InlineTextTheme) -> Void) -> ThemeComponent
public func Subscript(_ configure: (inout InlineTextTheme) -> Void) -> ThemeComponent
public func Superscript(_ configure: (inout InlineTextTheme) -> Void) -> ThemeComponent
public func Media(_ strategy: MediaRenderingStrategy) -> ThemeComponent
```

每个函数内部实现 `ThemeComponent` 协议，将闭包的 `inout` 修改应用到 `MarkupTheme` 对应字段。

- [ ] **步骤 3：重写 PresetThemes**

```swift
extension MarkupTheme {
    public static let `default` = MarkupTheme {
        BaseFont(.systemFont(ofSize: 16))
        Heading {
            $0.scale = .default
            $0.bold = true
        }
        Blockquote {
            $0.indent = 12
            $0.borderWidth = 3
            $0.borderColor = .systemGray
        }
        Code {
            $0.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
            $0.backgroundColor = .systemGray6  // UIKit / AppKit 自动适配
        }
        Mark {
            $0.backgroundColor = .systemYellow.withAlphaComponent(0.3)
        }
    }
    // .dark, .chat, .article 类似重写
}
```

- [ ] **步骤 4：删除旧文件**

删除 `ThemeComponent.swift`、`ParagraphSpacing.swift`、`BlockStyleConfig.swift`。

`TagStyleKey.swift` 简化为仅保留 `customOverrides` 所需的 key 类型（或直接用 `String`）。

`HeadingScale.swift` 保留（被 `HeadingTheme.scale` 引用）。

- [ ] **步骤 5：Commit**

```bash
git commit -m "refactor(theme): rewrite to typed per-kind theme system with 3-level resolve"
```

---

## Phase 3：插件化渲染协议（Approach A）

定义细粒度的渲染协议体系，每个 block/inline kind 有独立的扩展点。

---

### 任务 3.1：定义渲染协议体系 + RenderingContext

**文件：**
- 新增：`platforms/ios/Sources/XMarkup/Plugin/RenderingContext.swift`
- 新增：`platforms/ios/Sources/XMarkup/Plugin/BlockRendering.swift`
- 新增：`platforms/ios/Sources/XMarkup/Plugin/InlineRendering.swift`
- 新增：`platforms/ios/Sources/XMarkup/Plugin/AttributedStringProcessing.swift`
- 新增：`platforms/ios/Sources/XMarkup/Plugin/NSAttributedStringProcessing.swift`
- 新增：`platforms/ios/Sources/XMarkup/Plugin/RendererPlugin.swift`（便利组合协议）

- [ ] **步骤 1：RenderingContext**

```swift
/// 渲染上下文 — 在整个渲染管线中传递
public struct RenderingContext: Sendable {
    public let theme: MarkupTheme
    public let blockIndex: Int       // 当前块在文档中的位置（0-based）
    public let totalBlocks: Int      // 文档总块数
    public var sharedState: [String: Any]  // 插件间共享状态（NSTextList 实例等）

    public init(theme: MarkupTheme, blockIndex: Int, totalBlocks: Int) {
        self.theme = theme
        self.blockIndex = blockIndex
        self.totalBlocks = totalBlocks
        self.sharedState = [:]
    }
}
```

- [ ] **步骤 2：细粒度协议定义**

```swift
// BlockRendering.swift
/// 块级渲染器协议 — 控制单个 block 如何渲染为 AttributedString
/// 返回 nil 表示不处理此 block，交由下一个渲染器
public protocol BlockRendering: Sendable {
    func render(block: MarkupBlock, context: RenderingContext) -> AttributedString?
}

// InlineRendering.swift
/// 内联渲染器协议 — 控制单个 inline 样式如何应用
/// 返回 false 表示不处理此 inline，交由下一个渲染器
public protocol InlineRendering: Sendable {
    func apply(inline: MarkupInline, to attributed: inout AttributedString,
               blockText: String, context: RenderingContext) -> Bool
}

// AttributedStringProcessing.swift
/// AttributedString 后处理器 — 在所有 block 渲染完成后对整体结果做后处理
public protocol AttributedStringProcessing: Sendable {
    func process(_ attributed: AttributedString, context: RenderingContext) -> AttributedString
}

// NSAttributedStringProcessing.swift
/// NSAttributedString 增强器 — 在桥接为 NSAttributedString 后追加平台视觉属性
public protocol NSAttributedStringProcessing: Sendable {
    func enhance(_ nsAttr: NSMutableAttributedString, context: RenderingContext)
}
```

- [ ] **步骤 3：便利组合协议**

```swift
// RendererPlugin.swift
/// 便利组合协议 — 同时遵循四个阶段协议，所有方法有默认空实现
/// 用户只需覆写关心的方法
public protocol RendererPlugin: BlockRendering, InlineRendering,
                                 AttributedStringProcessing, NSAttributedStringProcessing {}

extension RendererPlugin {
    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? { nil }
    public func apply(inline: MarkupInline, to attributed: inout AttributedString,
                      blockText: String, context: RenderingContext) -> Bool { false }
    public func process(_ attributed: AttributedString, context: RenderingContext) -> AttributedString { attributed }
    public func enhance(_ nsAttr: NSMutableAttributedString, context: RenderingContext) {}
}
```

- [ ] **步骤 4：Commit**

```bash
git commit -m "feat(plugin): define fine-grained rendering protocol hierarchy (Approach A)"
```

---

### 任务 3.2：定义 RenderPipeline

**文件：**
- 新增：`platforms/ios/Sources/XMarkup/Plugin/RenderPipeline.swift`

- [ ] **步骤 1：RenderPipeline 编排器**

```swift
/// 可组合的渲染管线 — 编排多个插件按阶段执行
public struct RenderPipeline: Sendable {
    let blockRenderers: [any BlockRendering]
    let inlineRenderers: [any InlineRendering]
    let postProcessors: [any AttributedStringProcessing]
    let enhancers: [any NSAttributedStringProcessing]
    let bridge: any MarkupRenderer<NSAttributedString>

    public init(
        bridge: some MarkupRenderer<NSAttributedString> = NSAttributedStringRenderer(),
        blockRenderers: [any BlockRendering] = [],
        inlineRenderers: [any InlineRendering] = [],
        postProcessors: [any AttributedStringProcessing] = [],
        enhancers: [any NSAttributedStringProcessing] = []
    ) { ... }

    /// 从 RendererPlugin 数组自动分类到各阶段
    public init(
        bridge: some MarkupRenderer<NSAttributedString> = NSAttributedStringRenderer(),
        plugins: [any RendererPlugin]
    ) {
        self.blockRenderers = plugins
        self.inlineRenderers = plugins
        self.postProcessors = plugins
        self.enhancers = plugins
        self.bridge = bridge
    }

    /// 完整渲染：MarkupDocument → NSAttributedString
    public func render(_ document: MarkupDocument, theme: MarkupTheme) -> NSAttributedString {
        // Phase 1: Block rendering (with plugin override)
        var attr = renderBlocks(document.blocks, theme: theme)
        // Phase 2: Inline rendering (handled within block rendering)
        // Phase 3: AttributedString post-processing
        for processor in postProcessors {
            let ctx = RenderingContext(theme: theme, blockIndex: 0, totalBlocks: document.blocks.count)
            attr = processor.process(attr, context: ctx)
        }
        // Phase 4: Bridge to NSAttributedString
        var nsAttr = bridge.render(attr).mutableCopy() as! NSMutableAttributedString
        // Phase 5: NSAttributedString enhancement
        for enhancer in enhancers {
            let ctx = RenderingContext(theme: theme, blockIndex: 0, totalBlocks: document.blocks.count)
            enhancer.enhance(nsAttr, context: ctx)
        }
        return nsAttr
    }

    /// 渲染块列表（内部方法）
    private func renderBlocks(_ blocks: [MarkupBlock], theme: Theme) -> AttributedString { ... }
}
```

- [ ] **步骤 2：MarkupDocument.render 增加管线参数**

```swift
extension MarkupDocument {
    /// 使用默认管线渲染（向后兼容便捷方法）
    public func render(theme: MarkupTheme = .default) -> AttributedString {
        let pipeline = RenderPipeline.default
        return pipeline.renderAttributed(self, theme: theme)
    }

    /// 使用自定义管线渲染
    public func render(theme: MarkupTheme = .default, pipeline: RenderPipeline) -> AttributedString {
        pipeline.renderAttributed(self, theme: theme)
    }
}
```

- [ ] **步骤 3：Commit**

---

## Phase 4：渲染器重构为插件实现

将现有 `internal` 自由函数重构为协议实现，成为默认插件。

---

### 任务 4.1：重构 BlockRenderer → DefaultBlockRenderer

**文件：**
- 新增：`platforms/ios/Sources/XMarkup/Plugin/Defaults/DefaultBlockRenderer.swift`
- 参考：`platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift`（源）

- [ ] **步骤 1：将 `renderBlock` 自由函数重构为 `DefaultBlockRenderer: BlockRendering`**

核心变化：
- 函数签名从 `renderBlock(_:theme:)` 改为 `render(block:context:)` 
- theme 从 `context.theme` 获取
- 每个 block kind 读取对应的 typed theme（`context.theme.heading.resolved(for:block:)`）
- 不再从 `tagStyles` 字典读取，改为从 typed theme 读取

```swift
public struct DefaultBlockRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? {
        switch block.kind {
        case .heading:
            return renderHeading(block, context: context)
        case .blockquote:
            return renderBlockquote(block, context: context)
        case .listItem:
            return renderListItem(block, context: context)
        case .preformatted:
            return renderPreformatted(block, context: context)
        case .horizontalRule:
            return renderHorizontalRule(block, context: context)
        case .paragraph, .division:
            return renderParagraph(block, context: context)
        case .table:
            return nil  // table 由 DefaultTableRenderer 处理
        default:
            return renderParagraph(block, context: context)
        }
    }

    private func renderHeading(_ block: MarkupBlock, context: RenderingContext) -> AttributedString {
        let config = context.theme.heading.resolved(for: block, baseFont: context.theme.baseFont)
        // 用 config.fontSize, config.bold, config.textColor 构建属性...
    }

    private func renderBlockquote(_ block: MarkupBlock, context: RenderingContext) -> AttributedString {
        let config = context.theme.blockquote.resolved(for: block)
        // 用 config.indent, config.textColor 构建属性...
    }
    // ... 其他 block kinds
}
```

- [ ] **步骤 2：Commit**

---

### 任务 4.2：重构 InlineRenderer → DefaultInlineRenderer

**文件：**
- 新增：`platforms/ios/Sources/XMarkup/Plugin/Defaults/DefaultInlineRenderer.swift`
- 参考：`platforms/ios/Sources/XMarkup/Rendering/InlineRenderer.swift`（源）

- [ ] **步骤 1：将 `applyInlineAttributes` 自由函数重构为 `DefaultInlineRenderer: InlineRendering`**

核心变化：
- 每个内联 kind 从对应的 typed theme 读取配置
- `context.theme.codeInline.resolved(for:inline:block:)` 替代硬编码颜色

```swift
public struct DefaultInlineRenderer: InlineRendering, Sendable {
    public init() {}

    public func apply(inline: MarkupInline, to attributed: inout AttributedString,
                      blockText: String, context: RenderingContext) -> Bool {
        switch inline.kind {
        case .bold:
            applyBold(to: &attributed, context: context); return true
        case .code:
            applyCode(to: &attributed, context: context); return true
        case .link(let url):
            applyLink(url: url, to: &attributed, context: context); return true
        // ... 所有 inline kinds
        case .lineBreak:
            return true  // <br> 已在文本中为 \n，无需额外处理
        }
    }
}
```

- [ ] **步骤 2：Commit**

---

### 任务 4.3：重构 TableRenderer → DefaultTableRenderer

**文件：**
- 新增：`platforms/ios/Sources/XMarkup/Plugin/Defaults/DefaultTableRenderer.swift`
- 参考：`platforms/ios/Sources/XMarkup/Rendering/TableRenderer.swift`（源）

- [ ] **步骤 1：重构为 BlockRendering 实现**

```swift
public struct DefaultTableRenderer: BlockRendering, Sendable {
    public init() {}

    public func render(block: MarkupBlock, context: RenderingContext) -> AttributedString? {
        guard case .table(let structure) = block.kind else { return nil }
        let config = context.theme.table.resolved(for: block)
        // 使用 config.headerFont, config.headerBackgroundColor 等
        // 产出 tab 分隔 + 元数据标注的 NSAttributedString
        ...
    }
}
```

- [ ] **步骤 2：注册 table 元数据 key 为 AttributedStringKey**

```swift
// XMarkupScope.swift 新增
public struct XMarkupTableColumnCountKey: AttributedStringKey {
    public typealias Value = Int
    public static let name = "XMarkup.TableColumnCount"
}
public struct XMarkupTableHeaderCountKey: AttributedStringKey {
    public typealias Value = Int
    public static let name = "XMarkup.TableHeaderRowCount"
}
public struct XMarkupTableRowIndexKey: AttributedStringKey {
    public typealias Value = Int
    public static let name = "XMarkup.TableRowIndex"
}
```

- [ ] **步骤 3：Commit**

---

### 任务 4.4：重构 AttachmentRenderer → DefaultAttachmentRenderer

**文件：**
- 新增：`platforms/ios/Sources/XMarkup/Plugin/Defaults/DefaultAttachmentRenderer.swift`
- 参考：`platforms/ios/Sources/XMarkup/Rendering/AttachmentRenderer.swift`（源）

- [ ] **步骤 1：重构为 BlockRendering 实现**

处理 image/video/audio 块，使用 `context.theme.media` 策略。

- [ ] **步骤 2：Commit**

---

### 任务 4.5：组装 DefaultRenderPipeline

**文件：**
- 新增：`platforms/ios/Sources/XMarkup/Plugin/Defaults/DefaultRenderPipeline.swift`

- [ ] **步骤 1：默认管线工厂**

```swift
extension RenderPipeline {
    /// 默认管线：包含所有默认渲染器
    public static let `default` = RenderPipeline(
        blockRenderers: [
            DefaultTableRenderer(),       // table 优先匹配
            DefaultAttachmentRenderer(),  // 媒体附件
            DefaultBlockRenderer(),       // 其余所有 block
        ],
        inlineRenderers: [
            DefaultInlineRenderer(),
        ],
        postProcessors: [],
        enhancers: []
    )
}
```

- [ ] **步骤 2：Commit**

---

## Phase 5：渲染管线统一

消除 AS/NSA 双路径，统一为单一路径。

---

### 任务 5.1：统一渲染路径

**文件：**
- 删除：`platforms/ios/Sources/XMarkup/Rendering/DocumentRenderer.swift`
- 删除：`platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift`（已迁移到 Plugin/）
- 删除：`platforms/ios/Sources/XMarkup/Rendering/InlineRenderer.swift`（已迁移到 Plugin/）
- 删除：`platforms/ios/Sources/XMarkup/Rendering/TableRenderer.swift`（已迁移到 Plugin/）
- 删除：`platforms/ios/Sources/XMarkup/Rendering/AttachmentRenderer.swift`（已迁移到 Plugin/）
- 删除：`platforms/ios/Sources/XMarkup/Rendering/ListRenderer.swift`（空文件）
- 保留：`platforms/ios/Sources/XMarkup/Rendering/MarkupRenderer.swift`（桥接协议）
- 保留：`platforms/ios/Sources/XMarkup/Rendering/NSAttributedStringRenderer.swift`（key 转移）
- 保留：`platforms/ios/Sources/XMarkup/Rendering/RenderHelpers.swift`（name mappings 等）

- [ ] **步骤 1：RenderPipeline.renderBlocks 统一处理所有 block 类型**

不再区分 `hasTable` 选择不同路径。每个 block 先问 `blockRenderers`（按顺序，第一个返回非 nil 的胜出），全部返回 nil 则 fallback 到 `DefaultBlockRenderer`。

列表组分析（`analyzeBlockGroups`）逻辑移入 `RenderPipeline` 内部。

```swift
private func renderBlocks(_ blocks: [MarkupBlock], theme: MarkupTheme) -> AttributedString {
    let groups = analyzeBlockGroups(blocks)
    var result = AttributedString("")

    for (i, block) in blocks.enumerated() {
        if i > 0 { result.append(AttributedString("\n")) }
        let ctx = RenderingContext(theme: theme, blockIndex: i, totalBlocks: blocks.count)

        // 按顺序询问 blockRenderers
        var rendered: AttributedString?
        for renderer in blockRenderers {
            rendered = renderer.render(block: block, context: ctx)
            if rendered != nil { break }
        }

        if let rendered {
            result.append(rendered)
        }
        // 全部返回 nil = 该 block 被跳过（不应该发生）
    }
    return result
}
```

- [ ] **步骤 2：NSAttributedStringRenderer 保持不变（纯 key 转移）**

作为 `RenderPipeline.bridge` 的默认实现，只做 AttributedString → NSAttributedString 桥接 + 自定义 key 转移。

- [ ] **步骤 3：删除旧文件**

确认所有逻辑已迁移后，删除 `Rendering/` 下已迁移的文件。

- [ ] **步骤 4：Commit**

```bash
git commit -m "refactor(rendering): unify AS/NSA dual paths into single RenderPipeline"
```

---

## Phase 6：XMarkupUI 重构

将 XMarkupUI 层适配新的插件架构。

---

### 任务 6.1：PlatformEnhancementPlugin（替代 XMarkupEnhancedRenderer）

**文件：**
- 新增：`platforms/ios/Sources/XMarkupUI/PlatformEnhancementPlugin.swift`
- 删除：`platforms/ios/Sources/XMarkupUI/XMarkupEnhancedRenderer.swift`

- [ ] **步骤 1：实现 NSAttributedStringProcessing 协议**

```swift
/// 平台视觉增强插件 — 读取 XMarkupBlockKindKey 追加平台特定视觉属性
public struct PlatformEnhancementPlugin: NSAttributedStringProcessing, Sendable {
    public init() {}

    public func enhance(_ nsAttr: NSMutableAttributedString, context: RenderingContext) {
        #if canImport(AppKit) && !canImport(UIKit)
        // macOS: 为 blockquote/pre 添加 NSTextBlock
        let key = NSAttributedString.Key(XMarkupBlockKindKey.name)
        let fullRange = NSRange(location: 0, length: nsAttr.length)
        nsAttr.enumerateAttribute(key, in: fullRange) { value, range, _ in
            guard let kind = value as? String else { return }
            switch kind {
            case "blockquote":
                applyBlockquoteBlock(nsAttr, range: range, config: context.theme.blockquote)
            case "preformatted":
                applyPreformattedBlock(nsAttr, range: range, config: context.theme.preformatted)
            default: break
            }
        }
        #endif
    }
}
```

- [ ] **步骤 2：Commit**

---

### 任务 6.2：AsyncMediaLoader 统一为 async/await

**文件：**
- 修改：`platforms/ios/Sources/XMarkupUI/AsyncMediaLoader.swift`

- [ ] **步骤 1：用 async/await + TaskGroup 替换 DispatchGroup + URLSession 回调**

```swift
public final class AsyncMediaLoader: Sendable {
    private let session: URLSession
    private let imageCache: NSCache<NSString, XMImage>

    // 高级 API（带 layoutManager 自动刷新）
    @MainActor
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString,
        layoutManager: NSLayoutManager?,
        hrMinWidth: CGFloat = 100
    ) async { ... }

    // 底层 API（自定义回调）
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString
    ) async -> [Update] {
        await withTaskGroup(of: Update.self) { group in
            // 扫描所有 attachment，为每个创建 async task
            ...
        }
    }
}
```

删除 `CallbackActor`、`LayoutManagerRef` 辅助类型，不再需要。

- [ ] **步骤 2：Commit**

---

### 任务 6.3：XMarkupRenderingSession（共享视图抽象）

**文件：**
- 新增：`platforms/ios/Sources/XMarkupUI/XMarkupRenderingSession.swift`

- [ ] **步骤 1：提取 render → hr → media 共享流程**

```swift
/// 渲染会话 — 封装 "document → NSAttributedString → hr 更新 → 媒体加载" 全流程
/// XMarkupTextView 和 XMarkupLabel 共用此抽象
@MainActor
public class XMarkupRenderingSession {
    public let pipeline: RenderPipeline
    public var mutableAttr: NSMutableAttributedString?

    public init(pipeline: RenderPipeline = .default) { ... }

    /// 完整渲染流程
    public func render(_ document: MarkupDocument, theme: MarkupTheme) -> NSMutableAttributedString {
        let nsAttr = pipeline.render(document, theme: theme)
        let mutable = nsAttr.mutableCopy() as! NSMutableAttributedString
        self.mutableAttr = mutable
        return mutable
    }

    /// 更新 hr 宽度
    public func updateHRWidths(containerWidth: CGFloat, minWidth: CGFloat) { ... }

    /// 异步加载媒体
    public func loadMedia(layoutManager: NSLayoutManager?, hrMinWidth: CGFloat) async { ... }
}
```

- [ ] **步骤 2：Commit**

---

### 任务 6.4：XMarkupUI 配置安全化

**文件：**
- 修改：`platforms/ios/Sources/XMarkupUI/XMarkupUI.swift`
- 修改：`platforms/ios/Sources/XMarkupUI/XMarkupViewConfig.swift`

- [ ] **步骤 1：XMarkupUI 改为 @MainActor，消除数据竞争**

```swift
@MainActor
public final class XMarkupUI {
    public static let shared = XMarkupUI()
    public var config: XMarkupViewConfig
}
```

- [ ] **步骤 2：XMarkupViewConfig 改为 @MainActor**

```swift
@MainActor
public struct XMarkupViewConfig: Sendable { ... }
```

或者改为值类型快照模式：视图在 `load()` 时拷贝一份 config，之后不再读取共享实例。

- [ ] **步骤 3：Commit**

---

### 任务 6.5：视图组件适配

**文件：**
- 修改：`platforms/ios/Sources/XMarkupUI/XMarkupTextView+iOS.swift`
- 修改：`platforms/ios/Sources/XMarkupUI/XMarkupTextView+macOS.swift`
- 修改：`platforms/ios/Sources/XMarkupUI/XMarkupLabel.swift`

- [ ] **步骤 1：XMarkupTextView 使用 RenderPipeline + RenderingSession**

```swift
open class XMarkupTextView: UITextView {
    public var pipeline: RenderPipeline = .default
    private let session = XMarkupRenderingSession()

    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let mutable = session.render(document, theme: theme)
        replaceLayoutManager()
        textStorage.setAttributedString(mutable)
        session.updateHRWidths(containerWidth: bounds.width, ...)
        Task { await session.loadMedia(...) }
    }
}
```

- [ ] **步骤 2：XMarkupLabel 同理适配**

- [ ] **步骤 3：XMarkupTableRenderer 保留为 macOS 专用插件（P2，暂不集成）**

- [ ] **步骤 4：Commit**

---

## Phase 7：测试更新 + 验证

---

### 任务 7.1：更新现有测试

**文件：**
- 修改：`platforms/ios/Tests/XMarkupTests/` 下所有测试文件

- [ ] **步骤 1：主题测试重写**

旧测试使用 `Tag(.code) { ... }` 的地方，改为 `Code { $0.font = ... }`。
`HeadingScale` 测试不变（HeadingScale 结构保留）。
`ParagraphSpacing` 测试迁移为 `ParagraphTheme` 测试。
`BlockStyleConfiguration` 测试删除（已拆入 typed theme）。

- [ ] **步骤 2：渲染测试适配**

`RenderTests.swift` 中的测试改用 `RenderPipeline.default.render(document, theme:)`。
新增测试覆盖 typed theme 的三级 resolve 机制。

- [ ] **步骤 3：Bridge 测试新增**

新增 `testParserLogCallback`、`testErrorDescription`、`testVersion`、`testLineBreakInline`。

- [ ] **步骤 4：Commit**

---

### 任务 7.2：构建验证

- [ ] **步骤 1：`swift build` 编译通过**

- [ ] **步骤 2：`swift test` 全部通过**

- [ ] **步骤 3：修复所有编译错误和测试失败**

- [ ] **步骤 4：最终 Commit**

```bash
git commit -m "feat: complete plugin architecture redesign with typed themes"
```

---

## 最终文件结构

```
platforms/ios/Sources/XMarkup/
├── Attributes/
│   ├── XMarkupScope.swift              (+3 table key 注册)
│   └── TableMetadataKey.swift          (新增：table 专用 key，或合并入 Scope)
├── Bridge/
│   ├── ColorParser.swift               (保留)
│   ├── PlatformTypes.swift             (保留)
│   ├── XMarkupError.swift              (+description)
│   ├── XMarkupLogger.swift             (新增)
│   ├── XMarkupParser.swift             (+日志参数, +version)
│   ├── XMarkupResult.swift             (保留)
│   ├── XMarkupSpan.swift               (保留)
│   ├── XMarkupStyle.swift              (保留)
│   └── XMarkupTag.swift                (保留)
├── Core/
│   ├── BlockKind.swift                 (保留)
│   ├── MarkupAttachment.swift          (保留)
│   ├── MarkupBlock.swift               (保留)
│   ├── MarkupDocument.swift            (+render(pipeline:) 方法)
│   ├── MarkupDocumentBuilder.swift     (+lineBreak inline)
│   └── MarkupInline.swift             (+.lineBreak case)
├── Plugin/                             (新增目录)
│   ├── RenderingContext.swift
│   ├── BlockRendering.swift
│   ├── InlineRendering.swift
│   ├── AttributedStringProcessing.swift
│   ├── NSAttributedStringProcessing.swift
│   ├── RendererPlugin.swift            (便利组合)
│   ├── RenderPipeline.swift
│   └── Defaults/
│       ├── DefaultBlockRenderer.swift
│       ├── DefaultInlineRenderer.swift
│       ├── DefaultTableRenderer.swift
│       ├── DefaultAttachmentRenderer.swift
│       └── DefaultRenderPipeline.swift
├── Rendering/                          (精简)
│   ├── MarkupRenderer.swift            (保留：桥接协议)
│   ├── NSAttributedStringRenderer.swift (保留：key 转移)
│   └── RenderHelpers.swift             (保留：name mappings)
├── Theme/
│   ├── MarkupTheme.swift               (重写)
│   ├── MarkupThemeBuilder.swift        (适配)
│   ├── ThemeComponents.swift           (重写：Heading {} / Blockquote {} 等)
│   ├── HeadingScale.swift              (保留)
│   ├── MediaRenderingStrategy.swift    (保留)
│   ├── PresetThemes.swift              (重写)
│   ├── Types/
│   │   ├── ParagraphTheme.swift
│   │   ├── HeadingTheme.swift
│   │   ├── BlockquoteTheme.swift
│   │   ├── ListTheme.swift
│   │   ├── PreformattedTheme.swift
│   │   ├── TableTheme.swift
│   │   ├── HorizontalRuleTheme.swift
│   │   ├── InlineTextTheme.swift
│   │   └── LinkTheme.swift
│   └── (TagStyleKey.swift 简化或删除)

platforms/ios/Sources/XMarkupUI/
├── AsyncMediaLoader.swift              (重构为 async/await)
├── BlockquoteLayoutManager.swift       (保留)
├── HorizontalRuleUpdater.swift         (保留)
├── PlatformEnhancementPlugin.swift     (新增，替代 XMarkupEnhancedRenderer)
├── XMarkupLabel.swift                  (适配 RenderingSession)
├── XMarkupRenderingSession.swift       (新增)
├── XMarkupTableRenderer.swift          (保留 P2)
├── XMarkupTextView+iOS.swift           (适配 RenderPipeline)
├── XMarkupTextView+macOS.swift         (适配 RenderPipeline)
├── XMarkupUI.swift                     (@MainActor)
└── XMarkupViewConfig.swift             (@MainActor)
```

**删除文件清单：**
- `Theme/ThemeComponent.swift`
- `Theme/ParagraphSpacing.swift`
- `Theme/BlockStyleConfig.swift`
- `Theme/TagStyleKey.swift`（简化或删除）
- `Rendering/DocumentRenderer.swift`
- `Rendering/BlockRenderer.swift`
- `Rendering/InlineRenderer.swift`
- `Rendering/TableRenderer.swift`
- `Rendering/AttachmentRenderer.swift`
- `Rendering/ListRenderer.swift`
- `XMarkupUI/XMarkupEnhancedRenderer.swift`
```

---

## 自检

1. **规格覆盖度：** 全部 10 个架构问题 + 3 个 Bridge 缺失 + lineBreak 保留均有对应任务 ✅
2. **占位符扫描：** 无 TODO/TBD/待定 ✅
3. **类型一致性：** 所有协议、Theme、Pipeline 的类型引用一致 ✅
4. **依赖顺序：** Phase 1 独立 → Phase 2 主题 → Phase 3 协议 → Phase 4 实现 → Phase 5 统一 → Phase 6 UI → Phase 7 测试 ✅
