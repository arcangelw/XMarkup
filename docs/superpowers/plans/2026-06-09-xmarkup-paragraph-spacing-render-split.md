# 段落排版 + Render 拆分 + 注释补充 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为 MarkupTheme 添加段落间距和行间距配置，拆分 556 行的 MarkupDocument+Render.swift 为 5 个职责单一的文件，补充 Core/Theme 模块缺失的文档注释。

**架构：** MarkupTheme 新增 ParagraphSpacing 配置，通过 NSParagraphStyle 应用；Render 文件按职责拆为 5 个文件，函数可见性从 private 改为 internal；注释遵循规格 §7.3 标准。

**技术栈：** Swift 6 / AttributedString + NSParagraphStyle / SPM

---

## 文件结构

### 新建文件

| 文件 | 职责 |
|------|------|
| `platforms/ios/Sources/XMarkup/Theme/ParagraphSpacing.swift` | 段落排版配置结构体 |
| `platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift` | 块级渲染 + 段落排版 + 主题覆盖 |
| `platforms/ios/Sources/XMarkup/Rendering/InlineRenderer.swift` | 内联渲染 + 字体 trait + CSS 样式 |
| `platforms/ios/Sources/XMarkup/Rendering/AttachmentRenderer.swift` | 附件渲染 + 占位图 |
| `platforms/ios/Sources/XMarkup/Rendering/RenderHelpers.swift` | name mapping + 工具函数 + 跨平台常量 |
| `platforms/ios/Tests/XMarkupTests/Theme/ParagraphSpacingTests.swift` | 段落排版测试 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift` | 新增 paragraphSpacing 字段 |
| `platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift` | 新增 ParagraphSpacingComponent + 便利函数 |
| `platforms/ios/Sources/XMarkup/Theme/PresetThemes.swift` | 各主题保持 default（无需改值，因 init 已含默认） |
| `platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift` | 精简为入口，调用拆分出的函数 |
| `platforms/ios/Sources/XMarkup/Core/BlockKind.swift` | Level + TableStructure 注释 |
| `platforms/ios/Sources/XMarkup/Core/MarkupAttachment.swift` | API 示例 + case 注释 |
| `platforms/ios/Sources/XMarkup/Core/MarkupInline.swift` | API 使用示例 |
| `platforms/ios/Sources/XMarkup/Theme/MediaRenderingStrategy.swift` | case 使用场景说明 |
| `platforms/ios/Sources/XMarkup/Theme/MarkupThemeBuilder.swift` | DSL 使用示例 |
| `platforms/ios/Sources/XMarkup/Theme/TagStyleKey.swift` | 文档注释 + case 含义 |
| `platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift` | 组件使用示例 |

---

## 任务 1：ParagraphSpacing 结构体 + MarkupTheme 集成 + DSL 组件

**文件：**
- 创建：`platforms/ios/Sources/XMarkup/Theme/ParagraphSpacing.swift`
- 修改：`platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift`
- 修改：`platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift`
- 创建：`platforms/ios/Tests/XMarkupTests/Theme/ParagraphSpacingTests.swift`

- [ ] **步骤 1：编写测试**

创建 `platforms/ios/Tests/XMarkupTests/Theme/ParagraphSpacingTests.swift`：

```swift
import XCTest
@testable import XMarkup

final class ParagraphSpacingTests: XCTestCase {

    // MARK: - ParagraphSpacing 结构体

    func testDefaultSpacing() {
        let spacing = ParagraphSpacing.default
        XCTAssertEqual(spacing.spacingBefore, 8)
        XCTAssertEqual(spacing.spacingAfter, 8)
        XCTAssertEqual(spacing.lineSpacing, 0)
    }

    func testCustomSpacing() {
        let spacing = ParagraphSpacing(spacingBefore: 12, spacingAfter: 16, lineSpacing: 4)
        XCTAssertEqual(spacing.spacingBefore, 12)
        XCTAssertEqual(spacing.spacingAfter, 16)
        XCTAssertEqual(spacing.lineSpacing, 4)
    }

    func testEquality() {
        let a = ParagraphSpacing(spacingBefore: 8, spacingAfter: 8, lineSpacing: 0)
        let b = ParagraphSpacing.default
        XCTAssertEqual(a, b)
    }

    func testInequality() {
        let a = ParagraphSpacing(lineSpacing: 4)
        let b = ParagraphSpacing.default
        XCTAssertNotEqual(a, b)
    }

    // MARK: - MarkupTheme 集成

    func testThemeDefaultParagraphSpacing() {
        let theme = MarkupTheme.default
        XCTAssertEqual(theme.paragraphSpacing, .default)
    }

