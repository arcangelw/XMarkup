# XMarkupUI 视图层实现计划

> **面向 AI 代理的工作者：** 此计划在本会话中内联执行。

**目标：** 实现 `XMarkupUI` 可选 SPM 子模块，提供 iOS/macOS 的视图层增强渲染（hr 自适应、blockquote 竖线、AsyncMediaLoader 集成、macOS NSTextTable/NSTextBlock）。

**架构：** Package.swift 新增 `XMarkupUI` target，依赖 `XMarkup`。iOS 端使用 `UITextView` 子类 + 自定义 `NSLayoutManager`；macOS 端在 `XMarkupTextView` 条件编译中提供 `NSTextView` 扩展。

**技术栈：** iOS 15+ / macOS 12+, Swift, NSLayoutManager, NSTextAttachment, NSTextBlock (macOS)

---

## 文件结构

### 新建文件（全部在 `Sources/XMarkupUI/`）

| 文件 | 职责 | 优先级 |
|:--|:--|:--|
| `XMarkupUI.swift` | 模块入口，公开符号导出，`shared` 单例 | P0 |
| `XMarkupViewConfig.swift` | 全局配置模型 | P0 |
| `HorizontalRuleUpdater.swift` | hr 自适应宽度（更新 NSTextAttachment.bounds） | P0 |
| `AsyncMediaLoader+UI.swift` | AsyncMediaLoader → layoutManager 刷新 | P0 |
| `BlockquoteLayoutManager.swift` | iOS NSLayoutManager 子类，绘制 blockquote 左侧竖线 | P0 |
| `XMarkupTextView+iOS.swift` | iOS UITextView 子类，注入 BlockquoteLayoutManager + hr + 媒体 | P0 |
| `XMarkupLabel.swift` | iOS UILabel 子类 | P1 |
| `XMarkupTextView+macOS.swift` | macOS NSTextView 扩展 | P1 |
| `XMarkupBlockRenderer.swift` | macOS: NSTextBlock per-edge 增强 | P2 |
| `XMarkupTableRenderer.swift` | macOS: NSTextTable 原生表格渲染 | P2 |

### 修改文件

| 文件 | 改动 | 优先级 |
|:--|:--|:--|
| `Package.swift` | 新增 `XMarkupUI` target + product | P0 |

### 测试文件

| 文件 | 内容 | 优先级 |
|:--|:--|:--|
| `Tests/XMarkupUITests/XMarkupTextViewTests.swift` | hr 自适应、blockquote 竖线、媒体加载集成 | P0 |
| `Tests/XMarkupUITests/XMarkupLabelTests.swift` | hr 自适应 | P1 |
| `Tests/XMarkupUITests/XMarkupViewConfigTests.swift` | 配置默认值、序列化 | P0 |

---

## 任务

### 任务 1：Package.swift — 新增 XMarkupUI target (P0)

**文件：** 修改 `Package.swift`

- [ ] **步骤 1：修改 Package.swift**

```swift
.target(
    name: "XMarkupUI",
    dependencies: ["XMarkup"]
),
.product(
    name: "XMarkupUI",
    targets: ["XMarkupUI"]
),
```

添加到现有 `targets` 和 `products` 数组中。

- [ ] **步骤 2：创建 Source 目录**

```bash
mkdir -p Sources/XMarkupUI
mkdir -p Tests/XMarkupUITests
```

- [ ] **步骤 3：创建占位文件验证编译**

```swift
// Sources/XMarkupUI/XMarkupUI.swift
import Foundation
public struct XMarkupUI {
    public static let shared = XMarkupUI()
}
```

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

预期：Build complete

- [ ] **步骤 4：移除占位文件（后续任务逐文件创建）**

---

### 任务 2：XMarkupViewConfig 配置模型 (P0)

**文件：** 创建 `Sources/XMarkupUI/XMarkupViewConfig.swift`

- [ ] **步骤 1：编写配置结构体**

