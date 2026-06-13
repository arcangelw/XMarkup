# XMarkup iOS 桥接层增强 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 Demo 运行发现的 bug（链接颜色、mark 不可见），新增媒体渲染能力（图片/视频/音频），设计可扩展的自定义样式 API（XMarkupStyleConfig + 4 预置主题）。

**架构：** 分层配置式 — 预置主题开箱即用，`XMarkupStyleConfig` 声明式微调，`spanTransformer` / `postProcessor` 闭包精细控制。6 阶渲染流水线。媒体通过 `NSTextAttachment` 替换 `U+FFFC` 占位符实现。

**技术栈：** Swift 6 / C++17 / SPM / UIKit + AppKit 跨平台

**规格文件：** `docs/superpowers/specs/2026-06-08-xmarkup-bridge-enhancement-design.md`

---

## 文件结构

| 文件 | 状态 | 职责 |
|---|---|---|
| `core/src/style_resolver.cpp` | 修改 | 补上 video/audio src 属性提取 |
| `tests/test_style_resolver.cpp` | 修改 | 新增 video/audio src 提取测试 |
| `platforms/ios/Sources/XMarkup/XMarkupTag.swift` | 修改 | 添加 `Hashable` 一致性（字典 key） |
| `platforms/ios/Sources/XMarkup/XMarkupStyleConfig.swift` | 新增 | `XMarkupTagStyle` + `XMarkupStyleConfig` + 4 预置主题 |
| `platforms/ios/Sources/XMarkup/XMarkup+TextView.swift` | 新增 | UITextView/NSTextView 便利扩展 |
| `platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift` | 重构 | 集成 config、mark、媒体附件、6 阶流水线 |
| `platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift` | 修改 | 更新旧 API 调用 + 新增 mark/config/media 测试 |
| `platforms/ios/Tests/XMarkupTests/StyleConfigTests.swift` | 新增 | XMarkupStyleConfig 单元测试 |
| `playground/ios/XMarkupDemo/.../Shared/DemoExamples.swift` | 修改 | 新增 7 个复杂场景示例 + 新分类 |
| `playground/ios/XMarkupDemo/.../SwiftUI/RenderedTextView.swift` | 修改 | 调用 `configureForXMarkup()` |
| `playground/ios/XMarkupDemo/.../UIKit/RenderedTextViewController.swift` | 修改 | 调用 `configureForXMarkup()` |

---

## 构建与测试命令

```bash
# C++ 核心引擎测试（从项目根目录）
cmake -B build -DCMAKE_BUILD_TYPE=Debug 2>&1 | tail -3
cmake --build build 2>&1 | tail -5
(cd build && ctest --output-on-failure 2>&1 | tail -20)

# Swift 桥接层测试（从项目根目录）
swift test 2>&1 | tail -20

# Demo App 构建（SwiftUI target）
cd playground/ios/XMarkupDemo && xcodegen generate 2>&1
xcodebuild build -project XMarkupDemo.xcodeproj \
  -scheme XMarkupDemoSwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet 2>&1 | tail -5
```

---

## 任务 1：核心引擎 — video/audio src 属性提取

**文件：**
- 修改：`core/src/style_resolver.cpp:127-133`
- 修改：`tests/test_style_resolver.cpp`

- [ ] **步骤 1：编写失败的测试**

在 `tests/test_style_resolver.cpp` 末尾追加：

```cpp
TEST_F(StyleResolverTest, VideoTagWithDirectSrc) {
    auto r = resolve("<video src=\"movie.mp4\"></video>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_VIDEO) {
            found = true;
            EXPECT_EQ(s.value, "movie.mp4");
            EXPECT_GT(s.byte_end, s.byte_start);
        }
    }
    EXPECT_TRUE(found);
    EXPECT_NE(r.text.find("\xEF\xBF\xBC"), std::string::npos);
}

TEST_F(StyleResolverTest, AudioTagWithDirectSrc) {
    auto r = resolve("<audio src=\"song.mp3\"></audio>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_AUDIO) {
            found = true;
            EXPECT_EQ(s.value, "song.mp3");
            EXPECT_GT(s.byte_end, s.byte_start);
        }
    }
    EXPECT_TRUE(found);
    EXPECT_NE(r.text.find("\xEF\xBF\xBC"), std::string::npos);
}

TEST_F(StyleResolverTest, VideoTagWithSourceChildSrcFallback) {
    // video 没有 src，靠 <source> 子标签
    auto r = resolve("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>");
    bool found_video = false, found_source = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_VIDEO) {
            found_video = true;
            // video 自身无 src，value 应为空
            EXPECT_TRUE(s.value.empty());
        }
        if (s.tag == XM_TAG_VIDEO_SOURCE) {
            found_source = true;
            EXPECT_EQ(s.value, "a.mp4");
        }
    }
    EXPECT_TRUE(found_video);
    EXPECT_TRUE(found_source);
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cmake --build build 2>&1 | tail -3
(cd build && ctest --output-on-failure -R VideoTagWithDirectSrc 2>&1)
(cd build && ctest --output-on-failure -R AudioTagWithDirectSrc 2>&1)
```

预期：`VideoTagWithDirectSrc` 和 `AudioTagWithDirectSrc` FAIL（value 为空字符串，不等于预期 URL）

- [ ] **步骤 3：修改 style_resolver.cpp**

在 `core/src/style_resolver.cpp` 第 127-133 行，将：

```cpp
if (tag_type == XM_TAG_LINK) {
    extract_attribute_value(node.attributes, "href", span.value);
} else if (tag_type == XM_TAG_IMAGE) {
    extract_attribute_value(node.attributes, "src", span.value);
} else if (tag_type == XM_TAG_VIDEO_SOURCE || tag_type == XM_TAG_AUDIO_SOURCE) {
    extract_attribute_value(node.attributes, "src", span.value);
}
```

改为：

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

- [ ] **步骤 4：运行全部 C++ 测试验证通过**

```bash
cmake --build build 2>&1 | tail -3
(cd build && ctest --output-on-failure 2>&1 | tail -20)
```

预期：全部 PASS（原有 ~30 个 + 新增 3 个）

