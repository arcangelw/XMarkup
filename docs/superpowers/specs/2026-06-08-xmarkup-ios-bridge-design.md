# XMarkup iOS 桥接层设计规格

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:writing-plans` 创建实现计划。核心引擎改进项（#1、#2）应作为前置任务优先实现。

**目标：** 为 XMarkup C++ 核心引擎构建 Swift 桥接层，提供原始数据层（XMarkupResult）和便利层（NSAttributedString）双层 API，支持 iOS 15+ 和 macOS 12+。

**架构：** SPM 双 target 结构——`CXMarkup`（C library target，编译 C++ 源码并暴露 C API 头文件）+ `XMarkup`（Swift target，桥接层）。通过 `@unchecked Sendable` final class 封装 C API 生命周期，值类型承载解析结果，两趟处理算法将 span 映射为 NSAttributedString 属性。

**技术栈：** Swift 6+ / Xcode 26+ / SPM / C++17（源码集成）/ XCTest

---

## 目录

- [1. 核心引擎前置改进](#1-核心引擎前置改进)
- [2. Package 结构与模块划分](#2-package-结构与模块划分)
- [3. Swift 类型体系](#3-swift-类型体系)
- [4. XMarkupParser 生命周期](#4-xmarkupparser-生命周期)
- [5. NSAttributedString 便利层](#5-nsattributedstring-便利层)
- [6. 跨平台支持](#6-跨平台支持)
- [7. 跨平台注释规范](#7-跨平台注释规范)
- [8. 文件清单](#8-文件清单)
- [9. 测试策略](#9-测试策略)
- [10. 设计决策记录](#10-设计决策记录)

---

## 1. 核心引擎前置改进

以下改进须在 iOS 桥接层开发前完成，因为三端桥接层（iOS/Android/鸿蒙）均依赖这些改进。

### 1.1 `base_font_size` uint16 → float

**问题：** `XMConfig.base_font_size` 类型为 `uint16_t`，CSS 单位换算全程使用整数运算，导致精度丢失（如 `14.5px` → `14`）。三端平台（UIFont.pointSize / AbsoluteSizeSpan(float) / FontSize(float)）均支持浮点字号。

**改动范围：**

| 文件 | 改动 |
|------|------|
| `core/include/xmarkup/xmarkup.h` | `uint16_t base_font_size` → `float base_font_size` |
| `core/src/style_resolver.cpp` | `normalize_font_size()` 中换算逻辑适配 `float`，输出保留 2 位小数 |
| `core/src/parser.cpp` | 默认 config 适配 float |
| `tests/test_style_resolver.cpp` | 验证浮点精度（如 `1.5em × 14.5 = 21.75`） |
| `tests/test_api.cpp` | 验证浮点 base_font_size 下的端到端结果 |

### 1.2 零长度 Tag 插入占位字符

**问题：** `image`、`lineBreak`、`horizontalRule`、`video`、`audio` 等标签不产生文本，导致 span range 长度为 0。三端平台均无法对零长度 range 挂载内嵌对象（NSTextAttachment / ImageSpan / ImageSpan）。

**改动范围：**

| 文件 | 改动 |
|------|------|
| `core/src/style_resolver.cpp` | `dfs()` 方法中，对 void/empty 元素插入占位字符 |
| `tests/test_style_resolver.cpp` | 验证占位字符存在，range 非零长度 |
| `tests/test_api.cpp` | 端到端验证 |

**占位字符映射表：**

| Tag | 插入字符 | Unicode | 说明 |
|-----|----------|---------|------|
| `image` | `\u{FFFC}` | U+FFFC 对象替换字符 | 通用内嵌对象标记 |
| `video` | `\u{FFFC}` | U+FFFC | 同上 |
| `audio` | `\u{FFFC}` | U+FFFC | 同上 |
| `lineBreak` | `\n` | U+000A | 自然换行 |
| `horizontalRule` | `\u{FFFC}` | U+FFFC | 占位 + 自定义渲染 |

**注意：** 此改动改变输出 text 内容（增加占位符），属于 breaking change。当前 0.1.0 无外部消费者，改动成本最低。

### 1.3 验证段落分隔符

**需验证：** `<p>段落1</p><p>段落2</p>` 输出是否为 `段落1\n段落2`（含换行符）。如果未插入换行，需要修复，因为三端段落排版均依赖换行符。

### 1.4 消除硬编码 + 命名常量

**当前硬编码项 → 常量化：**

| 硬编码 | 常量名 | 注释要求 |
|--------|--------|----------|
| `256`（默认深度） | `kDefaultMaxNestingDepth` | 说明选择理由 |
| `16`（默认字号） | `kDefaultBaseFontSize` | 说明选择理由 |
| `1.333`（pt→px 系数） | `kPtToPxFactor` | 注明换算公式来源：`96dpi / 72pt/inch` |
| heading 倍率数组 | `kHeadingScale[6]` | 注明来源：浏览器默认样式表 |
| 14 个 void 元素 | `kVoidElements[]` | 注明来源：HTML5 规范 URL |
| ~120 个命名实体 | `named_entities()` | 注明来源：HTML5 规范 |

### 1.5 C++ 核心函数 Doxygen 注释

**覆盖要求：** 所有 `core/src/` 中的公开方法声明添加 Doxygen 注释，包含：
- `@brief` 简述
- `@param` 参数说明
- `@return` 返回值说明
- `@note` 使用注意事项
- `@code ... @endcode` 使用示例（生命周期函数、核心功能函数）
- 逻辑注释解释 WHY（算法选择、边界处理策略）

### 1.6 补充边界/异常测试用例

| 模块 | 缺失场景 |
|------|----------|
| StyleResolver | CSS 负值字号、零值字号、空 style 属性、无效颜色值 |
| StyleResolver | 嵌套 `<pre>` 内的空白行为、`<pre>` 内含实体解码 |
| EntityDecoder | 超大数字实体、负数实体、surrogate 范围实体 |
| Tokenizer | 属性值含 `<`、属性值含 `&`、超长属性值 |
| TreeBuilder | `<li>` 在非列表父级、`<td>` 在非表格父级 |
| API | 纯中文 HTML、混合多语言（中英日韩 Emoji）、BOM 头 |
| API | 连续多次 parse 结果互不干扰、destroy 后 parse 崩溃保护 |

### 1.7 `xmarkup_version()` API（低优先级）

```c
/**
 * @brief 获取 XMarkup 版本号
 * @return 版本字符串，格式 "major.minor.patch"，静态存储无需释放
 * @code
 * printf("XMarkup version: %s\\n", xmarkup_version());
 * @endcode
 */
