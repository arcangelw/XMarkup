# XMarkup iOS 桥接层增强设计规格

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。

**目标：** 修复 Demo 运行发现的 bug（链接颜色、mark 不可见），新增媒体渲染能力（图片/视频/音频），设计可扩展的自定义样式 API。

**架构：** 分层配置式 — 预置主题开箱即用，`XMarkupStyleConfig` 声明式微调，`spanTransformer` / `postProcessor` 闭包精细控制。媒体通过 `NSTextAttachment` 替换 `U+FFFC` 占位符实现。

**技术栈：** Swift 6 / C++17 / SPM / UIKit + AppKit 跨平台

---

## 1. Bug 修复

### 1.1 带颜色链接显示为默认蓝色

**根因：** `NSAttributedString` 中 `.link` 和 `.foregroundColor` 已正确设置，但 UITextView/NSTextView 的 `linkTextAttributes` 默认为蓝色，覆盖了自定义前景色。

**修复：**

- 桥接层 `NSAttributedString+XMarkup.swift` 逻辑本身正确，不做修改
- 新增 `XMarkup+TextView.swift`，提供跨平台便利扩展：

```swift
#if canImport(UIKit)
import UIKit
public typealias XMTextView = UITextView
#elseif canImport(AppKit)
import AppKit
public typealias XMTextView = NSTextView
#endif

extension XMTextView {
    /// 配置 TextView 以正确渲染 XMarkup 富文本
    /// 清空默认 linkTextAttributes，让 NSAttributedString 自身的前景色生效
    public func configureForXMarkup() {
        linkTextAttributes = [:]
    }
}
```

- Demo App 在设置 attributedText 之前调用 `textView.configureForXMarkup()`

### 1.2 `<mark>` 标签无视觉效果

**根因：** `applyNonFontAttributes` 中 `.mark` 落入 `default: break`，零处理。

**修复：** 在 `NSAttributedString+XMarkup.swift` 的 `applyNonFontAttributes` 中新增：

```swift
case .mark:
    string.addAttribute(.backgroundColor, value: XMColor.systemYellow.withAlphaComponent(0.3), range: range)
```

---

## 2. 自定义样式 API

### 2.1 文件结构

```
platforms/ios/Sources/XMarkup/
├── XMarkupStyleConfig.swift   ← 新增：配置类型 + 预置主题
├── XMarkup+TextView.swift     ← 新增：TextView 便利扩展
├── NSAttributedString+XMarkup.swift  ← 修改：集成 config + mark + 媒体
└── ... (其余文件不变)
```

### 2.2 类型定义

**`XMarkupTagStyle`** — 单个标签的样式配置：

```swift
public struct XMarkupTagStyle {
    public var font: XMFont?
    public var foregroundColor: XMColor?
    public var backgroundColor: XMColor?
    public var underlineStyle: NSUnderlineStyle?
    public var strikethroughStyle: NSUnderlineStyle?
}
```

**`XMarkupStyleConfig`** — 富文本渲染配置：

```swift
public struct XMarkupStyleConfig {
    // 基础字体
    public var baseFont: XMFont?  // nil 时用 systemFont(ofSize: 16)

    // 标签样式映射
    public subscript(tag: XMarkupTag) -> XMarkupTagStyle? { get set }

    // 图片加载器：(src URL) → XMImage?
    // nil 时使用 SF Symbol 占位图
    public var imageProvider: ((String) -> XMImage?)?

    // 媒体占位尺寸（默认 200×150）
    public var mediaPlaceholderSize: CGSize

    // 自定义媒体附件工厂：(tag, srcURL?) → NSTextAttachment?
    public var mediaAttachmentProvider: ((XMarkupTag, String?) -> NSTextAttachment?)?

    // 单次覆盖：per-span 精细控制
    public var spanTransformer: ((XMarkupSpan, inout [NSAttributedString.Key: Any]) -> Void)?

    // 后处理钩子：对最终结果做全局操作（如加行间距）
    public var postProcessor: ((inout NSMutableAttributedString) -> Void)?

    // 预置主题
    public static let `default`: XMarkupStyleConfig
    public static let dark: XMarkupStyleConfig
    public static let chat: XMarkupStyleConfig
    public static let article: XMarkupStyleConfig
}
```

### 2.3 预置主题定义

**`.default`**：通用
- baseFont: systemFont(ofSize: 16)
- mark: backgroundColor = systemYellow.withAlphaComponent(0.3)

**`.dark`**：暗色模式
- mark: backgroundColor = systemOrange.withAlphaComponent(0.3)
- foregroundColor = whiteColor（需要探测 light/dark 的场景由调用方决定）

**`.chat`**：聊天气泡
- baseFont: systemFont(ofSize: 14)
- link: foregroundColor = systemBlue
- mark: backgroundColor = systemYellow.withAlphaComponent(0.2)

**`.article`**：文章阅读
- baseFont: systemFont(ofSize: 17)
- heading1: font = systemFont(ofSize: 28, weight: .bold)
- heading2: font = systemFont(ofSize: 22, weight: .bold)
- heading3: font = systemFont(ofSize: 19, weight: .semibold)
- blockquote: foregroundColor = secondaryLabelColor
- code: backgroundColor = textBackgroundColor（系统自适应）
- mediaPlaceholderSize: CGSize(width: 300, height: 200)

### 2.4 API（破坏性重构）

```swift
extension XMarkupResult {
    // 唯一的渲染方法（移除旧的 makeAttributedString(baseFont:)）
    public func makeAttributedString(
        config: XMarkupStyleConfig = .default
    ) -> NSAttributedString
}
```

### 2.5 渲染流水线