- [ ] **步骤 5：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): 补上 video/audio 标签的 src 属性提取

- style_resolver 中 XM_TAG_VIDEO/XM_TAG_AUDIO 缺少 src 提取分支
- 新增 3 个测试：video 直接 src、audio 直接 src、video+source 子标签"
```

---

## 任务 2：TextView 便利扩展（链接颜色修复）

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/XMarkup+TextView.swift`

- [ ] **步骤 1：创建文件**

创建 `platforms/ios/Sources/XMarkup/XMarkup+TextView.swift`：

```swift
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// UITextView / NSTextView 便利扩展
///
/// 提供 XMarkup 富文本渲染所需的 TextView 配置。
#if canImport(UIKit)
public typealias XMTextView = UITextView
#elseif canImport(AppKit)
public typealias XMTextView = NSTextView
#endif

extension XMTextView {
    /// 配置 TextView 以正确渲染 XMarkup 富文本
    ///
    /// 清空默认的 `linkTextAttributes`，让 NSAttributedString 自身的
    /// `.foregroundColor` 生效，避免链接文字被系统蓝色覆盖。
    ///
    /// 在设置 `attributedText` **之前**调用：
    /// ```swift
    /// textView.configureForXMarkup()
    /// textView.attributedText = result.makeAttributedString()
    /// ```
    public func configureForXMarkup() {
        linkTextAttributes = [:]
    }
}
```

- [ ] **步骤 2：编译验证**

```bash
swift build 2>&1 | tail -10
```

预期：BUILD SUCCEEDED

- [ ] **步骤 3：Commit**

```bash
git add platforms/ios/Sources/XMarkup/XMarkup+TextView.swift
git commit -m "feat(ios): 新增 XMTextView.configureForXMarkup() 扩展

清空 linkTextAttributes 让自定义链接颜色生效，修复 Demo 中橙色链接显示为蓝色的问题"
```

---

## 任务 3：自定义样式配置类型

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/XMarkupTag.swift`（添加 `Hashable`）
- 创建：`platforms/ios/Sources/XMarkup/XMarkupStyleConfig.swift`

- [ ] **步骤 1：XMarkupTag 添加 Hashable**

在 `platforms/ios/Sources/XMarkup/XMarkupTag.swift` 第 7 行，将：

```swift
public enum XMarkupTag: Sendable, Equatable {
```

改为：

```swift
public enum XMarkupTag: Sendable, Equatable, Hashable {
```

- [ ] **步骤 2：编译验证 Hashable**

```bash
swift build 2>&1 | tail -5
```

预期：BUILD SUCCEEDED

- [ ] **步骤 3：创建 XMarkupStyleConfig.swift**

创建 `platforms/ios/Sources/XMarkup/XMarkupStyleConfig.swift`：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 单个 HTML 标签的样式覆盖
///
/// 设置非 nil 的属性将覆盖 HTML 解析得出的默认值。
/// 所有属性均为可选，nil 表示不覆盖。
public struct XMarkupTagStyle {
    public var font: XMFont?
    public var foregroundColor: XMColor?
    public var backgroundColor: XMColor?
    public var underlineStyle: NSUnderlineStyle?
    public var strikethroughStyle: NSUnderlineStyle?

    public init(
        font: XMFont? = nil,
        foregroundColor: XMColor? = nil,
        backgroundColor: XMColor? = nil,
        underlineStyle: NSUnderlineStyle? = nil,
        strikethroughStyle: NSUnderlineStyle? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.underlineStyle = underlineStyle
        self.strikethroughStyle = strikethroughStyle
    }
}

/// 富文本渲染配置
///
/// 控制解析结果到 NSAttributedString 的转换行为。
/// 支持预置主题、声明式微调、闭包精细控制三个层级。
///
/// ```swift
/// // 使用预置主题
/// let attr = result.makeAttributedString(config: .article)
///
/// // 声明式微调
/// var config = XMarkupStyleConfig.default
/// config[.link] = XMarkupTagStyle(foregroundColor: .systemRed)
/// let attr = result.makeAttributedString(config: config)
///
/// // spanTransformer 闭包精细控制
/// config.spanTransformer = { span, attrs in
///     if span.tag == .link { attrs[.underlineStyle] = 0 }
/// }
/// ```
public struct XMarkupStyleConfig {

    // MARK: - 基础配置

    /// 基础字体，nil 时使用 systemFont(ofSize: 16)
    public var baseFont: XMFont?

    /// 媒体占位图尺寸（默认 200×150）
    public var mediaPlaceholderSize: CGSize

    // MARK: - 闭包钩子

    /// 图片加载器：(src URL) → XMImage?
    /// nil 时使用 SF Symbol 占位图
    public var imageProvider: ((String) -> XMImage?)?

    /// 自定义媒体附件工厂：(tag, srcURL?) → NSTextAttachment?
    /// 非 nil 时替代默认占位图逻辑
    public var mediaAttachmentProvider: ((XMarkupTag, String?) -> NSTextAttachment?)?

    /// 单次覆盖：per-span 精细控制
    /// 在渲染流水线 Pass 5 调用，可修改任意 attribute
    public var spanTransformer: ((XMarkupSpan, inout [NSAttributedString.Key: Any]) -> Void)?

    /// 后处理钩子：对最终结果做全局操作（如加行间距）
    /// 在渲染流水线 Pass 6 调用
    public var postProcessor: ((inout NSMutableAttributedString) -> Void)?

    // MARK: - 标签样式映射

    private var tagStyles: [XMarkupTag: XMarkupTagStyle]

    /// 按标签读取/设置样式覆盖
    public subscript(tag: XMarkupTag) -> XMarkupTagStyle? {
        get { tagStyles[tag] }
        set { tagStyles[tag] = newValue }
    }

    // MARK: - 初始化