const char* xmarkup_version(void);
```

---

## 2. Package 结构与模块划分

```
XMarkup/                           ← 仓库根目录
├── Package.swift                  ← SPM 清单
├── core/                          ← 已有，C++ 核心引擎
│   ├── include/xmarkup/xmarkup.h
│   └── src/*.cpp, *.h
├── platforms/
│   └── ios/
│       └── Sources/
│           └── XMarkup/           ← Swift 桥接层源码
│               ├── XMarkupParser.swift
│               ├── XMarkupResult.swift
│               ├── XMarkupTag.swift
│               ├── XMarkupStyle.swift
│               ├── XMarkupSpan.swift
│               ├── XMarkupError.swift
│               ├── PlatformTypes.swift
│               ├── ColorParser.swift
│               └── NSAttributedString+XMarkup.swift
├── Tests/
│   └── XMarkupTests/
│       ├── XMarkupParserTests.swift
│       ├── XMarkupResultTests.swift
│       ├── NSAttributedStringTests.swift
│       ├── ColorParserTests.swift
│       └── CrossPlatformTests.swift
├── .swiftlint.yml
├── .swiftformat
├── LICENSE
└── README.md
```

### SPM Target 配置

**Target 1：`CXMarkup`（C library target）**

- `path: "core"`
- `sources: ["src"]`
- `publicHeadersPath: "include"`
- `cxxSettings: [.unsafeFlags(["-std=c++17"]), .headerSearchPath("src")]`
- SPM 自动生成 modulemap，Swift 侧 `import CXMarkup` 可直接调用 C API

**Target 2：`XMarkup`（Swift target）**

- `path: "platforms/ios/Sources/XMarkup"`
- `dependencies: ["CXMarkup"]`

**测试 Target：`XMarkupTests`**

- `dependencies: ["XMarkup"]`

**平台要求：** `.iOS(.v15), .macOS(.v12)`

---

## 3. Swift 类型体系

### 3.1 XMarkupError

```swift
/// XMarkup 解析错误
public enum XMarkupError: Error, Sendable {
    /// 解析器指针为 NULL
    case nullParser
    /// 输入 HTML 为 NULL
    case nullInput
    /// 嵌套深度超出限制，已截断
    case nestingOverflow
    /// 内存分配失败
    case allocationFailed
    /// 未知错误，保留原始错误码
    case unknown(code: Int32)

    /// 从 C API 错误码初始化
    init(cError: XMError)
}
```

### 3.2 XMarkupTag

```swift
/// HTML 标签类型
///
/// 映射 HTML 标签到语义化的 Swift 枚举。
/// 对于未知标签，保留原始 C 值供调试。
public enum XMarkupTag: Sendable {
    // 文本样式
    case bold
    case italic
    case underline
    case strikethrough
    case subscriptText
    case superscript
    case mark
    case code
    // 段落结构
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
    case blockquote
    case preformatted
    // 链接与媒体
    case link
    case image
    case video
    case videoSource
    case audio
    case audioSource
    // 列表
    case listOrdered
    case listUnordered
    case listItem
    // 表格
    case table
    case tableRow
    case tableCell
    case tableHeader
    // 其他
    case horizontalRule
    case lineBreak
    case division
    case span
    // 未知标签
    case unknown(tagValue: UInt32)

    /// 从 C API XMTagType 值初始化
    init(cValue: XMTagType)
}
```

### 3.3 XMarkupStyle

```swift
/// CSS 行内样式属性类型
public enum XMarkupStyle: Sendable {
    case foregroundColor
    case backgroundColor
    case fontSize
    case fontWeight
    case fontStyle
    case textDecoration
    case lineHeight
    case textAlign
    case letterSpacing
    case unknown(styleValue: UInt32)

    /// 从 C API XMStyleType 值初始化
    init(cValue: XMStyleType)
}
```

### 3.4 XMarkupSpan

```swift
/// 样式区间，描述一个标签或 CSS 属性在文本中的位置
///
/// `range` 使用 UTF-16 码元索引，与 NSString/NSAttributedString 索引体系直接对齐。
/// - 当 `style == .unknown(styleValue: 0)` 时：标签语义 span
/// - 当 `tag == .unknown(tagValue: 0)` 时：CSS 样式 span
public struct XMarkupSpan: Sendable {
    /// 文本区间（UTF-16 码元索引，半开区间 [start, end)）
    public let range: NSRange
    /// 标签类型
    public let tag: XMarkupTag
    /// CSS 样式类型
    public let style: XMarkupStyle
    /// 属性值（href/src/颜色值等），可能为 nil
    public let value: String?
}
```

### 3.5 XMarkupResult

```swift
/// XMarkup 解析结果
///
/// 值类型，不可变，`Sendable` 安全。
/// 包含原始解析数据（text + spans）和便利转换方法。
///
/// 使用方式：
/// ```swift
/// let result = try parser.parse("<b>Hello</b>")
/// // 原始数据层：直接访问 text 和 spans
/// print(result.text)       // "Hello"
/// print(result.spans)      // [XMarkupSpan(tag: .bold, range: (0,5))]
/// // 便利层：转换为 NSAttributedString
/// let attributed = result.makeAttributedString()
/// ```
public struct XMarkupResult: Sendable {
    /// 纯文本（HTML 标签已移除，实体已解码）
    public let text: String
    /// 样式区间数组
    public let spans: [XMarkupSpan]

    /// 从 C API XMResult 指针转换（内部方法）
    static func fromC(_ cResult: UnsafePointer<XMResult>) -> XMarkupResult

    /// 转换为 NSAttributedString（便利层，见第 5 节）
    public func makeAttributedString(baseFont: XMFont? = nil) -> NSAttributedString
}
```

---

## 4. XMarkupParser 生命周期

```swift
/// XMarkup HTML 解析器
///
/// 将 HTML 转换为纯文本 + 样式区间，供桥接层消费。
///
/// 使用方式：
/// ```swift
/// let parser = try XMarkupParser(baseFontSize: 14.5)
/// let result = try parser.parse("<b>Hello</b> <i>World</i>")
/// let attributed = result.makeAttributedString()
/// // 使用完毕后无需手动释放（deinit 自动释放 C 资源）
/// ```
///
/// - Note: 线程安全保证与 C 核心引擎一致：不同实例可跨线程并发使用，
///         同一实例不可并发调用。
public final class XMarkupParser: @unchecked Sendable {
    private let handle: OpaquePointer

    /// 当前配置的基准字号（保留 CGFloat 精度，用于 UIFont 渲染）
    public let baseFontSize: CGFloat

    /// 创建解析器
    ///
    /// - Parameters:
    ///   - baseFontSize: 基准字号（pt），用于 CSS em/rem/% 单位换算，默认 16
    ///   - maxNestingDepth: 最大嵌套深度，超出截断，默认 256
    ///   - autocorrect: 是否自动纠错乱序嵌套/未闭合标签，默认 true
    /// - Throws: 内存不足时抛出 `XMarkupError.allocationFailed`
    public init(
        baseFontSize: CGFloat = 16,
        maxNestingDepth: UInt16 = 256,
        autocorrect: Bool = true
    ) throws {
        self.baseFontSize = baseFontSize
        var config = XMConfig()
        config.enable_autocorrect = autocorrect ? 1 : 0
        config.max_nesting_depth = maxNestingDepth
        config.base_font_size = Float(baseFontSize)  // 依赖核心引擎改进 #1（uint16 → float）
        guard let ptr = xmarkup_create(&config) else {
            throw XMarkupError.allocationFailed
        }
        handle = ptr
    }

    deinit {
        xmarkup_destroy(handle)
    }

    /// 解析 HTML 字符串
    ///
    /// - Parameter html: HTML 输入（UTF-8 编码）
    /// - Returns: 解析结果，包含纯文本和样式区间
    /// - Throws: `XMarkupError` 各种解析错误
    public func parse(_ html: String) throws -> XMarkupResult {
        let cResult = html.withCString { ptr in
            xmarkup_parse(handle, ptr, html.utf8.count)
        }
        guard let cResult else {
            let error = xmarkup_last_error(handle)
            throw XMarkupError(cError: error)
        }
        defer { xmarkup_result_free(cResult) }

        let err = cResult.pointee.error
        guard err == XM_OK else {
            throw XMarkupError(cError: err)
        }

        return XMarkupResult.fromC(cResult)
    }
}
```

**设计要点：**

- `init` 抛异常而非存 nil → `handle` 用非可选类型，消除后续 nil 检查
- `parse` 内部 `defer { xmarkup_result_free }` → C 结果在转为 Swift 值类型后立即释放，无悬垂指针风险
- `html.withCString` + `html.utf8.count` → C API 需要字节长度，与 Swift String UTF-8 视图对齐
- `@unchecked Sendable` → C API 保证不同实例线程安全；同一实例不并发由调用者保证，文档注明
- RAII `deinit` → 无需手动 close/dispose

---

## 5. NSAttributedString 便利层

### 5.1 跨平台类型

```swift
#if canImport(UIKit)
import UIKit
public typealias XMFont = UIFont
public typealias XMColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias XMFont = NSFont
public typealias XMColor = NSColor
#endif
```

### 5.2 makeAttributedString 方法

```swift
extension XMarkupResult {
    /// 将解析结果转换为 NSAttributedString
    ///
    /// 使用方式：
    /// ```swift
    /// let result = try parser.parse("<b>Hello</b> <i style=\"color:#FF0000\">World</i>")
    /// let attributed = result.makeAttributedString(baseFont: UIFont.systemFont(ofSize: 14))
    /// // attributed 可直接用于 UILabel.attributedText / NSTextField.attributedStringValue
    /// ```
    ///
    /// - Parameter baseFont: 基础字体，nil 时使用 systemFont(ofSize: 16)
    /// - Returns: 带样式的 NSAttributedString
    public func makeAttributedString(baseFont: XMFont? = nil) -> NSAttributedString
}
```

### 5.3 两趟处理算法

**第一趟：合并字体属性**

字体属性不能逐个 `addAttribute`（BOLD 会覆盖 ITALIC），需逐范围合并 font traits：

```swift
// 伪代码
let str = NSMutableAttributedString(string: text, attributes: [.font: baseFont])

for span in spans {
    switch span.tag {
    case .bold:        addFontTrait(.traitBold, to: span.range, in: str)
    case .italic:      addFontTrait(.traitItalic, to: span.range, in: str)
    case .heading1:    applyFont(size: baseSize * 2.0, traits: [.traitBold], to: span.range, in: str)
    case .heading2:    applyFont(size: baseSize * 1.5, traits: [.traitBold], to: span.range, in: str)
    case .heading3:    applyFont(size: baseSize * 1.17, traits: [.traitBold], to: span.range, in: str)
    case .heading4:    applyFont(size: baseSize * 1.0, traits: [.traitBold], to: span.range, in: str)
    case .heading5:    applyFont(size: baseSize * 0.83, traits: [.traitBold], to: span.range, in: str)
    case .heading6:    applyFont(size: baseSize * 0.67, traits: [.traitBold], to: span.range, in: str)
    case .code:        applyFont(family: "Menlo", to: span.range, in: str)
    default: break
    }

    // CSS fontSize span
    if span.style == .fontSize, let pt = Float(span.value ?? "") {
        applyFont(size: CGFloat(pt), to: span.range, in: str)
    }
}
```

`addFontTrait` 内部使用 `enumerateAttribute(.font, in: range)` 读取当前字体并叠加 trait：

```swift
/// 向指定范围追加字体 trait（合并而非覆盖）
///
/// 处理 <b><i>text</i></b> 场景：先应用 BOLD trait，
/// 再在同一范围应用 ITALIC trait，最终得到 Bold-Italic 字体。
private func addFontTrait(_ trait: XMFontDescriptor.SymbolicTraits,
                          to range: NSRange,
                          in string: NSMutableAttributedString) {
    string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
        guard let font = currentFont as? XMFont else { return }
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(trait)
        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits),
           let newFont = XMFont(descriptor: descriptor, size: font.pointSize) {
            string.addAttribute(.font, value: newFont, range: attrRange)
        }
    }
}
```

**第二趟：非字体属性**

```swift
for span in spans {
    switch span.tag {
    case .underline:
        str.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue,
                         range: span.range)
    case .strikethrough:
        str.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue,
                         range: span.range)
    case .link:
        if let url = span.value {
            str.addAttribute(.link, value: url, range: span.range)
        }
    default: break
    }

    switch span.style {
    case .foregroundColor:
        if let color = parseHexColor(span.value) {
            str.addAttribute(.foregroundColor, value: color, range: span.range)
        }
    case .backgroundColor:
        if let color = parseHexColor(span.value) {
            str.addAttribute(.backgroundColor, value: color, range: span.range)
        }
    default: break
    }
}
```

### 5.4 Heading 字号比例表

遵循浏览器默认比例：

| Tag | 倍率（相对 baseFont.pointSize） | 加粗 |
|-----|------|------|
| heading1 | 2.0× | 是 |
| heading2 | 1.5× | 是 |
| heading3 | 1.17× | 是 |
| heading4 | 1.0× | 是 |
| heading5 | 0.83× | 是 |
| heading6 | 0.67× | 是 |

### 5.5 不映射的 Tag

以下 tag 不映射为 NSAttributedString attribute（无直接对应），保留在原始数据中供调用者自行处理：

- `paragraph`、`division`、`blockquote` → 段落级样式，需 NSParagraphStyle（后续扩展）
- `listOrdered`、`listUnordered`、`listItem` → 列表需自定义布局
- `table` 系列 → 需表格渲染器
- `image`、`video`、`audio`、`videoSource`、`audioSource` → 需 NSTextAttachment 或自定义处理
- `horizontalRule`、`lineBreak` → 占位字符已由核心引擎插入（改进 #2），但视觉渲染需调用者自定义

### 5.6 ColorParser

```swift
/// 解析 #RRGGBB 十六进制颜色字符串为 XMColor
///
/// - Parameter hex: 颜色字符串，格式 "#RRGGBB"
/// - Returns: XMColor，无效格式返回 nil
private func parseHexColor(_ hex: String?) -> XMColor?
```

---

## 6. 跨平台支持

### 目标平台

| 平台 | 最低版本 | 对应关系 |
|------|----------|----------|
| iOS | 15.0 | 与 macOS 12 API 同步 |
| macOS | 12.0 | Monterey |

### 编译条件

```swift
#if canImport(UIKit)
// iOS 特有代码
#elseif canImport(AppKit)
// macOS 特有代码
#endif
```

### CI 验证

```bash
# iOS 模拟器
swift build && swift test
# macOS
swift build && swift test
```

---

## 7. 跨平台注释规范

### 7.1 通用规则

| 规则 | 说明 |
|------|------|
| 注释语言 | 中文（与项目主语言一致），技术术语保留英文 |
| 函数注释必须包含 | 简述、参数、返回值、异常/错误、使用示例（公开 API） |
| 逻辑注释原则 | 解释 WHY（为什么这样做）而非 WHAT（做了什么） |
| 常量注释 | 必须注明数值来源（规范文档 URL、行业标准、算法论文） |
| 使用示例 | 所有公开 API 的生命周期函数和核心功能函数必须包含 `@code` / 代码块示例 |

### 7.2 C++ 核心引擎

| 层级 | 风格 | 覆盖要求 |
|------|------|----------|
| 公共 API（`xmarkup.h`） | Doxygen `/** */` + `@code/@endcode` | 100%——所有函数、类型、字段、枚举值 |
| 核心函数声明 | Doxygen `/** */` + `@code/@endcode` | 100%——所有公开方法 |
| 实现逻辑 | `//` 行内注释 | 状态转换、循环不变量、非直觉判断、边界条件 |

