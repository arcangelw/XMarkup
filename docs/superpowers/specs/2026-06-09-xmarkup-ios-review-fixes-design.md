# XMarkup iOS Code Review 收尾修复

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:writing-plans` 创建实现计划。

**目标：** 修复 Code Review 发现的 8 项实现问题，完成源码和测试的子目录迁移，补充注释规范，同步更新规格文档。

**架构：** 纯代码修复 + 文件迁移 + 文档同步，不涉及新功能。

**技术栈：** Swift 6 / SPM / XCTest

---

## 1. 代码修复

### 1.1 `MarkupTheme` 补全 `Equatable`（必须修复）

**文件：** `Theme/MarkupTheme.swift`

**问题：** 手动实现了 `==` 但未声明 `Equatable` 协议，且 `==` 遗漏了 `mediaStrategy`。`mediaStrategy` 包含闭包（`.imageProvider` / `.customAttachment`），闭包不可比较。

**方案：**
- 声明 `Equatable` 协议
- `==` 比较 `baseFont` + `headingScale` + `tagStyles`，显式排除 `mediaStrategy`
- 添加注释说明排除原因

### 1.2 `convertToInlines` 修正 trimmedEnd 计算（必须修复）

**文件：** `Core/MarkupDocumentBuilder.swift:172`

**问题：** `trimmedEnd` 对整个 `text` 做尾部换行修剪，当多个块级 span 共享同一份 `text` 时，最后一个块之前的块也可能被错误截断。

**方案：**
- 对 `parentRange` 范围内的文本做尾部换行判断
- 用 `NSString.substring(with: parentRange)` 提取块内文本，计算实际 trimmedEnd

### 1.3 `applyInlineAttributes` 添加安全断言（必须修复）

**文件：** `Rendering/MarkupDocument+Render.swift:138-144`

**问题：** 隐式假设 `AttributedString` 的 character index 与 `String` 的 character index 一致，未做验证。

**方案：**
- 添加注释说明 `AttributedString.Character == String.Character`（grapheme cluster）的假设依据
- 在 `#if DEBUG` 下添加 assert 校验 offset 一致性

### 1.4 `convertToInlines` 处理部分重叠 span（建议修改）

**文件：** `Core/MarkupDocumentBuilder.swift:150-153`

**问题：** span 起始在 `parentRange` 内但尾部超出时直接跳过，丢失了有效数据。

**方案：**
- 改为截断重叠部分：`min(spanEnd, parentEnd) - spanStart`
- 仅当截断后 length ≤ 0 时才跳过

### 1.5 `HeadingScale` 默认值添加来源注释（建议修改）

**文件：** `Theme/HeadingScale.swift`

**问题：** 默认缩放系数未注释来源。

**方案：** 在 init 参数和 `default` 静态属性上添加注释，注明来源为 Chrome/Firefox/Safari 浏览器默认样式表 h1-h6 缩放比例。

### 1.6 `.dark` 主题添加占位说明（建议修改）

**文件：** `Theme/PresetThemes.swift`

**问题：** `.dark` 主题与 `.default` 差异化不足，可能误导用户。

**方案：** 在 `.dark` 计算属性上添加注释，说明当前为静态颜色占位，完整的暗色适配应使用 `UIColor(dynamicProvider:)` 动态颜色，待 P2 实现。

### 1.7 `NSAttributedStringRenderer` 消除多余复制（建议修改）

**文件：** `Rendering/NSAttributedStringRenderer.swift:16-18`

**问题：** `NSAttributedString(attributedString: nsAttr)` 做了一次不必要的不可变化复制。

**方案：** 直接 `return nsAttr`（`NSMutableAttributedString` 可安全作为 `NSAttributedString` 返回）。

### 1.8 规格文档同步 `MarkupInline.range` 类型变更（建议修改）

**文件：** `docs/superpowers/specs/2026-06-08-xmarkup-modern-swift-redesign.md`

**问题：** 规格中 `MarkupInline.range` 类型为 `Range<String.Index>`，实际实现为 `NSRange`（为修复 emoji range 问题而改）。

**方案：** 更新规格文档 §3.1 中 `MarkupInline` 的定义，将 `range` 类型改为 `NSRange`，并添加注释说明变更原因（UTF-16 对齐）。

---

## 2. 目录结构迁移

### 2.1 源码迁移

将根目录的 8 个 Bridge 层文件迁移到 `Bridge/` 子目录：

```
Sources/XMarkup/
├── ColorParser.swift          → Bridge/ColorParser.swift
├── PlatformTypes.swift        → Bridge/PlatformTypes.swift
├── XMarkupError.swift         → Bridge/XMarkupError.swift
├── XMarkupParser.swift        → Bridge/XMarkupParser.swift
├── XMarkupResult.swift        → Bridge/XMarkupResult.swift
├── XMarkupSpan.swift          → Bridge/XMarkupSpan.swift
├── XMarkupStyle.swift         → Bridge/XMarkupStyle.swift
├── XMarkupTag.swift           → Bridge/XMarkupTag.swift
```