    public init(
        baseFont: XMFont? = nil,
        mediaPlaceholderSize: CGSize = CGSize(width: 200, height: 150),
        imageProvider: ((String) -> XMImage?)? = nil,
        mediaAttachmentProvider: ((XMarkupTag, String?) -> NSTextAttachment?)? = nil,
        spanTransformer: ((XMarkupSpan, inout [NSAttributedString.Key: Any]) -> Void)? = nil,
        postProcessor: ((inout NSMutableAttributedString) -> Void)? = nil
    ) {
        self.baseFont = baseFont
        self.mediaPlaceholderSize = mediaPlaceholderSize
        self.imageProvider = imageProvider
        self.mediaAttachmentProvider = mediaAttachmentProvider
        self.spanTransformer = spanTransformer
        self.postProcessor = postProcessor
        self.tagStyles = [:]
    }

    // MARK: - 预置主题

    /// 通用主题
    public static let `default`: XMarkupStyleConfig = {
        var config = XMarkupStyleConfig()
        config[.mark] = XMarkupTagStyle(
            backgroundColor: XMColor.systemYellow.withAlphaComponent(0.3)
        )
        return config
    }()

    /// 暗色模式主题
    public static let dark: XMarkupStyleConfig = {
        var config = XMarkupStyleConfig()
        config[.mark] = XMarkupTagStyle(
            backgroundColor: XMColor.systemOrange.withAlphaComponent(0.3)
        )
        return config
    }()

    /// 聊天气泡主题
    public static let chat: XMarkupStyleConfig = {
        var config = XMarkupStyleConfig(
            baseFont: XMFont.systemFont(ofSize: 14),
            mediaPlaceholderSize: CGSize(width: 150, height: 100)
        )
        config[.link] = XMarkupTagStyle(foregroundColor: XMColor.systemBlue)
        config[.mark] = XMarkupTagStyle(
            backgroundColor: XMColor.systemYellow.withAlphaComponent(0.2)
        )
        return config
    }()

    /// 文章阅读主题
    public static let article: XMarkupStyleConfig = {
        var config = XMarkupStyleConfig(
            baseFont: XMFont.systemFont(ofSize: 17),
            mediaPlaceholderSize: CGSize(width: 300, height: 200)
        )
        config[.heading1] = XMarkupTagStyle(
            font: XMFont.systemFont(ofSize: 28, weight: .bold)
        )
        config[.heading2] = XMarkupTagStyle(
            font: XMFont.systemFont(ofSize: 22, weight: .bold)
        )
        config[.heading3] = XMarkupTagStyle(
            font: XMFont.systemFont(ofSize: 19, weight: .semibold)
        )
        #if canImport(UIKit)
        config[.blockquote] = XMarkupTagStyle(foregroundColor: .secondaryLabel)
        config[.code] = XMarkupTagStyle(backgroundColor: .systemGray6)
        #elseif canImport(AppKit)
        config[.blockquote] = XMarkupTagStyle(foregroundColor: .secondaryLabelColor)
        config[.code] = XMarkupTagStyle(backgroundColor: .textBackgroundColor)
        #endif
        return config
    }()
}
```

- [ ] **步骤 4：编译验证**

```bash
swift build 2>&1 | tail -10
```

预期：BUILD SUCCEEDED

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/XMarkupTag.swift \
       platforms/ios/Sources/XMarkup/XMarkupStyleConfig.swift
git commit -m "feat(ios): 新增 XMarkupStyleConfig 自定义样式配置

- XMarkupTagStyle：单标签样式覆盖（font/color/bg/underline/strikethrough）
- XMarkupStyleConfig：渲染配置（baseFont + tagStyles + 闭包钩子）
- 4 个预置主题：.default / .dark / .chat / .article
- XMarkupTag 添加 Hashable 以支持 Dictionary key"
```

---

## 任务 4：重构渲染管线（破坏性 API 变更 + mark + 媒体）

**文件：**
- 重构：`platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift`

**目标：**
1. 将 `makeAttributedString(baseFont:)` 替换为 `makeAttributedString(config:)`
2. `.mark` 标签添加背景色
3. 实现 6 阶渲染流水线（HTML 字体 → HTML 非字体 → config 覆盖 → 媒体 → spanTransformer → postProcessor）
4. 媒体附件：扫描 .image/.video/.audio span，用 NSTextAttachment 替换 U+FFFC

- [ ] **步骤 1：替换整个 NSAttributedString+XMarkup.swift**

将 `platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift` 全部内容替换为：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// NSAttributedString 便利层：6 阶渲染流水线
extension XMarkupResult {

    /// 将解析结果转换为 NSAttributedString
    ///
    /// 使用方式：
    /// ```swift
    /// let result = try parser.parse("<b>Hello</b> <i>World</i>")
    /// let attributed = result.makeAttributedString()
    /// // 或使用预置主题
    /// let article = result.makeAttributedString(config: .article)
    /// ```
    ///
    /// - Parameter config: 渲染配置，默认 `.default`
    /// - Returns: 带样式的 NSAttributedString
    public func makeAttributedString(config: XMarkupStyleConfig = .default) -> NSAttributedString {
        let base = config.baseFont ?? XMFont.systemFont(ofSize: 16)

        guard !text.isEmpty else {
            return NSAttributedString(string: "")
        }

        let str = NSMutableAttributedString(string: text, attributes: [.font: base])

        // Pass 1: HTML 字体属性（bold/italic/heading/code/fontSize）
        for span in spans {
            applyFontAttributes(span, baseFontSize: base.pointSize, config: config, to: str)
        }

        // Pass 2: HTML 非字体属性（underline/strikethrough/link/mark/color）
        for span in spans {
            applyNonFontAttributes(span, to: str)
        }

        // Pass 3: StyleConfig 标签覆盖
        applyConfigOverrides(config, to: str)

        // Pass 4: 媒体附件替换（image/video/audio → NSTextAttachment）
        applyMediaAttachments(config: config, to: str)

        // Pass 5: spanTransformer（单次精细控制）
        if let transformer = config.spanTransformer {
            for span in spans {
                var attrs: [NSAttributedString.Key: Any] = [:]
                transformer(span, &attrs)
                if !attrs.isEmpty {
                    str.addAttributes(attrs, range: span.range)
                }
            }
        }

        // Pass 6: postProcessor（全局后处理）
        if let processor = config.postProcessor {
            processor(&str)
        }

        return NSAttributedString(attributedString: str)
    }

    // MARK: - Pass 1: HTML 字体属性