### 7.3 iOS 桥接层（Swift）

| 层级 | 风格 | 覆盖要求 |
|------|------|----------|
| 公开 API | `///` + `` ```swift ``` `` 代码示例 | 100%——所有 public 类型、方法、属性 |
| MARK 分区 | `// MARK: -` | 按职责分组 |
| 复杂逻辑 | `//` 行内注释 | 字体合并算法、颜色解析、非直觉转换 |

### 7.4 Android 桥接层（Kotlin，预设规范）

| 层级 | 风格 | 覆盖要求 |
|------|------|----------|
| 公开 API | KDoc `/** */` + `` ```kotlin ``` `` 代码示例 | 100%——所有 public class/function/property |
| 复杂逻辑 | `//` 行内注释 | span 映射、单位换算、JNI 生命周期 |

### 7.5 鸿蒙桥接层（ArkTS，预设规范）

| 层级 | 风格 | 覆盖要求 |
|------|------|----------|
| 公开 API | TSDoc `/** */` + `` ```typescript ``` `` 代码示例 | 100%——所有 export function/class/interface |
| 复杂逻辑 | `//` 行内注释 | N-API 转换、样式映射 |

### 7.6 跨平台一致性规则

| 规则 | 说明 |
|------|------|
| 跨平台映射表 | 每个桥接层的 README 中包含 span→原生类型 的映射对照表 |
| Changelog | 核心引擎变更时，三端桥接层需同步更新文档 |
| 示例对齐 | 三端的同一功能示例应覆盖相同的 HTML 输入场景 |