```swift
import Foundation

/// XMarkupUI 全局配置
public struct XMarkupViewConfig: Sendable {
    // hr 自适应
    public var hrMinWidth: CGFloat = 100

    // blockquote 左边框
    public var blockquoteBorderWidth: CGFloat = 3
    public var blockquoteBorderColor: XMColor = .systemGray
    /// 竖线相对缩进后文本起点的水平偏移（负值向左）
    public var blockquoteBorderOffset: CGFloat = -6

    // 异步媒体加载
    /// 加载文档后自动运行 AsyncMediaLoader
    public var enableMediaAutoLoad: Bool = true

    public init() {}
}
```

- [ ] **步骤 2：编译验证**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

预期：Build complete

---

### 任务 3：XMarkupUI 模块入口 (P0)

**文件：** 创建 `Sources/XMarkupUI/XMarkupUI.swift`

- [ ] **步骤 1：编写模块入口**

```swift
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// XMarkupUI 模块入口
public struct XMarkupUI {
    /// 共享实例
    public static let shared = XMarkupUI()

    /// 全局配置
    public var config: XMarkupViewConfig

    private init() {
        self.config = XMarkupViewConfig()
    }
}

// 公开符号导出（方便用户 `import XMarkupUI` 后直接访问）
@_exported import XMarkup
```

- [ ] **步骤 2：创建测试文件 `Tests/XMarkupUITests/XMarkupViewConfigTests.swift`**

```swift
import XCTest
@testable import XMarkupUI

final class XMarkupViewConfigTests: XCTestCase {
    func testDefaultValues() {
        let config = XMarkupViewConfig()
        XCTAssertEqual(config.hrMinWidth, 100)
        XCTAssertEqual(config.blockquoteBorderWidth, 3)
        XCTAssertTrue(config.enableMediaAutoLoad)
    }

    func testSharedInstance() {
        let instance = XMarkupUI.shared
        XCTAssertEqual(instance.config.hrMinWidth, 100)
    }

    func testConfigModifiable() {
        var config = XMarkupViewConfig()
        config.hrMinWidth = 200
        XCTAssertEqual(config.hrMinWidth, 200)
    }
}
```

- [ ] **步骤 3：运行测试**

```bash
swift test --target XMarkupUI 2>&1 | grep -E "passed|failed"
```

预期：3 tests passed

---

### 任务 4：HorizontalRuleUpdater — hr 自适应宽度 (P0)

**文件：** 创建 `Sources/XMarkupUI/HorizontalRuleUpdater.swift`

- [ ] **步骤 1：编写实现**

```swift
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// hr 分隔线自适应宽度
///
/// 在布局完成后调用，将 hr 的 NSTextAttachment.bounds 更新为容器宽度。
enum HorizontalRuleUpdater {

    /// 更新所有 hr attachment 的宽度
    /// - Parameters:
    ///   - textStorage: 文本存储对象
    ///   - containerWidth: 容器当前宽度（UILabel.bounds.width 或 NSTextContainer.size.width）
    ///   - minWidth: 最小宽度下限
    static func update(
        in textStorage: NSTextStorage,
        containerWidth: CGFloat,
        minWidth: CGFloat = 100
    ) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let blockKindKey = NSAttributedString.Key(XMarkupBlockKindKey.name)
        textStorage.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let attachment = value as? NSTextAttachment,
                  let kind = textStorage.attribute(blockKindKey, at: range.location) as? String,
                  kind == "horizontalRule" else { return }
            attachment.bounds.size.width = max(containerWidth, minWidth)
        }
    }
}
```

- [ ] **步骤 2：编写测试**

```swift
// 添加到 XMarkupViewConfigTests.swift
func testHorizontalRuleUpdater() {
    // 创建一个包含 NSTextAttachment 的 NSTextStorage
    let attachment = NSTextAttachment()
    attachment.bounds = CGRect(x: 0, y: 0, width: 300, height: 1)
    let attrString = NSMutableAttributedString(attachment: attachment)
    // 标记为 hr
    attrString.addAttribute(
        NSAttributedString.Key(XMarkupBlockKindKey.name),
        value: "horizontalRule",
        range: NSRange(location: 0, length: attrString.length)
    )
    let storage = NSTextStorage(attributedString: attrString)

    // 执行更新
    HorizontalRuleUpdater.update(in: storage, containerWidth: 200, minWidth: 50)
    let updatedAttachment = storage.attribute(.attachment, at: 0) as? NSTextAttachment
    XCTAssertEqual(updatedAttachment?.bounds.width, 200)
}
```