    private func applyFontAttributes(
        _ span: XMarkupSpan,
        baseFontSize: CGFloat,
        config: XMarkupStyleConfig,
        to string: NSMutableAttributedString
    ) {
        let range = span.range

        switch span.tag {
        case .bold:
            addFontTrait(boldTrait, to: range, in: string)
        case .italic:
            addFontTrait(italicTrait, to: range, in: string)
        case .heading1:
            applyHeadingFont(scale: 2.0, to: range, in: string)
        case .heading2:
            applyHeadingFont(scale: 1.5, to: range, in: string)
        case .heading3:
            applyHeadingFont(scale: 1.17, to: range, in: string)
        case .heading4:
            applyHeadingFont(scale: 1.0, to: range, in: string)
        case .heading5:
            applyHeadingFont(scale: 0.83, to: range, in: string)
        case .heading6:
            applyHeadingFont(scale: 0.67, to: range, in: string)
        case .code:
            applyCodeFont(to: range, in: string)
        default:
            break
        }

        // CSS fontSize
        if span.style == .fontSize, let value = span.value, let size = Float(value) {
            applyFontSize(CGFloat(size), to: range, in: string)
        }
    }

    // MARK: - Pass 2: HTML 非字体属性

    private func applyNonFontAttributes(_ span: XMarkupSpan, to string: NSMutableAttributedString) {
        let range = span.range

        switch span.tag {
        case .underline:
            string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .strikethrough:
            string.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .link:
            if let url = span.value {
                string.addAttribute(.link, value: url, range: range)
            }
        case .mark:
            string.addAttribute(
                .backgroundColor,
                value: XMColor.systemYellow.withAlphaComponent(0.3),
                range: range
            )
        default:
            break
        }

        switch span.style {
        case .foregroundColor:
            if let color = ColorParser.parse(span.value) {
                string.addAttribute(.foregroundColor, value: color, range: range)
            }
        case .backgroundColor:
            if let color = ColorParser.parse(span.value) {
                string.addAttribute(.backgroundColor, value: color, range: range)
            }
        default:
            break
        }
    }

    // MARK: - Pass 3: StyleConfig 标签覆盖

    private func applyConfigOverrides(
        _ config: XMarkupStyleConfig,
        to string: NSMutableAttributedString
    ) {
        for span in spans {
            guard let style = config[span.tag] else { continue }
            let range = span.range

            if let font = style.font {
                string.enumerateAttribute(.font, in: range) { _, attrRange, _ in
                    #if canImport(UIKit)
                    string.addAttribute(.font, value: font, range: attrRange)
                    #elseif canImport(AppKit)
                    string.addAttribute(.font, value: font, range: attrRange)
                    #endif
                }
            }
            if let fg = style.foregroundColor {
                string.addAttribute(.foregroundColor, value: fg, range: range)
            }
            if let bg = style.backgroundColor {
                string.addAttribute(.backgroundColor, value: bg, range: range)
            }
            if let underline = style.underlineStyle {
                string.addAttribute(.underlineStyle, value: underline.rawValue, range: range)
            }
            if let strike = style.strikethroughStyle {
                string.addAttribute(.strikethroughStyle, value: strike.rawValue, range: range)
            }
        }
    }

    // MARK: - Pass 4: 媒体附件

    private func applyMediaAttachments(
        config: XMarkupStyleConfig,
        to string: NSMutableAttributedString
    ) {
        let mediaTags: Set<XMarkupTag> = [.image, .video, .audio]
        let mediaSpans = spans.filter { mediaTags.contains($0.tag) }

        // 从后向前遍历，避免 range 偏移
        let sortedSpans = mediaSpans.sorted { $0.range.location > $1.range.location }

        let nsString = string.string as NSString
        let fffc: Character = "\u{FFFC}"

        for span in sortedSpans {
            let spanRange = span.range

            // 在 span 范围内搜索 U+FFFC
            let searchResult = nsString.range(of: "\u{FFFC}", options: [], range: spanRange)
            guard searchResult.location != NSNotFound else { continue }

            // 确定媒体 src
            let src = resolveMediaSrc(span, allSpans: spans)

            // 创建附件
            let attachment: NSTextAttachment
            if let customProvider = config.mediaAttachmentProvider {
                guard let custom = customProvider(span.tag, src) else { continue }
                attachment = custom
            } else {
                attachment = createDefaultAttachment(
                    tag: span.tag,
                    src: src,
                    config: config
                )
            }

            let attrStr = NSAttributedString(attachment: attachment)
            string.replaceCharacters(in: searchResult, with: attrStr)
        }
    }

    /// 解析媒体 src：优先取自身 value，否则查找子 source span
    private func resolveMediaSrc(_ span: XMarkupSpan, allSpans: [XMarkupSpan]) -> String? {
        if let src = span.value, !src.isEmpty { return src }

        // video/audio 无直接 src 时，查找嵌套的 source span
        let childTag: XMarkupTag
        switch span.tag {
        case .video: childTag = .videoSource
        case .audio: childTag = .audioSource
        default: return nil
        }

        for child in allSpans {
            if child.tag == childTag,
               child.range.location >= span.range.location,
               child.range.location + child.range.length <= span.range.location + span.range.length,
               let src = child.value {
                return src
            }
        }
        return nil
    }