    func testThemeEqualityIncludesParagraphSpacing() {
        var a = MarkupTheme.default
        var b = MarkupTheme.default
        XCTAssertEqual(a, b)
        a.paragraphSpacing = ParagraphSpacing(lineSpacing: 4)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - DSL 组件

    func testParagraphSpacingComponent() {
        let theme = MarkupTheme {
            ParagraphSpacing(spacingBefore: 10, spacingAfter: 10, lineSpacing: 2)
        }
        XCTAssertEqual(theme.paragraphSpacing.spacingBefore, 10)
        XCTAssertEqual(theme.paragraphSpacing.spacingAfter, 10)
        XCTAssertEqual(theme.paragraphSpacing.lineSpacing, 2)
    }

    func testParagraphSpacingComponentWithDefaults() {
        let theme = MarkupTheme {
            ParagraphSpacing()
        }
        XCTAssertEqual(theme.paragraphSpacing, .default)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift build 2>&1 | grep "error:" | head -5`

预期：编译失败，`ParagraphSpacing` 类型不存在。

- [ ] **步骤 3：创建 ParagraphSpacing.swift**

创建 `platforms/ios/Sources/XMarkup/Theme/ParagraphSpacing.swift`：

```swift
import Foundation

/// 段落排版配置
///
/// 控制 block 之间的纵向间距和 block 内部的行间距。
/// 通过 `NSParagraphStyle` 应用于 `AttributedString` 的每个 block。
///
/// 使用方式：
/// ```swift
/// let theme = MarkupTheme {
///     ParagraphSpacing(spacingBefore: 12, spacingAfter: 12, lineSpacing: 4)
/// }
/// ```
public struct ParagraphSpacing: Sendable, Equatable {
    /// 段前间距（pt），作用于当前 block 上方的空白距离
    public var spacingBefore: CGFloat
    /// 段后间距（pt），作用于当前 block 下方的空白距离
    public var spacingAfter: CGFloat
    /// 行间距（pt），作用于当前 block 内各行之间的额外距离，默认 0
    public var lineSpacing: CGFloat

    public init(
        spacingBefore: CGFloat = 8,
        spacingAfter: CGFloat = 8,
        lineSpacing: CGFloat = 0
    ) {
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.lineSpacing = lineSpacing
    }

    /// 默认段落间距：段前 8pt、段后 8pt、行间距 0
    public static let `default` = ParagraphSpacing()
}
```

- [ ] **步骤 4：集成到 MarkupTheme**

修改 `platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift`，在 `headingScale` 后新增 `paragraphSpacing` 字段，更新 init 和 `==`：

```swift
public struct MarkupTheme: @unchecked Sendable, Equatable {
    public var baseFont: XMFont
    public var headingScale: HeadingScale
    /// 段落排版配置（间距、行距）
    public var paragraphSpacing: ParagraphSpacing
    public var tagStyles: [TagStyleKey: AttributeContainer]
    public var mediaStrategy: MediaRenderingStrategy

    public init(
        baseFont: XMFont = XMFont.systemFont(ofSize: 16),
        headingScale: HeadingScale = .default,
        paragraphSpacing: ParagraphSpacing = .default,
        tagStyles: [TagStyleKey: AttributeContainer] = [:],
        mediaStrategy: MediaRenderingStrategy = .placeholder
    ) {
        self.baseFont = baseFont
        self.headingScale = headingScale
        self.paragraphSpacing = paragraphSpacing
        self.tagStyles = tagStyles
        self.mediaStrategy = mediaStrategy
    }

    public static func == (lhs: MarkupTheme, rhs: MarkupTheme) -> Bool {
        lhs.baseFont == rhs.baseFont
            && lhs.headingScale == rhs.headingScale
            && lhs.paragraphSpacing == rhs.paragraphSpacing
            && lhs.tagStyles == rhs.tagStyles
    }
}
```

- [ ] **步骤 5：添加 DSL 组件**

在 `platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift` 末尾添加：

```swift
/// 段落排版组件
public struct ParagraphSpacingComponent: ThemeComponent {
    public let spacing: ParagraphSpacing

    public init(_ spacing: ParagraphSpacing) {
        self.spacing = spacing
    }

    public func apply(to theme: inout MarkupTheme) {
        theme.paragraphSpacing = spacing
    }
}

/// 便利函数：创建 ParagraphSpacingComponent
public func ParagraphSpacing(
    spacingBefore: CGFloat = 8,
    spacingAfter: CGFloat = 8,
    lineSpacing: CGFloat = 0
) -> ParagraphSpacingComponent {
    ParagraphSpacingComponent(ParagraphSpacing(
        spacingBefore: spacingBefore,
        spacingAfter: spacingAfter,
        lineSpacing: lineSpacing
    ))
}
```

- [ ] **步骤 6：运行测试验证通过**

运行：`swift test 2>&1 | tail -5`

预期：所有测试通过（含新增的 ParagraphSpacing 测试）。

- [ ] **步骤 7：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Theme/ParagraphSpacing.swift \
       platforms/ios/Sources/XMarkup/Theme/MarkupTheme.swift \
       platforms/ios/Sources/XMarkup/Theme/ThemeComponent.swift \
       platforms/ios/Tests/XMarkupTests/Theme/ParagraphSpacingTests.swift
git commit -m "feat: 新增 ParagraphSpacing 段落排版配置，集成到 MarkupTheme 和 DSL"
```

---

## 任务 2：Render 文件拆分

**文件：**
- 重写：`platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift`（精简为 ~50 行）
- 创建：`platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift`
- 创建：`platforms/ios/Sources/XMarkup/Rendering/InlineRenderer.swift`
- 创建：`platforms/ios/Sources/XMarkup/Rendering/AttachmentRenderer.swift`
- 创建：`platforms/ios/Sources/XMarkup/Rendering/RenderHelpers.swift`

**重要说明：** 所有从原文件拆出的 `private func` 改为 `func`（`internal` 可见性），以便跨文件调用。

- [ ] **步骤 1：创建 RenderHelpers.swift**

创建 `platforms/ios/Sources/XMarkup/Rendering/RenderHelpers.swift`，包含以下从 `MarkupDocument+Render.swift` 提取的函数。将所有 `private` 改为 `internal`（即去掉 `private` 关键字）：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Name Mappings

func blockKindName(for kind: BlockKind) -> String {
    switch kind {
    case .paragraph: return "paragraph"
    case .heading(let level): return "heading\(level.rawValue)"
    case .blockquote: return "blockquote"
    case .preformatted: return "preformatted"
    case .listItem: return "listItem"
    case .division: return "division"
    case .horizontalRule: return "horizontalRule"
    case .table: return "table"
    }
}

func inlineKindName(for kind: InlineKind) -> String {
    switch kind {
    case .bold: return "bold"
    case .italic: return "italic"
    case .underline: return "underline"
    case .strikethrough: return "strikethrough"
    case .code: return "code"
    case .mark: return "mark"
    case .link: return "link"
    case .subscriptText: return "subscript"
    case .superscript: return "superscript"
    case .span: return "span"
    }
}

func blockStyleKey(for kind: BlockKind) -> TagStyleKey? {
    switch kind {
    case .paragraph: return .paragraph
    case .heading: return .heading
    case .blockquote: return .blockquote
    case .preformatted: return .preformatted
    case .listItem: return .listItem
    case .division: return .division
    case .horizontalRule: return .horizontalRule
    case .table: return nil
    }
}

func inlineStyleKey(for kind: InlineKind) -> TagStyleKey? {
    switch kind {
    case .bold: return .bold
    case .italic: return .italic
    case .underline: return .underline
    case .strikethrough: return .strikethrough
    case .code: return .code
    case .mark: return .mark
    case .link: return .link
    case .subscriptText, .superscript: return nil
    case .span: return nil
    }
}

func extractSrc(from content: AttachmentContent) -> String {
    switch content {
    case .image(let src), .video(let src), .audio(let src): return src
    case .custom(_, let metadata): return metadata["src"] ?? ""
    }
}

func srcIdentifier(from content: AttachmentContent) -> String {
    switch content {
    case .image(let src): return "image:\(src)"
    case .video(let src): return "video:\(src)"
    case .audio(let src): return "audio:\(src)"
    case .custom(let type, _): return "custom:\(type)"
    }
}

// MARK: - 跨平台字体 Trait 常量

#if canImport(UIKit)
let traitBold: UIFontDescriptor.SymbolicTraits = .traitBold
let traitItalic: UIFontDescriptor.SymbolicTraits = .traitItalic
#elseif canImport(AppKit)
let traitBold: NSFontDescriptor.SymbolicTraits = .bold
let traitItalic: NSFontDescriptor.SymbolicTraits = .italic
#endif
```

- [ ] **步骤 2：创建 InlineRenderer.swift**

创建 `platforms/ios/Sources/XMarkup/Rendering/InlineRenderer.swift`，提取 `applyInlineAttributes`、`applyFontTrait`、`applyInlineStyle`，去掉 `private`：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Inline Attributes

func applyInlineAttributes(
    _ inline: MarkupInline,
    theme: MarkupTheme,
    to attr: inout AttributedString,
    blockText: String
) {
    // inline.range 是 UTF-16 NSRange（相对于块文本起始位置）
    // 通过 String.Index 中转后使用 character offset 定位 AttributedString，
    // 避免 Range(NSRange, in: AttributedString) 在 emoji 场景下可能出现的边界错位。
    //
    // 关键假设：AttributedString(block.text) 的 character index 与 String(block.text) 的
    // character index 一致（两者都基于 Extended Grapheme Cluster）。
    // Apple 的 AttributedString 初始化时未做 Unicode 规范化（NFC），
    // 因此此假设在当前 Apple 实现下成立。
    let attrRange: Range<AttributedString.Index>
    do {
        guard let stringRange = Range(inline.range, in: blockText) else { return }
        let charOffset = blockText.distance(from: blockText.startIndex, to: stringRange.lowerBound)
        let charLength = blockText.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
        guard charLength > 0 else { return }
        let start = attr.index(attr.startIndex, offsetByCharacters: charOffset)
        let end = attr.index(start, offsetByCharacters: charLength)
        #if DEBUG
        assert(String(attr[start..<end].characters) == String(blockText[stringRange]),
               "AttributedString character index 与 String character index 不一致，请检查 Unicode 规范化问题")
        #endif
        attrRange = start..<end
    }

    switch inline.kind {
    case .bold:
        applyFontTrait(traitBold, to: attrRange, in: &attr)

    case .italic:
        applyFontTrait(traitItalic, to: attrRange, in: &attr)

    case .underline:
        #if canImport(UIKit)
        attr[attrRange].uiKit.underlineStyle = .single
        #elseif canImport(AppKit)
        attr[attrRange].appKit.underlineStyle = .single
        #endif

    case .strikethrough:
        #if canImport(UIKit)
        attr[attrRange].uiKit.strikethroughStyle = .single
        #elseif canImport(AppKit)
        attr[attrRange].appKit.strikethroughStyle = .single
        #endif

    case .code:
        #if canImport(UIKit)
        attr[attrRange].uiKit.font = UIFont.monospacedSystemFont(
            ofSize: theme.baseFont.pointSize, weight: .regular
        )
        #elseif canImport(AppKit)
        attr[attrRange].appKit.font = NSFont.monospacedSystemFont(
            ofSize: theme.baseFont.pointSize, weight: .regular
        )
        #endif

    case .mark:
        break  // 颜色由主题 tagStyles 覆盖

    case .link(let url):
        #if canImport(UIKit)
        attr[attrRange].uiKit.foregroundColor = .systemBlue
        #elseif canImport(AppKit)
        attr[attrRange].appKit.foregroundColor = .linkColor
        #endif
        attr[attrRange].link = URL(string: url)
        attr[attrRange][XMarkupLinkURLKey.self] = url

    case .subscriptText:
        break  // P2

    case .superscript:
        break  // P2

    case .span(let styles):
        for style in styles {
            applyInlineStyle(style, to: attrRange, in: &attr)
        }
    }

    // 为所有内联元素设置自定义 tag
    let tagName = inlineKindName(for: inline.kind)
    attr[attrRange][XMarkupTagKey.self] = tagName
}

func applyFontTrait(
    _ trait: XMFontDescriptor.SymbolicTraits,
    to range: Range<AttributedString.Index>,
    in attr: inout AttributedString
) {
    for run in attr[range].runs {
        #if canImport(UIKit)
        if let font = run.uiKit.font {
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                attr[run.range].uiKit.font = newFont
            }
        }
        #elseif canImport(AppKit)
        if let font = run.appKit.font {
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            if let newFont = NSFont(descriptor: descriptor, size: font.pointSize) {
                attr[run.range].appKit.font = newFont
            }
        }
        #endif
    }
}

func applyInlineStyle(
    _ style: InlineStyle,
    to range: Range<AttributedString.Index>,
    in attr: inout AttributedString
) {
    switch style {
    case .foregroundColor(let hex):
        if let color = ColorParser.parse(hex) {
            #if canImport(UIKit)
            attr[range].uiKit.foregroundColor = color
            #elseif canImport(AppKit)
            attr[range].appKit.foregroundColor = color
            #endif
        }
    case .backgroundColor(let hex):
        if let color = ColorParser.parse(hex) {
            #if canImport(UIKit)
            attr[range].uiKit.backgroundColor = color
            #elseif canImport(AppKit)
            attr[range].appKit.backgroundColor = color
            #endif
        }
    case .fontSize(let size):
        for run in attr[range].runs {
            #if canImport(UIKit)
            if let font = run.uiKit.font {
                let newFont = UIFont(descriptor: font.fontDescriptor, size: CGFloat(size))
                attr[run.range].uiKit.font = newFont
            }
            #elseif canImport(AppKit)
            if let font = run.appKit.font {
                if let newFont = NSFont(descriptor: font.fontDescriptor, size: CGFloat(size)) {
                    attr[run.range].appKit.font = newFont
                }
            }
            #endif
        }
    case .fontStyle(let fontStyle):
        if fontStyle == "italic" {
            applyFontTrait(traitItalic, to: range, in: &attr)
        }
    case .textDecoration(let decoration):
        if decoration == "underline" {
            #if canImport(UIKit)
            attr[range].uiKit.underlineStyle = .single
            #elseif canImport(AppKit)
            attr[range].appKit.underlineStyle = .single
            #endif
        } else if decoration == "line-through" {
            #if canImport(UIKit)
            attr[range].uiKit.strikethroughStyle = .single
            #elseif canImport(AppKit)
            attr[range].appKit.strikethroughStyle = .single
            #endif
        }
    case .fontWeight, .lineHeight, .letterSpacing:
        break  // P2
    }
}
```

- [ ] **步骤 3：创建 AttachmentRenderer.swift**

创建 `platforms/ios/Sources/XMarkup/Rendering/AttachmentRenderer.swift`，提取 `renderAttachmentBlock`、`createPlaceholderAttachment`、`createPlaceholderImage`，去掉 `private`：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Attachment Rendering

func renderAttachmentBlock(
    _ block: MarkupBlock,
    attachment: MarkupAttachment,
    theme: MarkupTheme,
    baseAttributes: AttributeContainer
) -> AttributedString {
    let nsAttachment: NSTextAttachment

    switch theme.mediaStrategy {
    case .placeholder:
        nsAttachment = createPlaceholderAttachment(
            content: attachment.content,
            suggestedSize: attachment.suggestedSize
        )
    case .imageProvider(let provider):
        let src = extractSrc(from: attachment.content)
        if let image = provider(src) {
            let attach = NSTextAttachment()
            attach.image = image
            let aspectRatio = image.size.height / max(image.size.width, 1)
            let displayWidth = attachment.suggestedSize.width
            let displaySize = CGSize(width: displayWidth, height: displayWidth * aspectRatio)
            attach.bounds = CGRect(origin: .zero, size: displaySize)
            nsAttachment = attach
        } else {
            nsAttachment = createPlaceholderAttachment(
                content: attachment.content,
                suggestedSize: attachment.suggestedSize
            )
        }
    case .customAttachment(let factory):
        if let custom = factory(attachment.content, attachment.suggestedSize) {
            nsAttachment = custom
        } else {
            nsAttachment = createPlaceholderAttachment(
                content: attachment.content,
                suggestedSize: attachment.suggestedSize
            )
        }
    }

    // 通过 NSAttributedString 中间步骤嵌入 NSTextAttachment
    var attr = AttributedString("\u{FFFC}", attributes: baseAttributes)
    attr[XMarkupAttachmentRefKey.self] = srcIdentifier(from: attachment.content)
    attr[XMarkupTagKey.self] = blockKindName(for: block.kind)

    let nsAttr = NSMutableAttributedString(attributedString: NSAttributedString(attr))
    let attachmentAttr = NSAttributedString(attachment: nsAttachment)
    let nsRange = (nsAttr.string as NSString).range(of: "\u{FFFC}")
    if nsRange.location != NSNotFound {
        nsAttr.replaceCharacters(in: nsRange, with: attachmentAttr)
    }

    return AttributedString(nsAttr)
}

func createPlaceholderAttachment(
    content: AttachmentContent,
    suggestedSize: CGSize
) -> NSTextAttachment {
    let symbolName: String
    switch content {
    case .image: symbolName = "photo"
    case .video: symbolName = "play.rectangle"
    case .audio: symbolName = "waveform"
    case .custom: symbolName = "square"
    }

    let size = suggestedSize.width > 0 ? suggestedSize : CGSize(width: 200, height: 150)
    let image = createPlaceholderImage(systemName: symbolName, size: size)

    let attachment = NSTextAttachment()
    attachment.image = image
    attachment.bounds = CGRect(origin: .zero, size: size)
    return attachment
}

func createPlaceholderImage(systemName: String, size: CGSize) -> XMImage {
    #if canImport(UIKit)
    let symbolConfig = UIImage.SymbolConfiguration(pointSize: min(size.width, size.height) * 0.3)
    let symbol = UIImage(systemName: systemName, withConfiguration: symbolConfig) ?? UIImage()
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
    #elseif canImport(AppKit)
    let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) ?? NSImage(size: size)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.systemGray.withAlphaComponent(0.1).setFill()
    NSRect(origin: .zero, size: size).fill()
    let symbolSize = symbol.size
    symbol.draw(
        at: NSPoint(x: (size.width - symbolSize.width) / 2, y: (size.height - symbolSize.height) / 2),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
    )
    image.unlockFocus()
    return image
    #endif
}
```

- [ ] **步骤 4：创建 BlockRenderer.swift**

创建 `platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift`，提取 `renderBlock`、`applyBlockKindAttributes`、`applyThemeOverrides`、`mergeAttributeContainer`，去掉 `private`：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Block Rendering

func renderBlock(_ block: MarkupBlock, theme: MarkupTheme) -> AttributedString {
    // 1. 构建块级基础属性
    var baseAttributes = AttributeContainer()
    #if canImport(UIKit)
    baseAttributes.uiKit.font = theme.baseFont
    #elseif canImport(AppKit)
    baseAttributes.appKit.font = theme.baseFont
    #endif

    // 2. 根据 block.kind 调整属性
    applyBlockKindAttributes(kind: block.kind, theme: theme, to: &baseAttributes)

    // 3. 设置自定义 XMarkupScope 属性
    let blockKindName = blockKindName(for: block.kind)
    baseAttributes[XMarkupTagKey.self] = blockKindName
    baseAttributes[XMarkupBlockKindKey.self] = blockKindName

    switch block.kind {
    case let .heading(level):
        baseAttributes[XMarkupHeadingLevelKey.self] = level.rawValue
    case let .listItem(isOrdered, indentLevel):
        baseAttributes[XMarkupListItemInfoKey.self] = "\(isOrdered ? "ordered" : "unordered"):\(indentLevel)"
    default:
        break
    }

    // 4. 处理媒体附件
    if let attachment = block.attachment {
        return renderAttachmentBlock(block, attachment: attachment, theme: theme, baseAttributes: baseAttributes)
    }

    // 5. 构建段落 AttributedString
    var attr = AttributedString(block.text, attributes: baseAttributes)

    // 6. 应用内联样式
    for inline in block.inlines {
        applyInlineAttributes(inline, theme: theme, to: &attr, blockText: block.text)
    }

    // 7. 应用主题 tagStyles 覆盖
    applyThemeOverrides(for: block, theme: theme, to: &attr)

    return attr
}

// MARK: - Block Kind Attributes

func applyBlockKindAttributes(
    kind: BlockKind,
    theme: MarkupTheme,
    to attributes: inout AttributeContainer
) {
    switch kind {
    case let .heading(level):
        let scale: CGFloat
        switch level {
        case .h1: scale = theme.headingScale.h1
        case .h2: scale = theme.headingScale.h2
        case .h3: scale = theme.headingScale.h3
        case .h4: scale = theme.headingScale.h4
        case .h5: scale = theme.headingScale.h5
        case .h6: scale = theme.headingScale.h6
        }
        let fontSize = theme.baseFont.pointSize * scale
        #if canImport(UIKit)
        if let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(traitBold) {
            attributes.uiKit.font = UIFont(descriptor: boldDescriptor, size: fontSize)
        }
        #elseif canImport(AppKit)
        let boldDescriptor = theme.baseFont.fontDescriptor.withSymbolicTraits(.bold)
        if let font = NSFont(descriptor: boldDescriptor, size: fontSize) {
            attributes.appKit.font = font
        }
        #endif

    case .preformatted:
        #if canImport(UIKit)
        attributes.uiKit.font = UIFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        #elseif canImport(AppKit)
        attributes.appKit.font = NSFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .regular)
        #endif

    case .horizontalRule:
        break

    default:
        break
    }
}

// MARK: - Theme Overrides

func applyThemeOverrides(
    for block: MarkupBlock,
    theme: MarkupTheme,
    to attr: inout AttributedString
) {
    // 块级主题覆盖
    if let blockKey = blockStyleKey(for: block.kind),
       let container = theme.tagStyles[blockKey] {
        let fullRange = attr.startIndex..<attr.endIndex
        mergeAttributeContainer(container, into: &attr, range: fullRange)
    }

    // 内联主题覆盖
    for inline in block.inlines {
        if let inlineKey = inlineStyleKey(for: inline.kind),
           let container = theme.tagStyles[inlineKey] {
            // inline.range 是 UTF-16 NSRange（相对于块文本起始位置）
            // 通过 String.Index 中转，确保 emoji 场景不出现边界错位
            guard let stringRange = Range(inline.range, in: block.text) else { continue }
            let charOffset = block.text.distance(from: block.text.startIndex, to: stringRange.lowerBound)
            let charLength = block.text.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
            guard charLength > 0 else { continue }
            let start = attr.index(attr.startIndex, offsetByCharacters: charOffset)
            let end = attr.index(start, offsetByCharacters: charLength)
            mergeAttributeContainer(container, into: &attr, range: start..<end)
        }
    }
}

func mergeAttributeContainer(
    _ container: AttributeContainer,
    into attr: inout AttributedString,
    range: Range<AttributedString.Index>
) {
    #if canImport(UIKit)
    if let font = container.uiKit.font {
        attr[range].uiKit.font = font
    }
    if let color = container.uiKit.foregroundColor {
        attr[range].uiKit.foregroundColor = color
    }
    if let bgColor = container.uiKit.backgroundColor {
        attr[range].uiKit.backgroundColor = bgColor
    }
    #elseif canImport(AppKit)
    if let font = container.appKit.font {
        attr[range].appKit.font = font
    }
    if let color = container.appKit.foregroundColor {
        attr[range].appKit.foregroundColor = color
    }
    if let bgColor = container.appKit.backgroundColor {
        attr[range].appKit.backgroundColor = bgColor
    }
    #endif
}
```

- [ ] **步骤 5：精简 MarkupDocument+Render.swift**

将 `platforms/ios/Sources/XMarkup/Rendering/MarkupDocument+Render.swift` 替换为仅保留公开入口方法：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension MarkupDocument {

    /// 将文档转换为 AttributedString
    ///
    /// 性能策略：按 block 分段构建（init(String, attributes: AttributeContainer)），
    /// 然后一次性 append 拼接。利用 AttributedString 的 COW 优化。
    public func render(theme: MarkupTheme = .default) -> AttributedString {
        guard !blocks.isEmpty else {
            return AttributedString("")
        }

        var result = AttributedString("")

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            result.append(renderBlock(block, theme: theme))
        }

        return result
    }
}
```

- [ ] **步骤 6：运行测试验证拆分未破坏功能**

运行：`swift test 2>&1 | tail -5`

预期：所有测试通过。

- [ ] **步骤 7：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/
git commit -m "refactor: 拆分 MarkupDocument+Render.swift 为 5 个职责单一的文件"
```

---

## 任务 3：在渲染管线中应用段落排版

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift`

- [ ] **步骤 1：编写测试 — 渲染结果包含 NSParagraphStyle**

在 `platforms/ios/Tests/XMarkupTests/Theme/ParagraphSpacingTests.swift` 末尾追加：

```swift
    // MARK: - 渲染管线验证

