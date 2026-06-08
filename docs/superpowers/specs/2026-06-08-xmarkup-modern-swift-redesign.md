# XMarkup iOS 桥接层现代化重构设计

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:writing-plans 创建实现计划。

**目标：** 将 XMarkup iOS 桥接层从命令式 C++ 思维移植彻底重构为现代 Swift 架构——以 `AttributedString` + 自定义 `AttributedStringKey` 为核心，段落/内联两级结构化数据模型，可插拔 Renderer 协议，支持 SwiftUI 原生渲染和第三方图文混排库。

**架构：** 两层架构 + Apple 原生桥接。`MarkupDocument`（段落树 + 内联区间 + 通用附件）作为唯一的平台无关中间表示；`MarkupTheme`（Result Builder DSL）将语义映射到 `AttributeContainer`；输出直接是 Apple 原生 `AttributedString`（携带自定义 XMarkupScope 属性），多种 `MarkupRenderer` 实现消费同一份 `AttributedString`。跨平台（Android/鸿蒙）共享 `MarkupDocument` 概念结构和 Theme DSL 模式，保证 API 风格和视觉行为一致。

**技术栈：** Swift 6.0 / AttributedString + AttributedStringKey / AttributeScope / Result Builders / TextKit 2 / SwiftUI Text

---

## 1. 设计动机

### 1.1 当前问题

| 文件 | 行数 | 问题 |
|------|------|------|
| `NSAttributedString+XMarkup.swift` | ~500 | 6 趟命令式管线，大量 switch/case 分发，手动 enumerateAttribute/addAttribute |
| `XMarkupStyleConfig.swift` | ~180 | 万能配置 struct：混装字体、主题、闭包钩子、媒体处理，`@unchecked Sendable` |
| `spanTransformer` / `postProcessor` | — | 逃逸闭包说明声明式 API 表达力不足 |

核心痛点：
1. **添加新标签 = 修改 3 处 switch**（字体属性、非字体属性、配置覆盖），极易遗漏
2. **不支持 Swift 原生 `AttributedString`**，无法对接 SwiftUI `Text`
3. **扁平 span 丢失父子嵌套**，blockquote 内的段落无法正确继承缩进
4. **配置构建啰嗦**：`config[.heading1] = XMarkupTagStyle(font: ...)`
5. **无法对接第三方图文混排库**（YYText、自绘引擎等）

### 1.2 设计目标

- 以 `AttributedString` 为一等公民，需要 UIKit/AppKit 时零成本桥接到 `NSAttributedString`
- 数据模型支持段落/内联两级结构，保留语义层级
- 可插拔 Renderer 协议，内置 SwiftUI / UIKit / TextKit 2 路径，第三方可扩展
- Result Builder DSL 配置主题，声明式、可序列化
- 跨平台（Android/鸿蒙）共享概念结构，保证 API 风格和视觉行为一致
- 高性能：分段构建 + COW 优化，避免不必要的复制

---

## 2. 架构总览

```
C++ Engine (flat spans: text + [XMSpan])
       ↓ 一次性转换
┌───────────────────────────────────────┐
│         MarkupDocument               │  ① 唯一的平台无关中间表示
│  struct, Sendable, Equatable          │
│                                       │
│  blocks: [MarkupBlock]               │     段落树（h1/p/blockquote/li...）
│    ├─ kind: BlockKind                │
│    ├─ text: Substring                │
│    ├─ inlines: [MarkupInline]        │     (bold/italic/link/code...)
│    └─ attachment: MarkupAttachment?  │     (image/video/audio/custom)
└──────────┬────────────────────────────┘
           │
    ┌──────┴───────┐
    │ MarkupTheme  │  ② 纯值类型样式配置（Result Builder DSL）
    │              │     BlockKind → AttributeContainer
    └──────┬───────┘     MarkupAttachment → 渲染策略
           │
           ↓
┌───────────────────────────────────────┐
│         AttributedString              │  ③ Apple 原生类型
│  (含自定义 XMarkupScope 属性)          │     自带 UIKit/SwiftUI scope
│                                       │     自定义 key 保留语义信息
└──┬────────┬──────────┬────────────┬───┘
   ↓        ↓          ↓            ↓
SwiftUI    UIKit      自绘引擎     第三方
Text拼接   TextKit2   CoreText     (YYText等)
```