    /// 创建默认 SF Symbol 占位附件
    private func createDefaultAttachment(
        tag: XMarkupTag,
        src: String?,
        config: XMarkupStyleConfig
    ) -> NSTextAttachment {
        // 尝试自定义图片加载
        if let src = src, let provider = config.imageProvider, let image = provider(src) {
            let attachment = NSTextAttachment()
            attachment.image = image
            let aspectRatio = image.size.height / max(image.size.width, 1)
            let displayWidth = config.mediaPlaceholderSize.width
            let displaySize = CGSize(width: displayWidth, height: displayWidth * aspectRatio)
            attachment.bounds = CGRect(origin: .zero, size: displaySize)
            return attachment
        }

        // SF Symbol 占位图
        let symbolName: String
        switch tag {
        case .image: symbolName = "photo"
        case .video: symbolName = "play.rectangle"
        case .audio: symbolName = "waveform"
        default: symbolName = "square"
        }

        let size = config.mediaPlaceholderSize
        let image = createPlaceholderImage(systemName: symbolName, size: size)

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)
        return attachment
    }

    #if canImport(UIKit)
    private func createPlaceholderImage(systemName: String, size: CGSize) -> XMImage {
        let config = UIImage.SymbolConfiguration(
            pointSize: min(size.width, size.height) * 0.3
        )
        let symbol = UIImage(systemSymbolName: systemName, withConfiguration: config)
            ?? UIImage()
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemGray.withAlphaComponent(0.1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let symbolSize = symbol.size
            symbol.draw(at: CGPoint(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2
            ))
        }
    }
    #elseif canImport(AppKit)
    private func createPlaceholderImage(systemName: String, size: CGSize) -> XMImage {
        let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
            ?? NSImage(size: size)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemGray.withAlphaComponent(0.1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let symbolSize = symbol.size
        let x = (size.width - symbolSize.width) / 2
        let y = (size.height - symbolSize.height) / 2
        symbol.draw(
            at: NSPoint(x: x, y: y),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        image.unlockFocus()
        return image
    }
    #endif

    // MARK: - 字体辅助方法

    private func addFontTrait(
        _ trait: XMFontDescriptor.SymbolicTraits,
        to range: NSRange,
        in string: NSMutableAttributedString
    ) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            #if canImport(UIKit)
                guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return }
                let newFont = XMFont(descriptor: descriptor, size: font.pointSize)
            #elseif canImport(AppKit)
                let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                guard let newFont = XMFont(descriptor: descriptor, size: font.pointSize) else { return }
            #endif
            string.addAttribute(.font, value: newFont, range: attrRange)
        }
    }

    private func applyHeadingFont(
        scale: CGFloat,
        to range: NSRange,
        in string: NSMutableAttributedString
    ) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            let newSize = font.pointSize * scale
            #if canImport(UIKit)
                guard let desc = font.fontDescriptor.withSymbolicTraits(boldTrait) else { return }
                let newFont = XMFont(descriptor: desc, size: newSize)
            #elseif canImport(AppKit)
                let desc = font.fontDescriptor.withSymbolicTraits(boldTrait)
                guard let newFont = XMFont(descriptor: desc, size: newSize) else { return }
            #endif
            string.addAttribute(.font, value: newFont, range: attrRange)
        }
    }

    private func applyCodeFont(to range: NSRange, in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            #if canImport(UIKit)
                let monoFont = UIFont(name: "Menlo", size: font.pointSize)
                    ?? UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            #elseif canImport(AppKit)
                let monoFont = NSFont(name: "Menlo", size: font.pointSize)
                    ?? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            #endif
            string.addAttribute(.font, value: monoFont, range: attrRange)
        }
    }

    private func applyFontSize(
        _ size: CGFloat,
        to range: NSRange,
        in string: NSMutableAttributedString
    ) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            let descriptor = font.fontDescriptor
            #if canImport(UIKit)
                let newFont = XMFont(descriptor: descriptor, size: size)
                string.addAttribute(.font, value: newFont, range: attrRange)
            #elseif canImport(AppKit)
                if let newFont = XMFont(descriptor: descriptor, size: size) {
                    string.addAttribute(.font, value: newFont, range: attrRange)
                }
            #endif
        }
    }
}

// MARK: - 跨平台字体 Trait 常量

#if canImport(UIKit)
    private let boldTrait: UIFontDescriptor.SymbolicTraits = .traitBold
    private let italicTrait: UIFontDescriptor.SymbolicTraits = .traitItalic
#elseif canImport(AppKit)
    private let boldTrait: NSFontDescriptor.SymbolicTraits = .bold
    private let italicTrait: NSFontDescriptor.SymbolicTraits = .italic
#endif
```

- [ ] **步骤 2：编译验证**

```bash
swift build 2>&1 | tail -10
```

预期：BUILD SUCCEEDED。注意旧的 `makeAttributedString(baseFont:)` 已被移除。

- [ ] **步骤 3：运行现有测试（预期有 1 个失败）**

```bash
swift test 2>&1 | tail -30
```

预期：`testCustomBaseFont` FAIL（调用了已移除的 `makeAttributedString(baseFont:)` API），其余 PASS。

- [ ] **步骤 4：更新失败测试**

在 `platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift` 中，将 `testCustomBaseFont` 方法替换为：

```swift
func testCustomBaseFontViaConfig() throws {
    let result = try parse("<b>text</b>")
    #if canImport(UIKit)
        let customFont = UIFont.systemFont(ofSize: 20)
    #elseif canImport(AppKit)
        let customFont = NSFont.systemFont(ofSize: 20)
    #endif
    var config = XMarkupStyleConfig()
    config.baseFont = customFont
    let attr = result.makeAttributedString(config: config)
    let font = attr.attribute(.font, at: 0, effectiveRange: nil) as? XMFont
    XCTAssertEqual(font?.pointSize, 20)
}
```

- [ ] **步骤 5：运行全部 Swift 测试**

```bash
swift test 2>&1 | tail -20
```

预期：全部 PASS

- [ ] **步骤 6：Commit**

```bash
git add platforms/ios/Sources/XMarkup/NSAttributedString+XMarkup.swift \
       platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift
git commit -m "refactor(ios): 破坏性重构渲染管线为 6 阶流水线

- 移除 makeAttributedString(baseFont:)，新增 makeAttributedString(config:)
- Pass 2 新增 .mark 标签背景色（systemYellow 0.3 alpha）
- Pass 3: StyleConfig 标签样式覆盖
- Pass 4: 媒体附件（NSTextAttachment 替换 U+FFFC）
- Pass 5: spanTransformer 闭包
- Pass 6: postProcessor 闭包
- 更新 testCustomBaseFont 为新 config API"
```

---

## 任务 5：新增 Swift 单元测试

**文件：**
- 修改：`platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/StyleConfigTests.swift`

- [ ] **步骤 1：在 NSAttributedStringTests.swift 末尾追加 mark 测试**

```swift
func testMarkBackgroundColor() throws {
    let result = try parse("<mark>highlighted</mark>")
    let attr = result.makeAttributedString()
    let bg = attr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
    XCTAssertNotNil(bg)
}