    func testRenderAppliesParagraphSpacing() throws {
        let theme = MarkupTheme {
            ParagraphSpacing(spacingBefore: 12, spacingAfter: 10, lineSpacing: 4)
        }
        let parser = try XMarkupParser()
        let result = try parser.parse("<p>Hello</p><p>World</p>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render(theme: theme)

        // 验证 runs 中存在 paragraphStyle
        var foundSpacing = false
        for run in attr.runs {
            #if canImport(UIKit)
            if let ps = run.uiKit.paragraphStyle {
                if ps.paragraphSpacingBefore == 12 && ps.paragraphSpacing == 10 && ps.lineSpacing == 4 {
                    foundSpacing = true
                }
            }
            #elseif canImport(AppKit)
            if let ps = run.appKit.paragraphStyle {
                if ps.paragraphSpacingBefore == 12 && ps.paragraphSpacing == 10 && ps.lineSpacing == 4 {
                    foundSpacing = true
                }
            }
            #endif
        }
        XCTAssertTrue(foundSpacing, "渲染结果应包含 ParagraphSpacing 配置的 NSParagraphStyle")
    }

    func testRenderDefaultThemeHasParagraphSpacing() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        let attr = doc.render()

        // 默认主题应有 8pt 间距
        var foundSpacing = false
        for run in attr.runs {
            #if canImport(UIKit)
            if let ps = run.uiKit.paragraphStyle {
                if ps.paragraphSpacingBefore == 8 && ps.paragraphSpacing == 8 {
                    foundSpacing = true
                }
            }
            #elseif canImport(AppKit)
            if let ps = run.appKit.paragraphStyle {
                if ps.paragraphSpacingBefore == 8 && ps.paragraphSpacing == 8 {
                    foundSpacing = true
                }
            }
            #endif
        }
        XCTAssertTrue(foundSpacing, "默认主题应包含 8pt 段落间距")
    }
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter ParagraphSpacingTests 2>&1 | grep -E "(FAIL|error:)" | head -5`

预期：`testRenderAppliesParagraphSpacing` 和 `testRenderDefaultThemeHasParagraphSpacing` 失败（paragraphStyle 未设置）。

- [ ] **步骤 3：在 BlockRenderer 中应用 NSParagraphStyle**

修改 `platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift` 中的 `renderBlock` 函数，在步骤 1（构建基础属性）之后、步骤 2（根据 kind 调整）之前，插入段落排版设置：

在 `baseAttributes.appKit.font = theme.baseFont` 之后、`// 2.` 注释之前插入：

```swift
    // 1.5 应用段落排版间距
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacingBefore = theme.paragraphSpacing.spacingBefore
    paragraphStyle.paragraphSpacing = theme.paragraphSpacing.spacingAfter
    paragraphStyle.lineSpacing = theme.paragraphSpacing.lineSpacing
    #if canImport(UIKit)
    baseAttributes.uiKit.paragraphStyle = paragraphStyle
    #elseif canImport(AppKit)
    baseAttributes.appKit.paragraphStyle = paragraphStyle
    #endif
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test 2>&1 | tail -5`

预期：所有测试通过。

- [ ] **步骤 5：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Rendering/BlockRenderer.swift \
       platforms/ios/Tests/XMarkupTests/Theme/ParagraphSpacingTests.swift
git commit -m "feat: 渲染管线应用 ParagraphSpacing（NSParagraphStyle）"
```

---

## 任务 4：Core/Theme 注释补充

**文件：**
- 修改：`platforms/ios/Sources/XMarkup/Core/BlockKind.swift`
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupAttachment.swift`
- 修改：`platforms/ios/Sources/XMarkup/Core/MarkupInline.swift`
- 修改：`platforms/ios/Sources/XMarkup/Theme/MediaRenderingStrategy.swift`
- 修改：`platforms/ios/Sources/XMarkup/Theme/MarkupThemeBuilder.swift`
- 修改：`platforms/ios/Sources/XMarkup/Theme/TagStyleKey.swift`

- [ ] **步骤 1：BlockKind.swift — Level 和 TableStructure 注释**

将 `BlockKind.swift` 替换为：

```swift
import Foundation

/// 标题级别
///
/// 对应 HTML 的 `<h1>` ~ `<h6>` 标签，rawValue 即标题级别数字。
public enum Level: Int, Sendable, Equatable, Comparable, Codable {
    case h1 = 1  // <h1>，最大标题
    case h2 = 2  // <h2>
    case h3 = 3  // <h3>
    case h4 = 4  // <h4>
    case h5 = 5  // <h5>
    case h6 = 6  // <h6>，最小标题

    public static func < (lhs: Level, rhs: Level) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 段落类型
public enum BlockKind: Sendable, Equatable {
    case paragraph                                           // <p>
    case heading(Level)                                      // <h1>~<h6>
    case blockquote                                          // <blockquote>
    case preformatted                                        // <pre>
    case listItem(isOrdered: Bool, indentLevel: Int)         // <li>
    case division                                            // <div>
    case horizontalRule                                      // <hr>
    case table(TableStructure)                               // <table>
}

/// 表格结构
///
/// P3 远期规划，当前按行列顺序拼接为纯文本段落，无特殊布局。
public struct TableStructure: Sendable, Equatable {
    /// 每行每列的块
    public let rows: [[MarkupBlock]]
    /// 表头行数
    public let headerRowCount: Int
    /// 列数
    public let columnCount: Int

    public init(rows: [[MarkupBlock]], headerRowCount: Int, columnCount: Int) {
        self.rows = rows
        self.headerRowCount = headerRowCount
        self.columnCount = columnCount
    }
}
```

- [ ] **步骤 2：MarkupAttachment.swift — API 示例 + case 注释**

将 `MarkupAttachment.swift` 替换为：

```swift
import Foundation

/// 平台无关的媒体附件描述
///
/// ```swift
/// let attachment = MarkupAttachment(
///     content: .image(src: "photo.jpg"),
///     suggestedSize: CGSize(width: 300, height: 200),
///     alignment: .center
/// )
/// ```
public struct MarkupAttachment: Sendable, Equatable {
    public let content: AttachmentContent
    public let suggestedSize: CGSize
    public let alignment: AttachmentAlignment