---

## 3. 数据模型：MarkupDocument

### 3.1 核心类型

```swift
/// 平台无关的标记文档，从 C++ 引擎的 flat spans 一次性构建
public struct MarkupDocument: Sendable, Equatable {
    /// 段落级块列表
    public let blocks: [MarkupBlock]
}

/// 段落级块（h1-h6, p, blockquote, pre, li, hr, div 等）
public struct MarkupBlock: Sendable, Equatable {
    public let kind: BlockKind
    /// 该段落的纯文本
    public let text: String
    /// 内联样式区间（bold/italic/link/code/mark 等）
    public let inlines: [MarkupInline]
    /// 媒体附件（image/video/audio/custom），非媒体块为 nil
    public let attachment: MarkupAttachment?
}

/// 段落类型
public enum BlockKind: Sendable, Equatable {
    case paragraph
    case heading(Level)          // h1~h6
    case blockquote
    case preformatted
    case listItem(isOrdered: Bool, indentLevel: Int)
    case division
    case horizontalRule
    case table(TableStructure)   // 表格特殊处理
}

/// 标题级别
public enum Level: Int, Sendable, Equatable {
    case h1 = 1, h2, h3, h4, h5, h6
}

/// 表格结构
public struct TableStructure: Sendable, Equatable {
    public let rows: [[MarkupBlock]]  // 每行每列的块
    public let headerRowCount: Int
    public let columnCount: Int
}

/// 内联样式（字符级）
public struct MarkupInline: Sendable, Equatable {
    /// 在所属 block.text 中的范围（String.Index）
    public let range: Range<String.Index>
    /// 内联类型
    public let kind: InlineKind
}

/// 内联类型
public enum InlineKind: Sendable, Equatable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case mark
    case link(url: String)
    case subscriptText
    case superscript
    case span(styles: [InlineStyle])
}

/// CSS 行内样式
public enum InlineStyle: Sendable, Equatable {
    case foregroundColor(String)    // "#RRGGBB"
    case backgroundColor(String)
    case fontSize(Float)
    case fontWeight(String)
    case fontStyle(String)
    case textDecoration(String)
    case lineHeight(Float)
    case letterSpacing(Float)
}
```

### 3.2 通用附件模型

```swift
/// 平台无关的媒体附件描述
public struct MarkupAttachment: Sendable, Equatable {
    public let content: AttachmentContent
    public let suggestedSize: CGSize
    public let alignment: AttachmentAlignment
}

public enum AttachmentContent: Sendable, Equatable {
    case image(src: String)
    case video(src: String)
    case audio(src: String)
    /// 第三方扩展入口
    case custom(type: String, metadata: [String: String])
}

public enum AttachmentAlignment: Sendable, Equatable {
    case `default`
    case center
    case leading
    case trailing
}
```

### 3.3 从 C++ flat spans 构建 MarkupDocument

构建器消费 C++ 核心的 `XMarkupResult`（text + flat spans），将其转为段落/内联两级结构：

```swift
extension MarkupDocument {
    /// 从 C++ 桥接结果构建
    ///
    /// 算法：
    /// 1. 按 \n 分割 text 为段落
    /// 2. 遍历 spans，识别块级 tag（h1-h6/p/blockquote/li/...）
    /// 3. 将块级 tag 映射到对应段落的 BlockKind
    /// 4. 剩余非块级 span 映射为对应段落的 MarkupInline
    /// 5. 媒体类 tag (img/video/audio) 映射为 MarkupAttachment
    public static func from(_ result: XMarkupResult) -> MarkupDocument
}
```

### 3.4 增量更新预留

```swift
extension MarkupDocument {
    /// 追加内容（聊天场景）
    public func appending(_ other: MarkupDocument) -> MarkupDocument

    /// 计算差异（预留接口，后期实现）
    public func diff(from old: MarkupDocument) -> DocumentDiff
}

/// 文档差异（后期实现）
public struct DocumentDiff: Sendable {
    public let inserted: [Int]      // 新增块的索引
    public let removed: [Int]       // 删除块的索引
    public let modified: [Int]      // 修改块的索引
}
```

---

## 4. 主题系统：MarkupTheme