---

## 8. 文件清单

### 8.1 核心引擎改进文件（修改）

| 文件 | 改动类型 |
|------|----------|
| `core/include/xmarkup/xmarkup.h` | `base_font_size` uint16→float、Doxygen 注释、`xmarkup_version()` |
| `core/src/style_resolver.cpp` | 浮点换算、占位字符插入、命名常量、Doxygen 注释 |
| `core/src/style_resolver.h` | Doxygen 注释 |
| `core/src/tokenizer.cpp` | 逻辑注释 |
| `core/src/tokenizer.h` | Doxygen 注释 |
| `core/src/tree_builder.cpp` | 命名常量、逻辑注释 |
| `core/src/tree_builder.h` | Doxygen 注释 |
| `core/src/entity_decoder.cpp` | 来源注释 |
| `core/src/entity_decoder.h` | Doxygen 注释 |
| `core/src/utf16_indexer.cpp` | 逻辑注释 |
| `core/src/utf16_indexer.h` | Doxygen 注释 |
| `core/src/parser.cpp` | 适配 float config、Doxygen 注释 |
| `core/src/parser.h` | Doxygen 注释 |
| `core/src/api.cpp` | 适配 float config、`xmarkup_version()` |
| `tests/test_style_resolver.cpp` | 浮点精度测试、占位字符测试、边界用例 |
| `tests/test_api.cpp` | 浮点端到端测试、占位字符测试、多语言测试 |

