# XMarkup iOS 段落排版 + Render 拆分 + 注释补充

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:writing-plans` 创建实现计划。

**目标：** 为 MarkupTheme 添加段落间距和行间距配置，拆分 556 行的 MarkupDocument+Render.swift 为 5 个职责单一的文件，补充 Core/Theme 模块缺失的文档注释。

**架构：** 在 MarkupTheme 中新增 ParagraphSpacing 配置，通过 NSParagraphStyle 应用于每个 block 的 AttributedString。拆分 Render 文件但不改变公开 API。注释补充遵循规格 §7.3 标准。

**技术栈：** Swift 6 / AttributedString + NSParagraphStyle / SPM

---

## 1. 段落排版配置

### 1.1 ParagraphSpacing 结构体

新建 `Theme/ParagraphSpacing.swift`：

```swift
/// 段落排版配置
///
/// 控制 block 之间的纵向间距和 block 内部的行间距。
/// 通过 NSParagraphStyle 应用于 AttributedString。
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

### 1.2 MarkupTheme 新增字段

在 `MarkupTheme` 中新增 `paragraphSpacing` 字段，位于 `headingScale` 之后：

```swift
public struct MarkupTheme: @unchecked Sendable, Equatable {
    public var baseFont: XMFont
    public var headingScale: HeadingScale
    public var paragraphSpacing: ParagraphSpacing   // 新增
    public var tagStyles: [TagStyleKey: AttributeContainer]
    public var mediaStrategy: MediaRenderingStrategy
    ...
}
```

`Equatable.==` 包含 `paragraphSpacing` 比较。

### 1.3 Theme DSL 组件

新建 `ParagraphSpacingComponent`：

```swift
public struct ParagraphSpacingComponent: ThemeComponent {
    public let spacing: ParagraphSpacing
    public init(_ spacing: ParagraphSpacing) { ... }
    public func apply(to theme: inout MarkupTheme) { ... }
}

/// 便利函数
public func ParagraphSpacing(
    spacingBefore: CGFloat = 8,
    spacingAfter: CGFloat = 8,
    lineSpacing: CGFloat = 0
) -> ParagraphSpacingComponent { ... }
```

### 1.4 渲染管线应用

在 `renderBlock` 方法中，为每个 block 的 `baseAttributes` 设置 `NSParagraphStyle`：

```swift
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.paragraphSpacingBefore = theme.paragraphSpacing.spacingBefore
paragraphStyle.paragraphSpacing = theme.paragraphSpacing.spacingAfter
paragraphStyle.lineSpacing = theme.paragraphSpacing.lineSpacing
baseAttributes.uiKit.paragraphStyle = paragraphStyle  // 或 appKit
```

注意：`render(theme:)` 中块间 `\n` 分隔符仍保留（用于文本分段），视觉间距由 `NSParagraphStyle` 控制。

### 1.5 预置主题更新

各预置主题的段落间距保持 `default`（8/8/0），用户可自定义。

---

## 2. Render 文件拆分

### 2.1 拆分方案

当前 `MarkupDocument+Render.swift`（556 行）拆为 5 个文件：

| 文件 | 预估行数 | 职责 | 提取的函数 |
|------|----------|------|-----------|
| `MarkupDocument+Render.swift` | ~50 | 公开入口 + 块拼接 | `render(theme:)` |
| `BlockRenderer.swift` | ~180 | 块级渲染 + 段落排版 | `renderBlock`, `applyBlockKindAttributes`, `applyThemeOverrides`, `mergeAttributeContainer` |
| `InlineRenderer.swift` | ~150 | 内联渲染 + 字体 trait | `applyInlineAttributes`, `applyFontTrait`, `applyInlineStyle` |
| `AttachmentRenderer.swift` | ~120 | 附件渲染 + 占位图 | `renderAttachmentBlock`, `createPlaceholderAttachment`, `createPlaceholderImage` |
| `RenderHelpers.swift` | ~60 | name mapping + 工具 | `blockKindName`, `inlineKindName`, `blockStyleKey`, `inlineStyleKey`, `extractSrc`, `srcIdentifier`, `traitBold`, `traitItalic` |

所有文件放在 `platforms/ios/Sources/XMarkup/Rendering/` 目录。

### 2.2 可见性

- 拆出的函数保持 `internal`（模块内可见），因为 `MarkupDocument+Render.swift` 需要调用
- 不改变任何公开 API
- `private` 改为 `internal`（跨文件需要模块内可见）

### 2.3 SPM 兼容性

SPM 递归扫描 `Rendering/` 目录下所有 `.swift` 文件，无需修改 `Package.swift`。

---

## 3. 注释补充

### 3.1 需补充的 Core 文件

| 文件 | 缺失项 |
|------|--------|
| `BlockKind.swift` | `Level` 枚举缺少文档注释和 case 注释；`TableStructure` 缺少使用说明 |
| `MarkupAttachment.swift` | `MarkupAttachment` 缺少 API 使用示例；`AttachmentContent` 缺少 case 注释；`AttachmentAlignment` 缺少 case 注释 |
| `MarkupInline.swift` | `MarkupInline` 缺少 API 使用示例 |

### 3.2 需补充的 Theme 文件

| 文件 | 缺失项 |
|------|--------|
| `MarkupTheme.swift` | 补充包含 `paragraphSpacing` 的完整使用示例 |
| `MediaRenderingStrategy.swift` | 各 case 缺少使用场景说明 |
| `MarkupThemeBuilder.swift` | 缺少 DSL 使用示例 |
| `TagStyleKey.swift` | 缺少文档注释和 case 含义说明 |
| `ThemeComponent.swift` | `BaseFont`/`HeadingScaleComponent`/`TagStyleComponent`/`MediaComponent` 缺少使用示例 |

### 3.3 注释规范

遵循规格 §7.3 标准：
- 公开 API 必须包含 `///` 文档注释
- 枚举 case 必须有关联 HTML 标签或用途注释
- 复杂类型必须包含 `` ```swift `` 使用示例
- 注释语言为中文，技术术语保留英文

---

## 4. 文件变更汇总

| 操作 | 文件 | 说明 |
|------|------|------|
| 新建 | `Theme/ParagraphSpacing.swift` | 段落排版配置 |
| 新建 | `Rendering/BlockRenderer.swift` | 块级渲染 |
| 新建 | `Rendering/InlineRenderer.swift` | 内联渲染 |
| 新建 | `Rendering/AttachmentRenderer.swift` | 附件渲染 |
| 新建 | `Rendering/RenderHelpers.swift` | 渲染辅助函数 |
| 修改 | `Theme/MarkupTheme.swift` | 新增 paragraphSpacing 字段 |
| 修改 | `Theme/ThemeComponent.swift` | 新增 ParagraphSpacingComponent |
| 修改 | `Theme/PresetThemes.swift` | 预置主题保持 default |
| 重写 | `Rendering/MarkupDocument+Render.swift` | 精简为入口方法 |
| 修改 | `Core/BlockKind.swift` | 注释补充 |
| 修改 | `Core/MarkupAttachment.swift` | 注释补充 |
| 修改 | `Core/MarkupInline.swift` | 注释补充 |
| 修改 | `Theme/MediaRenderingStrategy.swift` | 注释补充 |
| 修改 | `Theme/MarkupThemeBuilder.swift` | 注释补充 |
| 修改 | `Theme/TagStyleKey.swift` | 注释补充 |
| 新建 | `Tests/.../ParagraphSpacingTests.swift` | 段落排版测试 |
| 新建 | `Tests/.../RenderSplitTests.swift` | 拆分后功能回归测试 |