### 4.1 核心类型

```swift
/// 纯值类型的样式主题，可序列化、可比较、可复用
public struct MarkupTheme: Sendable, Equatable {
    /// 基础字体
    public var baseFont: XMFont
    /// 标题缩放系数
    public var headingScale: HeadingScale
    /// 标签样式映射
    public var tagStyles: [TagStyleKey: AttributeContainer]
    /// 媒体渲染策略
    public var mediaStrategy: MediaRenderingStrategy
}

/// 标题缩放配置
public struct HeadingScale: Sendable, Equatable {
    public var h1: CGFloat  // 默认 2.0
    public var h2: CGFloat  // 默认 1.5
    public var h3: CGFloat  // 默认 1.17
    public var h4: CGFloat  // 默认 1.0
    public var h5: CGFloat  // 默认 0.83
    public var h6: CGFloat  // 默认 0.67
}

/// 主题配置 key（用于 tagStyles 字典）
public enum TagStyleKey: String, Sendable, Equatable, Hashable {
    case bold, italic, underline, strikethrough, code, mark
    case link, heading, paragraph, blockquote, preformatted
    case listItem, division, horizontalRule
    case image, video, audio
}

/// 媒体渲染策略
public enum MediaRenderingStrategy: Sendable {
    /// 使用 SF Symbol 占位图（默认）
    case placeholder
    /// 通过闭包加载图片
    case imageProvider(@Sendable (String) -> XMImage?)
    /// 通过闭包创建自定义附件
    case customAttachment(@Sendable (AttachmentContent, CGSize) -> NSTextAttachment?)
}
```

### 4.2 Result Builder DSL

```swift
@resultBuilder
public enum MarkupThemeBuilder {
    public static func buildBlock(_ components: ThemeComponent...) -> [ThemeComponent]
}

/// 主题 DSL 组件（协议）
public protocol ThemeComponent: Sendable {
    func apply(to theme: inout MarkupTheme)
}

// DSL 示例用法：
let theme = MarkupTheme {
    BaseFont(.systemFont(ofSize: 17))
    HeadingScale(h1: 2.0, h2: 1.5, h3: 1.17)

    Tag(.heading) { level in
        switch level {
        case .h1: return AttributeContainer().uiKit.font(.systemFont(ofSize: 28, weight: .bold))
        case .h2: return AttributeContainer().uiKit.font(.systemFont(ofSize: 22, weight: .bold))
        default:   return AttributeContainer()
        }
    }

    Tag(.code) {
        $0.uiKit.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        $0.uiKit.backgroundColor = .systemGray6
    }

    Tag(.link) {
        $0.uiKit.foregroundColor = .tintColor
    }

    Tag(.blockquote) {
        $0.uiKit.foregroundColor = .secondaryLabel
    }

    Media(.imageProvider) { src in
        // 异步加载图片，返回 nil 时回退到占位图
        ImageCache.shared.load(src)
    }
}
```

### 4.3 预置主题

```swift
extension MarkupTheme {
    /// 通用主题（当前 .default 的等价物）
    public static let `default`: MarkupTheme

    /// 暗色模式主题
    public static let dark: MarkupTheme

    /// 聊天气泡主题（小字体、小媒体）
    public static let chat: MarkupTheme

    /// 文章阅读主题（大字体、宽媒体）
    public static let article: MarkupTheme
}
```

---

## 5. 自定义 AttributedStringKey

### 5.1 XMarkupScope