### 8.2 iOS 桥接层文件（新建）

| 文件 | 职责 | 行数预估 |
|------|------|----------|
| `Package.swift` | SPM 清单 | ~40 |
| `platforms/ios/Sources/XMarkup/XMarkupError.swift` | 错误枚举 + `init(cError:)` | ~25 |
| `platforms/ios/Sources/XMarkup/XMarkupTag.swift` | 标签枚举 + `init(cValue:)` | ~60 |
| `platforms/ios/Sources/XMarkup/XMarkupStyle.swift` | CSS 样式枚举 + `init(cValue:)` | ~25 |
| `platforms/ios/Sources/XMarkup/XMarkupSpan.swift` | 样式区间结构体 + C 结构转换 | ~30 |
| `platforms/ios/Sources/XMarkup/XMarkupResult.swift` | 结果结构体 + `fromC()` 转换 | ~40 |
| `platforms/ios/Sources/XMarkup/XMarkupParser.swift` | 解析器封装，生命周期管理 | ~50 |
| `platforms/ios/Sources/XMarkup/PlatformTypes.swift` | 跨平台 XMFont/XMColor 公开 typealias | ~15 |
| `platforms/ios/Sources/XMarkup/ColorParser.swift` | `#RRGGBB` → XMColor 解析工具 | ~20 |
| `platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift` | 便利层：span→attribute 映射 | ~150 |
| `platforms/ios/Tests/XMarkupTests/XMarkupParserTests.swift` | 解析器生命周期 + parse 正确性 | ~80 |
| `platforms/ios/Tests/XMarkupTests/XMarkupResultTests.swift` | 结果转换：span 解析、range 精度 | ~60 |
| `platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift` | 便利层：字体合并、颜色映射、嵌套叠加 | ~100 |
| `platforms/ios/Tests/XMarkupTests/ColorParserTests.swift` | 十六进制颜色解析边界 | ~30 |
| `platforms/ios/Tests/XMarkupTests/CrossPlatformTests.swift` | 跨平台编译验证 | ~20 |
| `.swiftlint.yml` | SwiftLint 规则 | ~30 |
| `.swiftformat` | SwiftFormat 规则 | ~10 |