- [ ] **步骤 3：运行测试**

```bash
swift test --target XMarkupUI 2>&1 | grep -E "passed|failed"
```

预期：4 tests passed

---

### 任务 5：AsyncMediaLoader+UI — 媒体加载与视图刷新集成 (P0)

**文件：** 创建 `Sources/XMarkupUI/AsyncMediaLoader+UI.swift`

- [ ] **步骤 1：编写 AsyncMediaLoader extension**

```swift
import Foundation

extension AsyncMediaLoader {

    /// 加载附件并自动刷新 layoutManager
    /// - Parameters:
    ///   - nsAttr: 可变的富文本（将被修改 attachment images）
    ///   - layoutManager: 需要刷新的 layoutManager
    ///   - minHRWidth: hr 最小宽度
    ///   - completion: 所有加载完成后的回调
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString,
        layoutManager: NSLayoutManager?,
        minHRWidth: CGFloat = 100,
        completion: (() -> Void)? = nil
    ) {
        // 使用原有的 loadAttachments 方法
        // update 回调刷新指定区域，completion 回调最终刷新
        let originalUpdate: (Update) -> Void = { [weak layoutManager] event in
            guard case .updated(let range) = event else { return }
            layoutManager?.invalidateDisplay(for: range)
        }
        let originalCompletion: () -> Void = { [weak layoutManager, weak nsAttr] in
            guard let lm = layoutManager, let storage = nsAttr else {
                completion?()
                return
            }
            // hr 自适应
            HorizontalRuleUpdater.update(
                in: storage,
                containerWidth: lm.textContainers.first?.containerSize.width ?? minHRWidth,
                minWidth: minHRWidth
            )
            lm.invalidateLayout(
                for: NSRange(location: 0, length: storage.length)
            )
            completion?()
        }

        // 调用原有的 loadAttachments
        // 注意：这里调用的原始方法签名是 (in:update:completion:)
        // 由于原始方法在 Core 中定义，调用方式取决于实际签名
        loadAttachments(
            in: nsAttr,
            update: originalUpdate,
            completion: originalCompletion
        )
    }
}
```

> ⚠️ **注意：** 需要确认 `AsyncMediaLoader.loadAttachments()` 在 Core 中的确切签名。当前签名为 `(in: NSMutableAttributedString, update: @escaping @Sendable (Update) -> Void, completion: @escaping @Sendable () -> Void)`。此处 extension 不改变原始 API，仅包装 UI 集成逻辑。

---

### 任务 6：BlockquoteLayoutManager — blockquote 左侧竖线绘制 (P0)

**文件：** 创建 `Sources/XMarkupUI/BlockquoteLayoutManager.swift`

- [ ] **步骤 1：编写 NSLayoutManager 子类**

```swift
import Foundation

#if canImport(UIKit)
import UIKit

/// 自定义 NSLayoutManager，在背景绘制 blockquote 左侧竖线
///
/// 检测 `XMarkupBlockKindKey = "blockquote"` 段落，在段落左侧绘制竖线。
/// 多段落连续的 blockquote 会有一条连贯的竖线。
class BlockquoteLayoutManager: NSLayoutManager {
    /// 关联的 UI 配置（weak 防止循环引用）
    weak var markupConfig: XMarkupViewConfig?

    override func drawBackground(forGlyphRange glyphRange: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphRange, at: origin)
        guard let config = markupConfig,
              let textStorage,
              let container = textContainers.first else { return }

        let key = NSAttributedString.Key(XMarkupBlockKindKey.name)
        let charRange = characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        textStorage.enumerateAttribute(key, in: charRange) { value, subrange, _ in
            guard (value as? String) == "blockquote" else { return }

            let paraGlyphRange = glyphRange(forCharacterRange: subrange,
                                             actualCharacterRange: nil)
            let boundingRect = self.boundingRect(forGlyphRange: paraGlyphRange,
                                                  in: container)
            let firstLineRect = lineFragmentRect(forGlyphAt: paraGlyphRange.location,
                                                  effectiveRange: nil)

            let borderX = firstLineRect.minX + origin.x + config.blockquoteBorderOffset
            let borderRect = CGRect(
                x: borderX,
                y: boundingRect.minY + origin.y,
                width: config.blockquoteBorderWidth,
                height: max(boundingRect.height, firstLineRect.height)
            )

            config.blockquoteBorderColor.setFill()
            UIRectFill(borderRect)
        }
    }
}

#endif
```