```swift
/// XMarkup 自定义属性作用域
/// 携带语义信息，与 UIKit/SwiftUI scope 共存于同一个 AttributedString
enum XMarkupScope: AttributeScope {
    var xmarkupTag: XMarkupTagKey { get {} }
    var xmarkupBlockKind: XMarkupBlockKindKey { get {} }
    var xmarkupLinkURL: XMarkupLinkURLKey { get {} }
    var xmarkupHeadingLevel: XMarkupHeadingLevelKey { get {} }
    var xmarkupListItemInfo: XMarkupListItemInfoKey { get {} }
    var xmarkupAttachmentRef: XMarkupAttachmentRefKey { get {} }
}

struct XMarkupTagKey: AttributedStringKey {
    typealias Value = String
    static let name = "XMarkup.Tag"
}

struct XMarkupBlockKindKey: AttributedStringKey {
    typealias Value = String
    static let name = "XMarkup.BlockKind"
}

struct XMarkupLinkURLKey: AttributedStringKey {
    typealias Value = String
    static let name = "XMarkup.LinkURL"
}

struct XMarkupHeadingLevelKey: AttributedStringKey {
    typealias Value = Int
    static let name = "XMarkup.HeadingLevel"
}

struct XMarkupListItemInfoKey: AttributedStringKey {
    typealias Value = String  // "ordered:1" or "unordered:0" 等编码
    static let name = "XMarkup.ListItemInfo"
}

struct XMarkupAttachmentRefKey: AttributedStringKey {
    typealias Value = String  // attachment 的标识符，指向 MarkupDocument 中的 attachment
    static let name = "XMarkup.AttachmentRef"
}
```

### 5.2 为什么自定义 key 能存活

经过 API 验证确认：

```swift
// 1. AttributedString 同时携带 UIKit 属性 + 自定义属性 ✅
attr.uiKit.foregroundColor = .red
attr[XMarkupTagKey.self] = "heading1"

// 2. 桥接到 NSAttributedString 时，自定义属性通过 raw key 名保留 ✅
let nsAttr = NSAttributedString(attr)
nsAttr.attribute(NSAttributedString.Key("XMarkup.Tag"), at: 0, ...)  // 可读取

// 3. 桥接回来时，自定义属性完整恢复 ✅
let back = AttributedString(nsAttr)
back[XMarkupTagKey.self]  // "heading1"

// 4. SwiftUI Text(attributedString) 静默忽略自定义属性，但保留 UIKit/SwiftUI 属性 ✅
```

---

## 6. 渲染管线

### 6.1 MarkupDocument → AttributedString

这是核心转换。主题（MarkupTheme）将语义块映射到视觉属性：

```swift
extension MarkupDocument {
    /// 将文档转换为 AttributedString
    ///
    /// 性能策略：按 block 分段构建（init(String, attributes: AttributeContainer)），
    /// 然后一次性 append 拼接。利用 AttributedString 的 COW 优化，
    /// 避免大范围 mutation 造成的复制开销。
    public func render(theme: MarkupTheme = .default) -> AttributedString
}
```

内部实现流程：
1. 遍历 blocks，为每个 block 生成一个 `AttributedString` 段
2. 将 block.kind 通过 theme 解析为 `AttributeContainer`（字体大小、颜色等）
3. 为每个 block 设置 XMarkupScope 自定义 key：`xmarkupTag`、`xmarkupBlockKind`、`xmarkupHeadingLevel`/`xmarkupListItemInfo` 等
4. 将 block.inlines 逐个应用：bold → 添加 bold trait，link → 添加 `.link` + `xmarkupLinkURL` 自定义 key
5. 处理 attachment：根据 mediaStrategy 决定占位符/自定义附件，设置 `xmarkupAttachmentRef`
6. 段与段之间追加 `\n` 分隔符（块级元素之间的换行）
7. `BlockKind.table` 在 P1 阶段按行列顺序拼接为纯文本段落（无特殊布局），完整表格布局算法在 P3 远期规划
8. 拼接所有段返回完整的 `AttributedString`

### 6.2 MarkupRenderer 协议

```swift
/// 可插拔的渲染器协议
///
/// 所有渲染器消费 AttributedString（可能携带自定义 XMarkupScope 属性），
/// 而非自定义类型。第三方库通过 NSAttributedString(AttributedString) 桥接后
/// 读取标准属性 + 自定义 XMarkup key。
protocol MarkupRenderer<Output>: Sendable {
    associatedtype Output

    /// 渲染
    func render(_ attributed: AttributedString) -> Output

    /// 测量内容尺寸（用于布局计算）
    func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize
}
```

### 6.3 内置渲染器

#### NSAttributedStringRenderer（UIKit/AppKit）

```swift
/// 最简单的渲染器——零成本桥接
/// NSAttributedString(AttributedString) 是 O(1) 桥接
struct NSAttributedStringRenderer: MarkupRenderer {
    typealias Output = NSAttributedString

    func render(_ attributed: AttributedString) -> NSAttributedString {
        return NSAttributedString(attributed)
    }

    func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize {
        let nsAttr = NSAttributedString(attributed)
        let size = nsAttr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}
```