```
Pass 1: HTML 字体属性（bold/italic/heading/code/fontSize）
  ↓
Pass 2: HTML 非字体属性（underline/strikethrough/link/mark/color）
  ↓
Pass 3: StyleConfig 标签覆盖（config[.link].foregroundColor 等）
  ↓
Pass 4: 媒体附件替换（.image/.video/.audio span → NSTextAttachment 替换 U+FFFC）
  ↓
Pass 5: spanTransformer（单次精细控制）
  ↓
Pass 6: postProcessor（全局后处理）
  ↓
返回不可变 NSAttributedString
```

### 2.6 跨平台扩展性考量

当前仅在 iOS 桥接层实现，但 API 设计考虑 Android/HarmonyOS 扩展：

- `XMarkupStyleConfig` 是纯值类型，概念上可映射到 Kotlin data class / ArkTS interface
- `spanTransformer` 闭包模式可替换为协议/接口
- `imageProvider` / `mediaAttachmentProvider` 是平台相关的，由各端自行定义
- 渲染流水线顺序是固定的，各端实现顺序一致即可保证行为一致

---

## 3. 媒体渲染

### 3.1 核心引擎修复

`core/src/style_resolver.cpp` 中补上 `XM_TAG_VIDEO` 和 `XM_TAG_AUDIO` 的 src 属性提取。

当前代码（第 127-133 行）仅处理 link、image、videoSource、audioSource：

```cpp
// 修复前
if (tag_type == XM_TAG_LINK) {
    extract_attribute_value(node.attributes, "href", span.value);
} else if (tag_type == XM_TAG_IMAGE) {
    extract_attribute_value(node.attributes, "src", span.value);
} else if (tag_type == XM_TAG_VIDEO_SOURCE || tag_type == XM_TAG_AUDIO_SOURCE) {
    extract_attribute_value(node.attributes, "src", span.value);
}
```

修复后：

```cpp
if (tag_type == XM_TAG_LINK) {
    extract_attribute_value(node.attributes, "href", span.value);
} else if (tag_type == XM_TAG_IMAGE) {
    extract_attribute_value(node.attributes, "src", span.value);
} else if (tag_type == XM_TAG_VIDEO || tag_type == XM_TAG_AUDIO) {
    extract_attribute_value(node.attributes, "src", span.value);
} else if (tag_type == XM_TAG_VIDEO_SOURCE || tag_type == XM_TAG_AUDIO_SOURCE) {
    extract_attribute_value(node.attributes, "src", span.value);
}
```

### 3.2 占位符机制

核心引擎已为 img/video/audio/hr 插入 `U+FFFC`（OBJECT REPLACEMENT CHARACTER）作为占位符。桥接层通过扫描媒体 span 找到对应的 U+FFFC，替换为 `NSTextAttachment`。

### 3.3 默认占位图

无自定义 provider 时，使用 SF Symbol 生成占位图：

| 标签 | SF Symbol | 描述 |
|---|---|---|
| `.image` | `photo` | 照片图标 + 浅灰背景 |
| `.video` | `play.rectangle` | 播放图标 + 浅灰背景 |
| `.audio` | `waveform` | 波形图标 + 浅灰背景 |

占位图尺寸由 `config.mediaPlaceholderSize` 控制。

### 3.4 替换算法

从后向前遍历媒体 span（避免替换导致的 range 偏移）：

1. 筛选 `.image` / `.video` / `.audio` 类型的 span
2. 按 range.location 降序排列
3. 对每个 span，检查其 range 内是否包含 U+FFFC
4. 创建 NSTextAttachment → 用 `replaceCharacters(in:with:)` 替换

对于 `<video><source>` 结构：video span 包含 U+FFFC，videoSource span 的 value 是 src URL。桥接层需要查找 videoSource 子 span 的 value 作为 video 的 src。

---

## 4. Demo 示例增强

在现有 16 个示例基础上新增 7 个，覆盖实际场景：

| ID | 标题 | 覆盖内容 |
|---|---|---|
| `article` | 长文章阅读 | 多段落、H1-H4、引用块、有序/无序列表 |
| `chat-msg` | 聊天消息 | @提及（link）、紧凑排版、emoji、图片混排 |
| `notification` | 系统通知 | 标题 + 富文本正文 + 操作链接 |
| `api-doc` | 代码文档 | 标题、代码块、行内代码、参数说明、列表 |
| `social-post` | 社交动态 | #话题标签、@用户（link）、图片混排 |
| `product-detail` | 商品详情 | 价格组合样式、规格表、促销标签、图片 |
| `media-mix` | 图文音视频混排 | `<img>` + `<video>` + `<audio>` + 文字组合 |

每个示例的 HTML 长度应 > 200 字符，模拟真实内容。

---

## 5. 变更影响矩阵

| 文件 | 变更类型 | 说明 |
|---|---|---|
| `core/src/style_resolver.cpp` | 修改 | 补上 video/audio 的 src 提取 |
| `core/test/test_style_resolver.cpp` | 修改 | 新增 video/audio src 提取测试 |
| `platforms/ios/Sources/XMarkup/XMarkupStyleConfig.swift` | 新增 | 配置类型 + 预置主题 |
| `platforms/ios/Sources/XMarkup/XMarkup+TextView.swift` | 新增 | TextView 便利扩展 |
| `platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift` | 重构 | 集成 config、mark、媒体附件、流水线 |
| `platforms/ios/Tests/XMarkupTests/` | 修改 | 新增 config/mark/media 测试 |
| `playground/ios/XMarkupDemo/.../Shared/DemoExamples.swift` | 修改 | 新增 7 个复杂示例 |
| `playground/ios/XMarkupDemo/.../SwiftUI/RenderedTextView.swift` | 修改 | 调用 configureForXMarkup() |
| `playground/ios/XMarkupDemo/.../UIKit/RenderedTextVC.swift` | 修改 | 调用 configureForXMarkup() |