func testMarkWithConfigOverride() throws {
    let result = try parse("<mark>highlighted</mark>")
    var config = XMarkupStyleConfig.default
    config[.mark] = XMarkupTagStyle(backgroundColor: XMColor.systemRed.withAlphaComponent(0.5))
    let attr = result.makeAttributedString(config: config)
    let bg = attr.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? XMColor
    XCTAssertNotNil(bg)
}
```

- [ ] **步骤 2：创建 StyleConfigTests.swift**

创建 `platforms/ios/Tests/XMarkupTests/StyleConfigTests.swift`：

```swift
import XCTest
@testable import XMarkup

final class StyleConfigTests: XCTestCase {
    private func parse(_ html: String) throws -> XMarkupResult {
        let parser = try XMarkupParser()
        return try parser.parse(html)
    }

    // MARK: - 预置主题

    func testDefaultThemeMarkStyle() {
        let config = XMarkupStyleConfig.default
        XCTAssertNotNil(config[.mark])
        XCTAssertNotNil(config[.mark]?.backgroundColor)
        XCTAssertNil(config.baseFont) // 使用系统默认 16pt
    }

    func testDarkThemeMarkStyle() {
        let config = XMarkupStyleConfig.dark
        XCTAssertNotNil(config[.mark]?.backgroundColor)
    }

    func testChatThemeBaseFont() {
        let config = XMarkupStyleConfig.chat
        XCTAssertEqual(config.baseFont?.pointSize, 14)
        XCTAssertNotNil(config[.link]?.foregroundColor)
    }

    func testArticleThemeHeadingFonts() {
        let config = XMarkupStyleConfig.article
        XCTAssertEqual(config.baseFont?.pointSize, 17)
        XCTAssertEqual(config[.heading1]?.font?.pointSize, 28)
        XCTAssertEqual(config[.heading2]?.font?.pointSize, 22)
        XCTAssertEqual(config[.heading3]?.font?.pointSize, 19)
        XCTAssertEqual(config.mediaPlaceholderSize, CGSize(width: 300, height: 200))
    }

    // MARK: - 自定义配置