#### SwiftUITextRenderer（SwiftUI 纯文本）

```swift
/// 将 AttributedString 拆解为 Text 片段 + Image 插值
/// 适用于纯文本场景（无自定义 View 内嵌需求）
///
/// 注意：SwiftUI Text 有以下限制：
/// - 不渲染 NSTextAttachment（静默忽略）
/// - 不渲染自定义 AttributedStringKey（静默忽略）
/// - 不支持内联任意 View
/// 因此此渲染器需要手动处理附件，将其转为 Image 插值
struct SwiftUITextRenderer: MarkupRenderer {
    typealias Output = Text

    func render(_ attributed: AttributedString) -> Text {
        var result = Text("")
        for run in attributed.runs {
            var segment = Text(attributed[run.range])
            // 根据附件属性插入 Image
            // 根据自定义 key 添加 SwiftUI modifier
        }
        return result
    }

    func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize {
        // SwiftUI 中通过 GeometryReader 或 modified(ContentSizePreferenceKey) 测量
        // 此处返回 .zero，实际测量由 SwiftUI 布局系统完成
        return .zero
    }
}
```

#### TextKit2Renderer（UIKit 完整渲染）

```swift
/// 使用 NSTextLayoutManager + NSTextAttachmentViewProvider
/// 支持内联自定义 View、文本选择、图文混排
/// 适用于需要完整富文本编辑/展示能力的 UIKit 场景
struct TextKit2Renderer: MarkupRenderer {
    typealias Output = UITextView

    func render(_ attributed: AttributedString) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.linkTextAttributes = [:]  // 让 NSAttributedString 自身的颜色生效
        textView.attributedText = NSAttributedString(attributed)
        return textView
    }

    func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize {
        // 使用 NSTextLayoutManager 计算布局
    }
}
```

### 6.4 第三方渲染器示例

```swift
/// 第三方库只需实现 MarkupRenderer 协议
/// 通过 AttributedString → NSAttributedString 桥接后读取属性
struct YYTextRenderer: MarkupRenderer {
    typealias Output = YYLabel

    func render(_ attributed: AttributedString) -> YYLabel {
        let nsAttr = NSAttributedString(attributed)
        let label = YYLabel()
        // 读取标准属性 + 自定义 XMarkup key
        // 将 NSTextAttachment 转为 YYImage
        label.attributedText = convertToYYTextFormat(nsAttr)
        return label
    }

    func measure(_ attributed: AttributedString, constrainedTo width: CGFloat) -> CGSize {
        // YYText 自有的尺寸计算
    }
}
```

---

## 7. 用户侧 API 总览

### 7.1 基础用法

```swift
// 解析
let parser = try XMarkupParser()
let result = try parser.parse("<h1>Title</h1><p>Hello <b>world</b></p>")

// 构建结构化文档
let document = MarkupDocument.from(result)

// 渲染为 AttributedString（默认主题）
let attributed = document.render()

// SwiftUI 直接使用
Text(attributed)
```

### 7.2 自定义主题

```swift
let theme = MarkupTheme {
    BaseFont(.systemFont(ofSize: 17))
    HeadingScale(h1: 2.0, h2: 1.5, h3: 1.17)

    Tag(.heading) { level in
        var c = AttributeContainer()
        switch level {
        case .h1: c.uiKit.font = .systemFont(ofSize: 28, weight: .bold)
        case .h2: c.uiKit.font = .systemFont(ofSize: 22, weight: .bold)
        default: break
        }
        return c
    }

    Tag(.link) {
        $0.uiKit.foregroundColor = .systemBlue
    }

    Tag(.code) {
        $0.uiKit.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        $0.uiKit.backgroundColor = .systemGray6
    }
}

let attributed = document.render(theme: theme)
```

### 7.3 渲染到不同后端

```swift
// UIKit
let nsRenderer = NSAttributedStringRenderer()
let nsAttr = nsRenderer.render(attributed)
textView.attributedText = nsAttr

// TextKit 2 完整渲染
let tk2Renderer = TextKit2Renderer()
let textView = tk2Renderer.render(attributed)

// SwiftUI 纯文本
let swiftUIRenderer = SwiftUITextRenderer()
let text = swiftUIRenderer.render(attributed)

// 第三方库
let yyRenderer = YYTextRenderer()
let yyLabel = yyRenderer.render(attributed)
```