- [ ] **步骤 2：编译验证**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

预期：Build complete

---

### 任务 7：XMarkupTextView iOS — UITextView 子类 (P0)

**文件：** 创建 `Sources/XMarkupUI/XMarkupTextView+iOS.swift`

- [ ] **步骤 1：编写 iOS XMarkupTextView**

```swift
import Foundation

#if canImport(UIKit) && !os(macOS)
import UIKit

/// XMarkup 标记文档的文本视图
///
/// 自动功能：
/// - 注入 BlockquoteLayoutManager 绘制 blockquote 左侧竖线
/// - 布局时更新 hr 分隔线宽度
/// - 可选运行 AsyncMediaLoader 异步加载图片
open class XMarkupTextView: UITextView {

    /// 可替换的媒体加载器（默认新建 AsyncMediaLoader）
    public var mediaLoader: AsyncMediaLoader?

    /// 加载 MarkupDocument
    /// - Parameters:
    ///   - document: 标记文档
    ///   - theme: 主题配置
    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let attr = document.render(theme: theme)
        let nsAttr = NSAttributedStringRenderer().render(attr)
        load(nsAttr: nsAttr)
    }

    /// 加载 NSAttributedString
    /// - Parameter nsAttr: 已渲染的富文本
    public func load(nsAttr: NSAttributedString) {
        guard let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }

        // 替换 layoutManager
        replaceLayoutManager()

        // 设置富文本（必须在替换 LM 之后）
        textStorage?.setAttributedString(mutable)

        // hr 自适应
        updateHRWidths()

        // 异步媒体加载
        loadMedia(mutable)
    }

    // MARK: - Private

    private func replaceLayoutManager() {
        guard let storage = textStorage,
              let container = textContainer else { return }

        // 移除旧的 layout manager
        for lm in storage.layoutManagers {
            storage.removeLayoutManager(lm)
        }

        // 创建并添加 BlockquoteLayoutManager
        let lm = BlockquoteLayoutManager()
        lm.markupConfig = XMarkupUI.shared.config
        storage.addLayoutManager(lm)
        container.replaceLayoutManager(lm)
    }

    private func updateHRWidths() {
        guard let storage = textStorage else { return }
        HorizontalRuleUpdater.update(
            in: storage,
            containerWidth: bounds.width,
            minWidth: XMarkupUI.shared.config.hrMinWidth
        )
    }

    private func loadMedia(_ nsAttr: NSMutableAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad else { return }

        // 先更新 hr 以适配当前宽度
        updateHRWidths()

        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(
            in: nsAttr,
            layoutManager: layoutManager,
            minHRWidth: XMarkupUI.shared.config.hrMinWidth
        )
    }
}

#endif
```

- [ ] **步骤 2：创建测试文件 `Tests/XMarkupUITests/XMarkupTextViewTests.swift`**

```swift
import XCTest
@testable import XMarkupUI

final class XMarkupTextViewTests: XCTestCase {

    func testTextViewCanBeCreated() {
        let tv = XMarkupTextView()
        XCTAssertNotNil(tv)
    }

    func testLoadSimpleDocument() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<p>Hello</p>")
        let doc = MarkupDocument.from(result)
        let tv = XMarkupTextView()
        tv.load(doc)
        let text = tv.text ?? ""
        XCTAssertTrue(text.contains("Hello"))
    }

    func testLoadWithBlockquote() throws {
        let parser = try XMarkupParser()
        let result = try parser.parse("<blockquote>Quote</blockquote>")
        let doc = MarkupDocument.from(result)
        let tv = XMarkupTextView()
        tv.load(doc)
        XCTAssertNotNil(tv.textStorage)
    }

    func testLayoutManagerIsBlockquoteLM() throws {
        let tv = XMarkupTextView()
        tv.load(NSAttributedString(string: "test"))
        XCTAssertTrue(tv.layoutManager is BlockquoteLayoutManager,
                      "layoutManager 应被替换为 BlockquoteLayoutManager")
    }
}
```