---

## 9. 测试策略

### 9.1 核心引擎补充测试

见 [1.6 补充边界/异常测试用例](#16-补充边界异常测试用例)。

### 9.2 iOS 桥接层测试

**XMarkupParserTests：**

| 用例 | 验证点 |
|------|--------|
| 创建解析器（默认配置） | 初始化成功，baseFontSize == 16 |
| 创建解析器（自定义配置） | baseFontSize 传递正确 |
| 创建解析器失败 | 内存不足抛出 allocationFailed（mock 难度大，标记为 smoke test） |
| 解析空字符串 | text 为空字符串，spans 为空 |
| 解析纯文本 | text 等于原文，spans 为空 |
| 解析简单 HTML | `<b>Hello</b>` → text "Hello"，1 个 BOLD span |
| 解析嵌套 HTML | `<b><i>Hi</i></b>` → 2 个 span，BOLD + ITALIC |
| 连续多次 parse | 前一次结果不影响后一次 |
| 错误码映射 | 各种 XMError 正确映射到 XMarkupError |

**XMarkupResultTests：**

| 用例 | 验证点 |
|------|--------|
| 纯文本无 span | text 正确，spans.count == 0 |
| BOLD span range | range.location 和 range.length 正确 |
| 嵌套 BOLD+ITALIC 顺序 | BOLD 在前，ITALIC 在后（outside-in） |
| LINK 带 href | tag == .link，value == "https://..." |
| CSS fontSize span | style == .fontSize，value == "24" |
| Emoji UTF-16 range | 😊 占 2 个 UTF-16 码元，range.length == 2 |
| 未知 tag | tag == .unknown(tagValue: N) |

**NSAttributedStringTests：**

| 用例 | 验证点 |
|------|--------|
| BOLD→font trait | font 包含 .traitBold |
| ITALIC→font trait | font 包含 .traitItalic |
| BOLD+ITALIC 合并 | font 同时包含 .traitBold + .traitItalic |
| heading1 字号 | font.pointSize ≈ baseSize × 2.0 |
| heading6 字号 | font.pointSize ≈ baseSize × 0.67 |
| CSS 前景色 | foregroundColor == UIColor(hex) |
| CSS 背景色 | backgroundColor == UIColor(hex) |
| underline | underlineStyle == .single |
| strikethrough | strikethroughStyle == .single |
| link | .link attribute == URL string |
| 未知 tag 不崩溃 | 跳过映射，text 完整 |
| 自定义 baseFont | 使用传入字体而非系统默认 |

**ColorParserTests：**

| 用例 | 验证点 |
|------|--------|
| `#FF0000` | 红色 |
| `#00FF00` | 绿色 |
| `#0000FF` | 蓝色 |
| `#000000` | 黑色 |
| 无效格式 | 返回 nil |
| nil 输入 | 返回 nil |

### 9.3 验证命令

```bash
swift build
swift test
```

---

## 10. 设计决策记录

| # | 决策 | 方案 | 理由 |
|---|------|------|------|
| 1 | 分发方式 | SPM only | 主流，CocoaPods 逐渐被取代 |
| 2 | 目标平台 | iOS 15+ / macOS 12+ | API 同步版本对，兼容性工作量最小 |
| 3 | API 层次 | 两层（原始数据 + NSAttributedString） | 原始数据支持更多定制场景（SwiftUI、自定义渲染） |
| 4 | C++ 集成方式 | SPM 源码编译 | 最简单，无需 CI 预编译步骤 |
| 5 | 枚举设计 | 纯 Swift 枚举（无 rawValue） | 更 Swift-idiomatic，`init(cValue:)` 内部转换 |
| 6 | baseFontSize 类型 | CGFloat（Swift 侧）| 对齐 UIFont.pointSize |
| 7 | 并发模型 | `@unchecked Sendable` final class | actor 对同步 C 调用引入不必要 async 开销 |
| 8 | NSRange | 直接使用 UTF-16 NSRange | C API 返回 UTF-16 索引，与 NSString 索引对齐 |
| 9 | Span 处理 | 两趟（先合并字体，再加非字体） | 避免 BOLD 覆盖 ITALIC 的 font attribute 问题 |
| 10 | 跨平台类型 | 公开 typealias XMFont/XMColor | iOS/macOS 统一 API 签名 |