### 7.4 测量

```swift
let renderer = NSAttributedStringRenderer()
let size = renderer.measure(attributed, constrainedTo: 320)
// CGSize(width: 320, height: 256)
```

---

## 8. 跨平台一致性

### 8.1 共享概念

| 概念 | iOS (Swift) | Android (Kotlin) | 鸿蒙 (ArkTS) |
|------|------------|-------------------|---------------|
| 文档模型 | `MarkupDocument` | `MarkupDocument` | `MarkupDocument` |
| 段落块 | `MarkupBlock` | `MarkupBlock` | `MarkupBlock` |
| 内联样式 | `MarkupInline` | `MarkupInline` | `MarkupInline` |
| 附件 | `MarkupAttachment` | `MarkupAttachment` | `MarkupAttachment` |
| 主题 | `MarkupTheme` + DSL | `MarkupTheme` + DSL | `MarkupTheme` + DSL |
| 渲染器协议 | `MarkupRenderer` | `MarkupRenderer` | `MarkupRenderer` |
| 内置渲染器 | NSAttr/TextKit2/SwiftUI | SpannedString/Compose | Text/Canvas |

### 8.2 保证机制

1. **概念结构由 C++ 核心的 tag 枚举统一定义**（`XM_TAG_BOLD` 等），三平台从同一份 flat spans 构建等价的 `MarkupDocument`
2. **Theme DSL 的映射规则一致**：三个平台都是 `Tag(.heading) { ... }` 模式，只是具体属性类型不同（UIFont vs Typeface vs Font）
3. **Renderer 协议签名一致**：`render(input) → Output` + `measure(input, width) → Size`
4. **视觉行为由 BlockKind 统一保证**：三个平台的 heading1 都使用 h1 对应的缩放系数，blockquote 都有缩进

---

## 9. 文件结构规划

### 9.1 当前结构（重构前）

```
platforms/ios/Sources/XMarkup/           ← 扁平目录，无子目录
├── ColorParser.swift                    # 颜色解析
├── NSAttributedString+XMarkup.swift     # 6 趟渲染管线（将被删除）
├── PlatformTypes.swift                  # XMFont/XMColor 类型别名
├── XMarkupError.swift                   # 错误枚举
├── XMarkupParser.swift                  # C++ 引擎桥接
├── XMarkupResult.swift                  # C++ 结果桥接
├── XMarkupSpan.swift                    # C++ Span 映射
├── XMarkupStyle.swift                   # CSS Style 枚举
├── XMarkupStyleConfig.swift             # 配置 struct（将被删除）
└── XMarkupTag.swift                     # Tag 枚举

platforms/ios/Tests/XMarkupTests/        ← 扁平目录
├── ColorParserTests.swift
├── CrossPlatformTests.swift
├── NSAttributedStringTests.swift         # 将重写为 AttributedString 渲染测试
├── StyleConfigTests.swift               # 将重写为 Theme 测试
├── XMarkupParserTests.swift
└── XMarkupResultTests.swift
```

### 9.2 目标结构（重构后）