- [ ] **步骤 3：更新测试 target 配置**

```swift
// Package.swift 中的 test target
.testTarget(
    name: "XMarkupUITests",
    dependencies: ["XMarkupUI"]
),
```

- [ ] **步骤 4：运行测试**

```bash
swift test --target XMarkupUITests 2>&1 | grep -E "passed|failed"
```

预期：4 tests passed

---

### 任务 8：XMarkupLabel iOS — UILabel 子类 (P1)

**文件：** 创建 `Sources/XMarkupUI/XMarkupLabel.swift`

- [ ] **步骤 1：编写实现**

```swift
import Foundation

#if canImport(UIKit) && !os(macOS)
import UIKit

/// XMarkup 标记文档的标签视图
///
/// 支持 hr 自适应宽度和异步媒体加载。
/// UILabel 不提供 layoutManager 细粒度刷新，媒体加载后通过 setNeedsDisplay 整体刷新。
open class XMarkupLabel: UILabel {

    public var mediaLoader: AsyncMediaLoader?

    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let attr = document.render(theme: theme)
        let nsAttr = NSAttributedStringRenderer().render(attr)
        load(nsAttr: nsAttr)
    }

    public func load(nsAttr: NSAttributedString) {
        guard let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }
        attributedText = mutable
        loadMedia(mutable)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        // 更新 hr 宽度匹配当前 label 尺寸
        guard let textStorage = attributedText?.nbsp() else { return }
        HorizontalRuleUpdater.update(
            in: textStorage,
            containerWidth: bounds.width,
            minWidth: XMarkupUI.shared.config.hrMinWidth
        )
    }

    private func loadMedia(_ nsAttr: NSMutableAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad else { return }
        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(in: nsAttr,
            update: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.setNeedsDisplay()
                }
            },
            completion: nil
        )
    }
}

extension NSAttributedString {
    /// 创建 NSTextStorage，用于 hr 更新
    fileprivate func nbsp() -> NSTextStorage? {
        return NSTextStorage(attributedString: self)
    }
}

#endif
```

- [ ] **步骤 2：创建测试**

```swift
// 添加到 XMarkupUITests
func testLabelCanBeCreated() {
    let label = XMarkupLabel()
    XCTAssertNotNil(label)
}

func testLabelLoadSimpleDocument() throws {
    let parser = try XMarkupParser()
    let result = try parser.parse("<p>Hello</p>")
    let doc = MarkupDocument.from(result)
    let label = XMarkupLabel()
    label.load(doc)
    XCTAssertTrue(label.text?.contains("Hello") == true)
}
```

---

### 任务 9：XMarkupTextView macOS — NSTextView 扩展 (P1)

**文件：** 创建 `Sources/XMarkupUI/XMarkupTextView+macOS.swift`

- [ ] **步骤 1：编写 macOS 扩展**

```swift
import Foundation

#if os(macOS)
import AppKit

/// macOS 上 XMarkupTextView 作为 NSTextView 的别名
extension XMarkupTextView {

    public var mediaLoader: AsyncMediaLoader?

    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let attr = document.render(theme: theme)
        let nsAttr = NSAttributedStringRenderer().render(attr)
        textStorage?.setAttributedString(nsAttr)
        loadMedia(nsAttr)
    }

    private func loadMedia(_ nsAttr: NSAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad,
              let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }
        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(
            in: mutable,
            layoutManager: layoutManager,
            minHRWidth: XMarkupUI.shared.config.hrMinWidth
        )
    }
}

#endif
```