    func testCustomTagStyleOverrides() throws {
        let result = try parse("<u>underline</u>")
        var config = XMarkupStyleConfig.default
        config[.underline] = XMarkupTagStyle(foregroundColor: XMColor.systemRed)
        let attr = result.makeAttributedString(config: config)
        let color = attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    func testSpanTransformerClosure() throws {
        let result = try parse("<b>bold</b>")
        var config = XMarkupStyleConfig.default
        var transformedSpanTag: XMarkupTag?
        config.spanTransformer = { span, attrs in
            transformedSpanTag = span.tag
            attrs[.foregroundColor] = XMColor.systemPurple
        }
        let attr = result.makeAttributedString(config: config)
        XCTAssertEqual(transformedSpanTag, .bold)
        let color = attr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? XMColor
        XCTAssertNotNil(color)
    }

    func testPostProcessorClosure() throws {
        let result = try parse("<b>bold</b>")
        var config = XMarkupStyleConfig.default
        var postProcessed = false
        config.postProcessor = { str in
            postProcessed = true
            str.addAttribute(
                .kern,
                value: NSNumber(value: 1.5),
                range: NSRange(location: 0, length: str.length)
            )
        }
        let attr = result.makeAttributedString(config: config)
        XCTAssertTrue(postProcessed)
        let kern = attr.attribute(.kern, at: 0, effectiveRange: nil) as? NSNumber
        XCTAssertNotNil(kern)
    }

    // MARK: - 媒体渲染

    func testImagePlaceholderAttachment() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let attr = result.makeAttributedString()
        // 图片位置应有 NSTextAttachment
        XCTAssertTrue(attr.length > 0)
        let hasAttachment = attr.enumerateAttachments { attachment, _ in
            return true
        }
        // 检查 attachment 存在
        var foundAttachment = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testImageWithCustomProvider() throws {
        let result = try parse("<img src=\"custom.png\">")
        var config = XMarkupStyleConfig.default
        var providerCalled = false
        config.imageProvider = { src in
            providerCalled = true
            XCTAssertEqual(src, "custom.png")
            // 返回 nil 触发占位图回退
            return nil
        }
        let _ = result.makeAttributedString(config: config)
        XCTAssertTrue(providerCalled)
    }

    func testVideoPlaceholderAttachment() throws {
        let result = try parse("<video src=\"movie.mp4\"></video>")
        let attr = result.makeAttributedString()
        var foundAttachment = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testAudioPlaceholderAttachment() throws {
        let result = try parse("<audio src=\"song.mp3\"></audio>")
        let attr = result.makeAttributedString()
        var foundAttachment = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testVideoWithSourceChild() throws {
        let result = try parse("<video><source src=\"a.mp4\" type=\"video/mp4\"></video>")
        let attr = result.makeAttributedString()
        var foundAttachment = false
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if value is NSTextAttachment {
                foundAttachment = true
            }
        }
        XCTAssertTrue(foundAttachment)
    }

    func testMediaPlaceholderSize() throws {
        let result = try parse("<img src=\"photo.jpg\">")
        let customSize = CGSize(width: 100, height: 80)
        var config = XMarkupStyleConfig.default
        config.mediaPlaceholderSize = customSize
        let attr = result.makeAttributedString(config: config)
        attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, _, _ in
            if let attachment = value as? NSTextAttachment {
                XCTAssertEqual(attachment.bounds.size, customSize)
            }
        }
    }

    // MARK: - 默认 config 行为与旧 API 兼容

    func testDefaultConfigMatchesOldBehavior() throws {
        let result = try parse("<b>bold</b> normal <i>italic</i>")
        let attr = result.makeAttributedString()
        let attrOld = result.makeAttributedString(config: .default)
        // 两者结果应一致（默认 config = .default）
        XCTAssertEqual(attr.string, attrOld.string)
    }
}
```

- [ ] **步骤 3：运行全部 Swift 测试**

```bash
swift test 2>&1 | tail -30
```

预期：全部 PASS（原有测试 + 新增约 15 个测试）

- [ ] **步骤 4：Commit**

```bash
git add platforms/ios/Tests/XMarkupTests/NSAttributedStringTests.swift \
       platforms/ios/Tests/XMarkupTests/StyleConfigTests.swift
git commit -m "test(ios): 新增 mark/config/media/rendering 单元测试

- NSAttributedStringTests: 新增 mark 背景色、config 覆盖测试
- StyleConfigTests: 4 个预置主题、spanTransformer、postProcessor、
  媒体附件（image/video/audio）、自定义 imageProvider、placeholderSize"
```

---

## 任务 6：Demo 示例增强（7 个新复杂场景）

**文件：**
- 修改：`playground/ios/XMarkupDemo/XMarkupDemo/Shared/DemoExamples.swift`

- [ ] **步骤 1：在 DemoExamples.swift 的 Category 枚举中新增分类**

将 `Category` 枚举替换为：

```swift
enum Category: String, CaseIterable {
    case basic = "基础格式"
    case color = "颜色"
    case heading = "标题"
    case link = "链接"
    case mixed = "混合样式"
    case complex = "复杂 HTML"
    case scenario = "场景实战"
    case media = "媒体"
}
```

- [ ] **步骤 2：在 `allExamples` 数组末尾（`edge-cases` 之后）追加 7 个新示例**

```swift
// MARK: - 场景实战

DemoExample(
    id: "article",
    title: "长文章阅读",
    description: "多段落、H1-H4、引用块、列表",
    html: """
    <h1>Swift 并发编程指南</h1>
    <p>Swift 5.5 引入了结构化并发，极大简化了异步编程模型。本文将从基础概念出发，逐步深入讲解 async/await、TaskGroup 和 Actor 的使用。</p>
    <h2>一、async/await 基础</h2>
    <p>传统的闭包回调容易导致<b>回调地狱</b>（Callback Hell），代码嵌套层次深、错误处理分散。async/await 让异步代码看起来像同步代码：</p>
    <p>使用 <code>async</code> 标记异步函数，用 <code>await</code> 挂起等待结果。编译器会在挂起点安全地让出线程，避免阻塞。</p>
    <h3>错误处理</h3>
    <p>配合 <code>do/catch</code> 语句，可以像处理同步错误一样处理异步错误：</p>
    <blockquote>结构化并发的核心思想是：每个并发任务都有明确的生命周期和作用域，编译器帮你保证资源不泄漏。</blockquote>
    <h2>二、Task 与 TaskGroup</h2>
    <p><b>Task</b> 是并发任务的基本单元。你可以创建 <i>非结构化任务</i>（detached task）或使用 <b>TaskGroup</b> 进行结构化并发：</p>
    <h4>子章节示例</h4>
    <p>TaskGroup 会自动等待所有子任务完成，并在任一子任务抛出错误时取消其余任务。</p>
    """,
    category: .scenario
),
DemoExample(
    id: "chat-msg",
    title: "聊天消息",
    description: "@提及、紧凑排版、emoji、图片混排",
    html: """
    <p><b>张三</b> <span style="color:#999999;font-size:12px">14:32</span></p>
    <p>@李明 你看了昨天的发布会吗？<a href="https://example.com/live">直播回放</a>在这里 👀</p>
    <p>新功能简直<b>太棒了</b>！特别是那个实时协作编辑 ✨</p>
    <p><img src="https://example.com/screenshot.png"></p>
    <p><span style="color:#0088CC">@王芳</span> 你觉得这个设计怎么样？</p>
    <p><i>（消息已编辑）</i></p>
    """,
    category: .scenario
),
DemoExample(
    id: "notification",
    title: "系统通知",
    description: "标题 + 富文本正文 + 操作链接",
    html: """
    <h3><span style="color:#FF6600">⚠️</span> 系统维护通知</h3>
    <p>尊敬的用户，我们将于 <b><span style="color:#FF0000">2026 年 6 月 15 日 02:00-06:00</span></b> 期间进行系统升级维护。</p>
    <p>维护期间以下服务将<u>暂时不可用</u>：</p>
    <p>• 在线支付功能</p>
    <p>• 数据导出服务</p>
    <p>• API 接口调用</p>
    <p>给您带来的不便，敬请谅解。如有疑问请联系 <a href="https://example.com/support"><span style="color:#0066CC">在线客服</span></a>。</p>
    <p><span style="color:#999999;font-size:12px">— 运维团队 · 2026-06-08</span></p>
    """,
    category: .scenario
),
DemoExample(
    id: "api-doc",
    title: "代码文档",
    description: "标题、代码块、行内代码、参数说明",
    html: """
    <h2>XMarkupParser.parse(_:)</h2>
    <p>解析 HTML 字符串并返回结构化结果。</p>
    <h3>声明</h3>
    <p><code>public func parse(_ html: String) throws -> XMarkupResult</code></p>
    <h3>参数</h3>
    <p><b>html</b> — HTML 输入字符串（UTF-8 编码）</p>
    <h3>返回值</h3>
    <p><code>XMarkupResult</code> — 包含解析后的纯文本和样式区间数组。</p>
    <h3>讨论</h3>
    <p>执行完整解析管线：<i>词法分析 → AST 构建 → 样式解析 → 实体解码 → UTF-16 索引映射</i>。</p>
    <p>线程安全：不同实例可跨线程并发使用，同一实例<b>不可并发调用</b>。</p>
    <h3>示例</h3>
    <p><code>let parser = try XMarkupParser()</code></p>
    <p><code>let result = try parser.parse("&lt;b&gt;Hello&lt;/b&gt;")</code></p>
    """,
    category: .scenario
),
DemoExample(
    id: "social-post",
    title: "社交动态",
    description: "#话题、@用户、图片混排",
    html: """
    <p><b>技术探索者</b> <span style="color:#999999">· 2 小时前</span></p>
    <p>今天终于搞定了 XMarkup 的 C++ 核心引擎 🎉 踩了不少坑：</p>
    <p>1. UTF-8 和 UTF-16 索引转换比想象中复杂得多</p>
    <p>2. HTML 实体解码需要处理 <code>&amp;amp;</code> 这种嵌套转义</p>
    <p>3. 空白折叠规则要考虑 <code>&lt;pre&gt;</code> 标签的特殊情况</p>
    <p><img src="https://example.com/code-screenshot.png"></p>
    <p><span style="color:#0066CC">#Swift开发</span> <span style="color:#0066CC">#C++</span> <span style="color:#0066CC">#富文本解析</span></p>
    <p><a href="https://example.com/user/claude"><span style="color:#0088CC">@Claude</span></a> 感谢 AI 辅助编程的帮助！</p>
    <p><span style="color:#999999;font-size:12px">❤️ 128 · 💬 32 · 🔄 56</span></p>
    """,
    category: .scenario
),
DemoExample(
    id: "product-detail",
    title: "商品详情",
    description: "价格、规格表、促销标签、图片",
    html: """
    <h2>MacBook Pro 16 英寸</h2>
    <p><span style="color:#FF0000;font-size:28px"><b>¥19,999</b></span> <s>¥22,999</s> <span style="background-color:#FF4444;color:#FFFFFF"> 省 ¥3,000 </span></p>
    <p><img src="https://example.com/macbook-pro.png"></p>
    <h3>核心规格</h3>
    <p>• 芯片：<b>Apple M4 Pro</b>（14 核 CPU / 20 核 GPU）</p>
    <p>• 内存：<span style="color:#FF6600"><b>48GB</b></span> 统一内存</p>
    <p>• 存储：1TB SSD（最高可选 8TB）</p>
    <p>• 显示屏：16.2 英寸 Liquid Retina XDR</p>
    <p>• 电池：最长 <mark>22 小时</mark> 续航</p>
    <p><span style="background-color:#FFF3CD">🎁 教育优惠额外减 ¥2,000</span></p>
    <p>详细信息请 <a href="https://example.com/macbook-pro">查看完整规格</a></p>
    """,
    category: .scenario
),

// MARK: - 媒体

DemoExample(
    id: "media-mix",
    title: "图文音视频混排",
    description: "img + video + audio + 文字组合",
    html: """
    <h2>2026 年度旅行 vlog</h2>
    <p>这次旅行从<b>东京</b>出发，途径 <i>京都</i>、<i>大阪</i>，最终抵达<b>北海道</b>。以下是精彩瞬间 🎬</p>
    <h3>📷 富士山日出</h3>
    <p><img src="https://example.com/fuji-sunrise.jpg"></p>
    <p>凌晨 4 点出发，等了两个小时终于拍到了这张 <span style="color:#FF6600">金色日出</span>。</p>
    <h3>🎥 京都岚山竹林</h3>
    <p><video src="https://example.com/bamboo-forest.mp4"></video></p>
    <p>竹林中的光影变幻，视频比照片更能传达那种宁静感。</p>
    <h3>🎵 街头艺人演奏</h3>
    <p><audio src="https://example.com/street-music.mp3"></audio></p>
    <p>在<b>心斋桥</b>遇到的街头艺人，<span style="color:#9B59B6">萨克斯</span>吹得真好听。</p>
    <p>—— 全程使用 iPhone 拍摄，<a href="https://example.com/gear">拍摄器材清单</a></p>
    """,
    category: .media
),
```

- [ ] **步骤 3：验证 Demo App 构建**

```bash
cd playground/ios/XMarkupDemo && xcodegen generate 2>&1
xcodebuild build -project XMarkupDemo.xcodeproj \
  -scheme XMarkupDemoSwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet 2>&1 | tail -5
```

预期：BUILD SUCCEEDED

- [ ] **步骤 4：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/Shared/DemoExamples.swift
git commit -m "feat(demo): 新增 7 个复杂场景示例

- 长文章阅读、聊天消息、系统通知、代码文档
- 社交动态、商品详情、图文音视频混排
- 新增 scenario 和 media 两个分类"
```

---

## 任务 7：Demo App 视图更新

**文件：**
- 修改：`playground/ios/XMarkupDemo/XMarkupDemo/SwiftUI/RenderedTextView.swift`
- 修改：`playground/ios/XMarkupDemo/XMarkupDemo/UIKit/RenderedTextViewController.swift`

- [ ] **步骤 1：更新 SwiftUI RenderedTextView.swift**

在 `NSAttributedStringWrapper` 的 `makeUIView` 方法中，在 `return textView` 之前添加：

```swift
func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.isEditable = false
    textView.isScrollEnabled = false
    textView.backgroundColor = .clear
    textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    textView.configureForXMarkup()
    return textView
}
```

即只加一行 `textView.configureForXMarkup()`。

- [ ] **步骤 2：更新 UIKit RenderedTextViewController.swift**

在 `setupTextView()` 方法中，`return` 之前添加一行：

```swift
private func setupTextView() {
    textView.isEditable = false
    textView.isScrollEnabled = true
    textView.backgroundColor = .clear
    textView.configureForXMarkup()  // ← 新增
    textView.translatesAutoresizingMaskIntoConstraints = false
    // ... 约束代码不变
}
```

- [ ] **步骤 3：验证构建**

```bash
cd playground/ios/XMarkupDemo && xcodegen generate 2>&1
xcodebuild build -project XMarkupDemo.xcodeproj \
  -scheme XMarkupDemoSwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet 2>&1 | tail -5
```

预期：BUILD SUCCEEDED

- [ ] **步骤 4：Commit**

```bash
git add playground/ios/XMarkupDemo/XMarkupDemo/SwiftUI/RenderedTextView.swift \
       playground/ios/XMarkupDemo/XMarkupDemo/UIKit/RenderedTextViewController.swift
git commit -m "fix(demo): SwiftUI/UIKit 渲染视图调用 configureForXMarkup()

清空 linkTextAttributes 让自定义链接颜色生效"
```

---

## 验证检查点

全部任务完成后执行最终验证：

```bash
# 1. C++ 核心引擎测试
(cd build && ctest --output-on-failure 2>&1 | tail -5)

# 2. Swift 桥接层测试
swift test 2>&1 | tail -10

# 3. Demo 构建
cd playground/ios/XMarkupDemo && xcodegen generate && \
  xcodebuild build -project XMarkupDemo.xcodeproj \
  -scheme XMarkupDemoSwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -quiet 2>&1 | tail -3
```

三项全部通过后，工作完成。