```
platforms/ios/Sources/XMarkup/           ← SPM 递归扫描子目录，无需改 Package.swift
├── Core/
│   ├── MarkupDocument.swift             # [新建] MarkupDocument + MarkupBlock + BlockKind
│   ├── MarkupInline.swift              # [新建] MarkupInline + InlineKind + InlineStyle
│   ├── MarkupAttachment.swift          # [新建] MarkupAttachment + AttachmentContent
│   ├── MarkupDocumentBuilder.swift     # [新建] XMarkupResult → MarkupDocument 转换
│   └── DocumentDiff.swift              # [新建] 增量更新（预留接口）
├── Theme/
│   ├── MarkupTheme.swift               # [新建] MarkupTheme 主结构
│   ├── HeadingScale.swift              # [新建] 标题缩放配置
│   ├── MediaRenderingStrategy.swift    # [新建] 媒体渲染策略
│   ├── ThemeComponent.swift            # [新建] ThemeComponent 协议 + DSL 组件
│   ├── MarkupThemeBuilder.swift        # [新建] @resultBuilder
│   └── PresetThemes.swift              # [新建] .default / .dark / .chat / .article
├── Attributes/
│   ├── XMarkupScope.swift              # [新建] 自定义 AttributedStringKey + AttributeScope
│   └── AttributeContainer+Theme.swift  # [新建] 主题解析扩展
├── Rendering/
│   ├── MarkupRenderer.swift            # [新建] MarkupRenderer 协议
│   ├── NSAttributedStringRenderer.swift # [新建] UIKit/AppKit 渲染器
│   ├── SwiftUITextRenderer.swift       # [P2] SwiftUI Text 渲染器
│   ├── TextKit2Renderer.swift          # [P2] TextKit 2 渲染器
│   └── MarkupDocument+Render.swift     # [新建] render(theme:) 实现
├── Bridge/
│   ├── PlatformTypes.swift             # [迁移] ← 原 PlatformTypes.swift（不变）
│   ├── XMarkupParser.swift             # [迁移] ← 原 XMarkupParser.swift（更新文档注释）
│   ├── XMarkupResult.swift             # [迁移] ← 原 XMarkupResult.swift（更新文档注释）
│   ├── XMarkupSpan.swift               # [迁移] ← 原 XMarkupSpan.swift，改标记 internal
│   ├── XMarkupTag.swift                # [迁移] ← 原 XMarkupTag.swift（保留 public）
│   ├── XMarkupStyle.swift              # [迁移] ← 原 XMarkupStyle.swift，改标记 internal
│   ├── XMarkupError.swift              # [迁移] ← 原 XMarkupError.swift（不变）
│   └── ColorParser.swift               # [迁移] ← 原 ColorParser.swift（不变）
└── XMarkup.swift                        # [新建] 公共导出（re-export 所有 public 类型）
```

### 9.3 测试文件目标结构

```
platforms/ios/Tests/XMarkupTests/
├── Core/
│   ├── MarkupDocumentTests.swift       # [新建] MarkupDocument 构建和结构测试
│   ├── MarkupDocumentBuilderTests.swift # [新建] XMarkupResult → MarkupDocument 转换测试
│   └── MarkupAttachmentTests.swift     # [新建] 附件模型测试
├── Theme/
│   ├── MarkupThemeTests.swift          # [新建] 主题配置测试
│   ├── ThemeBuilderTests.swift         # [新建] Result Builder DSL 测试
│   └── PresetThemesTests.swift         # [新建] 预置主题测试
├── Rendering/
│   ├── RenderTests.swift               # [新建] MarkupDocument → AttributedString 渲染测试
│   └── NSAttributedStringRendererTests.swift # [新建] NSAttr 渲染器测试
├── Bridge/
│   ├── XMarkupParserTests.swift        # [迁移] ← 原文件（不变）
│   ├── XMarkupResultTests.swift        # [迁移] ← 原文件（不变）
│   ├── ColorParserTests.swift          # [迁移] ← 原文件（不变）
│   └── CrossPlatformTests.swift        # [迁移] ← 原文件（不变）
```

### 9.4 文件变更汇总

| 操作 | 文件数 | 说明 |
|------|--------|------|
| 新建 | 14 | Core/4 + Theme/6 + Attributes/2 + Rendering/2 |
| 迁移（移动到子目录） | 8 | Bridge/8 |
| 删除 | 4 | XMarkupStyleConfig + NSAttributedString+XMarkup + 对应测试 |
| P2 后期新建 | 2 | SwiftUITextRenderer + TextKit2Renderer |

### 9.5 SPM 兼容性

当前 `Package.swift` 的 target 配置：
```swift
.target(name: "XMarkup", dependencies: ["CXMarkup"], path: "platforms/ios/Sources/XMarkup")
```

SPM 默认递归扫描 `path` 下所有 `.swift` 文件，**子目录自动包含**，无需修改 `Package.swift`。测试 target 同理。

---

## 10. 旧 API 清理

由于组件尚未正式发布，直接删除旧 API 而非标记废弃：