> ⚠️ **macOS 编译提示：** 需要在文件顶部 `#if os(macOS)` 条件中声明 `XMarkupTextView` 为 NSTextView 的类型别名，或在 `XMarkupTextView+iOS.swift` 中用 `#if canImport(UIKit) && !os(macOS)` 隔离 iOS 路径。

---

### 任务 10：XMarkupBlockRenderer macOS — NSTextBlock 增强 (P2)

**文件：** 创建 `Sources/XMarkupUI/XMarkupBlockRenderer.swift`

```swift
import Foundation

#if os(macOS)
import AppKit

/// macOS 专用：将 BlockStyleConfiguration 渲染为 NSTextBlock
///
/// 读取 MarkupTheme.blockStyles，为 blockquote/pre 等元素添加全宽背景色和 per-edge 边框。
/// iOS 不可用（NSTextBlock 不存在于 UIKit）。
struct XMarkupBlockRenderer {

    static func applyBlockStyle(
        kind: BlockKind,
        theme: MarkupTheme,
        to paragraphStyle: NSMutableParagraphStyle
    ) {
        guard let key = blockStyleKey(for: kind),
              let config = theme.blockStyles[key] else { return }

        let hasBlockProps = config.backgroundColor != nil || config.borderLeading != nil
        guard hasBlockProps else { return }

        let block = NSTextBlock()
        if let bg = config.backgroundColor, let color = ColorParser.parse(bg) {
            block.backgroundColor = color
        }
        if let border = config.borderLeading, let color = ColorParser.parse(border.color) {
            block.setBorderColor(color, for: .minX)
            block.setWidth(border.width, type: .absoluteValueType, for: .border, edge: .minX)
        }
        paragraphStyle.textBlocks = [block]
    }
}

#endif
```

---

### 任务 11：XMarkupTableRenderer macOS — NSTextTable 表格 (P2)

**文件：** 创建 `Sources/XMarkupUI/XMarkupTableRenderer.swift`

```swift
import Foundation

#if os(macOS)
import AppKit

/// macOS 专用：使用 NSTextTable 原生渲染表格
///
/// 替换 Core 的纯文本 fallback（A | B），提供真正带列宽控制、边框和背景的原生表格。
struct XMarkupTableRenderer {

    static func renderTable(
        _ structure: TableStructure,
        theme: MarkupTheme
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let textTable = NSTextTable()
        textTable.columnCount = max(structure.columnCount, 1)

        if let tableConfig = theme.blockStyles[.table] {
            textTable.collapsesBorders = tableConfig.collapsesBorders ?? true
        }

        for (rowIdx, row) in structure.rows.enumerated() {
            for (colIdx, cell) in row.enumerated() {
                let cellBlock = NSTextTableBlock(
                    table: textTable,
                    startingRow: rowIdx,
                    rowSpan: 1,
                    startingColumn: colIdx,
                    columnSpan: 1
                )
                applyCellStyle(cellBlock, cell: cell, theme: theme)

                let paraStyle = NSMutableParagraphStyle()
                paraStyle.textBlocks = [cellBlock]

                let cellAttr = NSMutableAttributedString(string: cell.text)
                if cell.text.utf16.count > 0 {
                    cellAttr.addAttribute(.paragraphStyle, value: paraStyle,
                                           range: NSRange(location: 0, length: cell.text.utf16.count))
                }
                if rowIdx > 0 || colIdx > 0 {
                    result.append(NSAttributedString(string: "\n"))
                }
                result.append(cellAttr)
            }
        }
        return result
    }

    private static func applyCellStyle(
        _ block: NSTextTableBlock,
        cell: MarkupBlock,
        theme: MarkupTheme
    ) {
        let cellKey: TagStyleKey = cell.kind == .tableHeader ? .tableHeader : .tableCell
        guard let config = theme.blockStyles[cellKey] else { return }
        if let bg = config.backgroundColor, let color = ColorParser.parse(bg) {
            block.backgroundColor = color
        }
    }
}

#endif
```

---

## 验证步骤

```bash
# 全量构建
swift build 2>&1 | grep -E "error:|Build complete"

# 全量测试
swift test 2>&1 | tail -5
```

预期输出：
```
Build complete!
Executed N tests, with 0 failures
```