### 2.2 测试迁移

将根目录的 5 个测试文件迁移到对应子目录：

```
Tests/XMarkupTests/
├── XMarkupParserTests.swift   → Bridge/XMarkupParserTests.swift
├── XMarkupResultTests.swift   → Bridge/XMarkupResultTests.swift
├── ColorParserTests.swift     → Bridge/ColorParserTests.swift
├── CrossPlatformTests.swift   → Bridge/CrossPlatformTests.swift
└── Theme/
    └── MarkupThemeTests.swift ← 从根目录迁入（新建 Theme/ 子目录）
```

### 2.3 迁移后目录结构

```
Sources/XMarkup/
├── Bridge/
│   ├── ColorParser.swift
│   ├── PlatformTypes.swift
│   ├── XMarkupError.swift
│   ├── XMarkupParser.swift
│   ├── XMarkupResult.swift
│   ├── XMarkupSpan.swift
│   ├── XMarkupStyle.swift
│   └── XMarkupTag.swift
├── Core/
│   ├── BlockKind.swift
│   ├── MarkupAttachment.swift
│   ├── MarkupBlock.swift
│   ├── MarkupDocument.swift
│   ├── MarkupDocumentBuilder.swift
│   └── MarkupInline.swift
├── Theme/
│   ├── HeadingScale.swift
│   ├── MarkupTheme.swift
│   ├── MarkupThemeBuilder.swift
│   ├── MediaRenderingStrategy.swift
│   ├── PresetThemes.swift
│   ├── TagStyleKey.swift
│   └── ThemeComponent.swift
├── Attributes/
│   └── XMarkupScope.swift
└── Rendering/
    ├── MarkupDocument+Render.swift
    ├── MarkupRenderer.swift
    └── NSAttributedStringRenderer.swift

Tests/XMarkupTests/
├── Bridge/
│   ├── XMarkupParserTests.swift
│   ├── XMarkupResultTests.swift
│   ├── ColorParserTests.swift
│   └── CrossPlatformTests.swift
├── Core/
│   ├── BlockKindTests.swift
│   ├── MarkupAttachmentTests.swift
│   ├── MarkupBlockTests.swift
│   ├── MarkupDocumentBuilderTests.swift
│   ├── MarkupDocumentTests.swift
│   └── MarkupInlineTests.swift
├── Theme/
│   └── MarkupThemeTests.swift
├── Attributes/
│   └── XMarkupScopeTests.swift
└── Rendering/
    ├── NSAttributedStringRendererTests.swift
    └── RenderTests.swift
```

---

## 3. 注释补充

### 3.1 枚举 case 注释

**文件：** `Core/MarkupInline.swift`、`Core/BlockKind.swift`

为 `InlineKind` 和 `BlockKind` 的每个 case 添加 HTML 标签来源注释：

```swift
case bold              // <b> 或 <strong>
case italic            // <i> 或 <em>
case underline         // <u>
case strikethrough     // <s>、<strike> 或 <del>
case code              // <code>
case mark              // <mark>
case link(url: String) // <a href="...">
case subscriptText     // <sub>
case superscript       // <sup>
case span(styles:)     // <span style="...">
```

### 3.2 公开 API 使用示例

为以下类型补充 `///` 文档注释中的使用示例（` ```swift ` 代码块）：

- `MarkupDocument` — 构建和渲染示例
- `MarkupBlock` — 数据结构说明
- `MarkupTheme` — 自定义主题示例
- `MarkupRenderer` — 渲染器使用示例

### 3.3 `ColorParser` 格式说明

**文件：** `Bridge/ColorParser.swift`

在文档注释中明确支持的格式（`#RRGGBB`）和不支持的格式（`#RGB` 三位缩写、`rgb()` 函数、命名颜色）。

---

## 4. 文档更新

### 4.1 规格文档

**文件：** `docs/superpowers/specs/2026-06-08-xmarkup-modern-swift-redesign.md`

更新内容：
- §3.1 `MarkupInline.range` 类型从 `Range<String.Index>` 改为 `NSRange`，添加变更原因
- §9.2 目录结构更新为迁移后的实际结构

### 4.2 项目记忆

**文件：** `~/.claude/projects/-Users-arcangelw-GitHub-XMarkup/memory/MEMORY.md` 及相关文件

更新进度记录，标记 Code Review 修复完成。

---

## 5. 设计决策

| # | 决策 | 方案 | 理由 |
|---|------|------|------|
| 1 | MarkupTheme Equatable | 排除 mediaStrategy | 闭包不可比较，用户关心的是样式配置项 |
| 2 | XMarkupSpan/XMarkupStyle 可见性 | 保持 public + 文档标注 | 保留原始数据层访问能力 |
| 3 | 目录迁移范围 | 源码 + 测试一起迁移 | 一次性到位，避免后续重复操作 |
| 4 | MarkupInline.range 类型 | 保持 NSRange + 更新规格 | UTF-16 对齐已验证，回退无收益 |