| 已删除 API | 替代方案 |
|---------|--------|
| `XMarkupResult.makeAttributedString(config:)` | `MarkupDocument.from(result).render(theme:)` |
| `XMarkupStyleConfig` | `MarkupTheme` |
| `XMarkupTagStyle` | `AttributeContainer`（通过 Tag DSL） |
| `NSAttributedString+XMarkup.swift` | `MarkupDocument+Render.swift` |
| `NSAttributedStringTests.swift` | `RenderTests.swift` |
| `StyleConfigTests.swift` | `MarkupThemeTests.swift` |

---

## 11. 后期迭代规划

### P1 — 本期实现

- MarkupDocument 数据模型 + 构建器
- XMarkupScope 自定义 AttributeKey
- MarkupTheme + Result Builder DSL
- MarkupRenderer 协议 + NSAttributedStringRenderer
- MarkupDocument.render(theme:) 核心渲染管线
- 预置主题
- 废弃旧 API 的兼容层
- 完整测试覆盖

### P2 — 后续版本

- **SwiftUITextRenderer**：AttributedString → Text + Image 拼接的完整实现
- **TextKit2Renderer**：NSTextLayoutManager + NSTextAttachmentViewProvider 完整实现
- **深色模式**：MarkupTheme 中支持 light/dark 双套配色
- **Measure API 完善**：Renderer.measure 的精确实现

### P3 — 远期规划

- **DocumentDiff 增量更新**：聊天场景下的追加/差异计算 + 增量渲染
- **MarkupTheme 序列化**：JSON/Codable 支持，允许从配置文件加载主题
- **无障碍映射**：VoiceOver 语义属性（heading level、link destination）
- **表格渲染**：TableStructure 的布局算法
- **自定义 Renderer 注册表**：第三方库可注册全局默认 Renderer
- **AttributedString 性能 profile**：大文档（>10000 字）场景的性能基准测试
- **Android/鸿蒙 MarkupDocument 等价实现**：跨平台一致性验证

---

## 12. 性能策略

### 12.1 构建阶段（XMarkupResult → MarkupDocument）

- 一次性遍历 flat spans，按块级 tag 分组
- 使用 `reserveCapacity` 预分配数组
- 字符串切片用 `String.Index` 而非 `NSRange`（避免 UTF-16 转换开销）

### 12.2 渲染阶段（MarkupDocument → AttributedString）

- 按 block 分段构建：`init(String, attributes: AttributeContainer)`
- 一次性 `append` 拼接，避免逐字符 mutation
- 利用 AttributedString COW 优化：inline mutation `attr[range].font = ...` 不触发全量复制
- 内联样式通过 `enumerateAttribute` 或 `runs` 遍历应用

### 12.3 桥接阶段（AttributedString → NSAttributedString）

- `NSAttributedString(AttributedString)` 是 O(1) 零成本桥接（Apple 内部实现为共享存储）
- 自定义 AttributeKey 通过 raw key 名传递，无序列化/反序列化开销

### 12.4 缓存策略

- `MarkupDocument` 是不可变值类型，同一 result 产出同一 document，可安全缓存
- `MarkupTheme` 是不可变值类型，同一 theme + 同一 document = 同一 AttributedString
- 后期可实现 `render(theme:)` 的 Memoization（以 document + theme 的 hash 为 key）

---

## 13. 测试策略

### 13.1 数据模型测试

- `XMarkupResult → MarkupDocument` 转换正确性（各种 HTML 结构）
- 段落/内联正确分组（嵌套 blockquote + p、列表项、表格）
- 附件正确映射（img/video/audio/source 子元素）
- 边界情况：空文档、纯文本无标签、未知标签、超长文档

### 13.2 主题测试

- 预置主题的默认值验证
- Result Builder DSL 构建正确性
- Tag(.heading) 的级别分发正确性
- Media strategy 的占位图/自定义加载回退

### 13.3 渲染测试

- AttributedString 输出的属性正确性（字体 trait、颜色、下划线等）
- 自定义 XMarkupScope key 在 AttributedString 中存活
- NSAttributedString 桥接后自定义 key 存活
- Renderer.measure 的尺寸精度

### 13.4 性能测试

- 大文档（10000 字）的 render 耗时基准
- 多次 render 同一 document + theme 的缓存效果（后期）
- AttributedString 构建模式对比（分段 vs 全量 mutation）