    public init(
        content: AttachmentContent,
        suggestedSize: CGSize,
        alignment: AttachmentAlignment = .default
    ) {
        self.content = content
        self.suggestedSize = suggestedSize
        self.alignment = alignment
    }
}

/// 附件内容类型
public enum AttachmentContent: Sendable, Equatable {
    case image(src: String)                          // <img src="...">
    case video(src: String)                          // <video src="...">
    case audio(src: String)                          // <audio src="...">
    /// 第三方扩展入口，携带自定义类型和元数据
    case custom(type: String, metadata: [String: String])
}

/// 附件对齐方式
public enum AttachmentAlignment: String, Sendable, Equatable {
    case `default`  // 跟随文本方向
    case center     // 居中
    case leading    // 左对齐（LTR 环境下）
    case trailing   // 右对齐（LTR 环境下）
}
```

- [ ] **步骤 3：MarkupInline.swift — API 使用示例**

在 `MarkupInline` 结构体的文档注释中添加使用示例：

```swift
/// 内联样式（字符级）
///
/// `range` 是相对于所属 `MarkupBlock.text` 的 UTF-16 NSRange 偏移。
///
/// ```swift
/// let inline = doc.blocks[0].inlines[0]
/// // inline.range = NSRange(location: 6, length: 4)
/// // inline.kind = .bold
/// ```
public struct MarkupInline: Sendable, Equatable {
```

- [ ] **步骤 4：MediaRenderingStrategy.swift — case 使用场景**

将 `MediaRenderingStrategy.swift` 替换为：

```swift
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 媒体渲染策略
///
/// 决定 `<img>` / `<video>` / `<audio>` 标签如何被渲染为视觉内容。
public enum MediaRenderingStrategy: Sendable {
    /// 使用 SF Symbol 占位图（默认）
    ///
    /// 适用于不需要加载真实图片的场景（如预览、占位）。
    case placeholder

    /// 通过闭包加载图片
    ///
    /// 适用于需要异步加载网络图片或从缓存取图片的场景。
    /// 闭包返回 `nil` 时自动回退到占位图。
    ///
    /// ```swift
    /// .imageProvider { src in
    ///     ImageCache.shared.load(src)
    /// }
    /// ```
    case imageProvider(@Sendable (String) -> XMImage?)

    /// 通过闭包创建自定义附件
    ///
    /// 适用于需要完全自定义 NSTextAttachment 的场景（如自定义 View 内嵌）。
    /// 闭包返回 `nil` 时自动回退到占位图。
    case customAttachment(@Sendable (AttachmentContent, CGSize) -> NSTextAttachment?)
}
```

- [ ] **步骤 5：MarkupThemeBuilder.swift — DSL 使用示例**

将 `MarkupThemeBuilder.swift` 替换为：

```swift
import Foundation

@resultBuilder
public enum MarkupThemeBuilder {
    public static func buildBlock(_ components: ThemeComponent...) -> [ThemeComponent] {
        Array(components)
    }
}

extension MarkupTheme {
    /// 使用 Result Builder DSL 构建主题
    ///
    /// ```swift
    /// let theme = MarkupTheme {
    ///     BaseFont(.systemFont(ofSize: 17))
    ///     HeadingScaleComponent(HeadingScale(h1: 2.5))
    ///     ParagraphSpacing(spacingBefore: 12, spacingAfter: 12)
    ///     Tag(.code) { $0.uiKit.backgroundColor = .systemGray6 }
    ///     Tag(.link) { $0.uiKit.foregroundColor = .systemBlue }
    /// }
    /// ```
    public init(@MarkupThemeBuilder builder: () -> [ThemeComponent]) {
        self.init()
        var theme = MarkupTheme()
        for component in builder() {
            component.apply(to: &theme)
        }
        self = theme
    }
}
```

- [ ] **步骤 6：TagStyleKey.swift — 文档注释 + case 含义**

将 `TagStyleKey.swift` 替换为：

```swift
import Foundation

/// 主题配置 key（用于 MarkupTheme.tagStyles 字典）
///
/// 每个 key 对应一种 HTML 标签或元素类型的样式覆盖。
/// 通过 `Tag()` DSL 函数设置：
///
/// ```swift
/// Tag(.code) { $0.uiKit.font = .monospacedSystemFont(ofSize: 14, weight: .regular) }
/// ```
public enum TagStyleKey: String, Sendable, Equatable, Hashable, CaseIterable {
    // 内联样式
    case bold              // <b> / <strong>
    case italic            // <i> / <em>
    case underline         // <u>
    case strikethrough     // <s> / <del>
    case code              // <code>
    case mark              // <mark>
    case link              // <a>
    // 块级结构
    case heading           // <h1>~<h6>（统一覆盖，不区分级别）
    case paragraph         // <p>
    case blockquote        // <blockquote>
    case preformatted      // <pre>
    case listItem          // <li>
    case division          // <div>
    case horizontalRule    // <hr>
    // 媒体
    case image             // <img>
    case video             // <video>
    case audio             // <audio>
}
```

- [ ] **步骤 7：运行测试验证**

运行：`swift test 2>&1 | tail -5`

预期：所有测试通过。

- [ ] **步骤 8：Commit**

```bash
git add platforms/ios/Sources/XMarkup/Core/BlockKind.swift \
       platforms/ios/Sources/XMarkup/Core/MarkupAttachment.swift \
       platforms/ios/Sources/XMarkup/Core/MarkupInline.swift \
       platforms/ios/Sources/XMarkup/Theme/MediaRenderingStrategy.swift \
       platforms/ios/Sources/XMarkup/Theme/MarkupThemeBuilder.swift \
       platforms/ios/Sources/XMarkup/Theme/TagStyleKey.swift
git commit -m "docs: 补充 Core/Theme 模块文档注释（Level、TableStructure、Attachment、Inline、TagStyleKey 等）"
```

---

## 自检

### 1. 规格覆盖度

| 规格章节 | 对应任务 |
|---------|---------|
| §1.1~1.3 ParagraphSpacing + MarkupTheme + DSL | 任务 1 |
| §1.5 预置主题保持 default | 任务 1（init 默认值覆盖，无需改 PresetThemes） |
| §2.1 Render 文件拆分（5 文件） | 任务 2 |
| §1.4 渲染管线应用 NSParagraphStyle | 任务 3 |
| §3.1 Core 注释补充 | 任务 4（步骤 1~3） |
| §3.2 Theme 注释补充 | 任务 4（步骤 4~6） |

### 2. 占位符扫描

无 TODO/待定。所有步骤包含完整代码或精确命令。

### 3. 类型一致性

- `ParagraphSpacing` 在任务 1 定义，任务 2 的 `BlockRenderer` 引用 `theme.paragraphSpacing`（任务 3 添加调用点）
- 任务 2 拆分出的函数全部使用 `internal` 可见性（去掉 `private`），任务 3 在 `BlockRenderer` 中修改 `renderBlock`
- `MarkupTheme.init` 参数顺序：`baseFont, headingScale, paragraphSpacing, tagStyles, mediaStrategy` — 全文一致
- `MarkupTheme.==` 比较 `paragraphSpacing` — 任务 1 包含
