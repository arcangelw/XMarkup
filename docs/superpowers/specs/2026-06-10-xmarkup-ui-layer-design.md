# XMarkupUI 可选视图渲染层设计

> **目标：** 为 XMarkupCore 生成的 AttributedString 提供可选的视图层增强渲染。保留 Core 的纯数据职责，UI 层选择性增强。
>
> **架构：** 独立 SPM 子模块 `XMarkupUI`，依赖 `XMarkup`。iOS 提供 UITextView/UILabel 子类 + 自定义 NSLayoutManager 绘制引擎；macOS 提供 NSTextView 子类 + NSTextBlock/NSTextTable 原生渲染。
>
> **技术栈：** iOS 15+ / macOS 12+, Swift, NSLayoutManager, NSTextAttachmentViewProvider, NSTextBlock (macOS), NSTextTable (macOS)

---

## 1. 模块依赖

```
XMarkupUI → 依赖 → XMarkup
```

- `XMarkupUI` 是 `XMarkup` SPM 包内的一个子 target
- 不 import 则无开销
- 第三方库可以只依赖 `XMarkup`（Core），自行实现视图层

### SwiftPM 配置

```swift
.target(
    name: "XMarkupUI",
    dependencies: ["XMarkup"]
),
.product(
    name: "XMarkupUI",
    targets: ["XMarkupUI"]
)
```

---

## 2. 文件结构

```
Sources/XMarkupUI/
│
├── XMarkupUI.swift                       // 公开符号汇总
│
├── XMarkupTextView.swift                 // [iOS] UITextView 子类
│   ├── 自动加载 XMarkupTheme
│   ├── 注入 BlockquoteLayoutManager
│   └── 布局周期更新 hr 宽度
│
├── XMarkupLabel.swift                    // [iOS] UILabel 子类
│   └── layoutSubviews 更新 hr 宽度
│
├── BlockquoteLayoutManager.swift         // [iOS] NSLayoutManager 子类
│   └── drawBackground(forGlyphRange:at:) 绘制 blockquote 左侧竖线
│
├── HorizontalRuleUpdater.swift             // [iOS/macOS] hr 自适应宽度
│   └── updateHRAttachmentBounds(in:containerWidth:)
│
├── XMarkupViewConfig.swift              // 全局配置
│   ├── hrMinWidth
│   ├── blockquoteBorderWidth / color / offset
│   ├── enableMediaAutoLoad
│   └── enableTableRendering (macOS)
│
├── HorizontalRuleUpdater.swift          // hr 自适应宽度
│   └── updateAttachmentBounds(in:containerWidth:)
│
├── BlockquoteLayoutManager.swift        // [iOS] NSLayoutManager 子类
│   └── drawBackground(forGlyphRange:at:) 绘制 blockquote 左侧竖线
│
├── AsyncMediaLoader+UI.swift           // AsyncMediaLoader → layoutManager 刷新
│
├── XMarkupTextView.swift               // [iOS/macOS] 文本视图
│   ├── iOS: UITextView 子类
│   └── macOS: NSTextView 子类 (#if os(macOS))
│
├── XMarkupLabel.swift                  // [iOS] UILabel 子类
    
│   │
└── macOS/
    ├── XMarkupTableRenderer.swift       // [macOS] NSTextTable 表格渲染
    └── XMarkupBlockRenderer.swift       // [macOS] NSTextBlock per-edge 增强
```

---

## 3. 核心组件

### 3.1 XMarkupTextView（iOS）

```swift
open class XMarkupTextView: UITextView {

    public var mediaLoader: AsyncMediaLoader?

    /// 加载 MarkupDocument
    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let attr = document.render(theme: theme)
        let nsAttr = NSAttributedStringRenderer().render(attr)
        load(nsAttr: nsAttr)
    }

    /// 加载 NSAttributedString
    public func load(nsAttr: NSAttributedString) {
        // 1. 设置富文本
        guard let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }
        attributedText = mutable

        // 2. 注入 BlockquoteLayoutManager
        replaceLayoutManager()

        // 3. 注册 hr 自适应
        updateHRAttachmentWidths()

        // 4. 异步加载媒体附件
        loadMediaAttachments(mutable)
    }

    /// 异步加载附件：替换占位图为实际图片
    private func loadMediaAttachments(_ nsAttr: NSMutableAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad else { return }
        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(in: nsAttr,
            update: { [weak self] event in
                guard let self else { return }
                switch event {
                case .updated(let range):
                    // 刷新受影响区域的显示
                    self.layoutManager.invalidateDisplay(for: range)
                case .failed(_, _):
                    break
                case .completed:
                    break
                }
            },
            completion: { [weak self] in
                // 所有图片加载完成后刷新布局
                self?.layoutManager.invalidateLayout(
                    for: NSRange(location: 0, length: self?.textStorage.length ?? 0)
                )
            }
        )
    }

    private func replaceLayoutManager() {
        let storage = textStorage
        let container = textContainer

        // 移除旧的 layout manager
        if let oldLM = storage?.layoutManagers.first {
            storage?.removeLayoutManager(oldLM)
        }
        // 创建并添加 BlockquoteLayoutManager
        let lm = BlockquoteLayoutManager()
        lm.markupConfig = XMarkupUI.shared.config
        storage?.addLayoutManager(lm)
        container.replaceLayoutManager(lm)
    }

    private func updateHRAttachmentWidths() {
        guard let textStorage else { return }
        HorizontalRuleUpdater.update(
            in: textStorage,
            containerWidth: bounds.width
        )
    }
}
```

### 3.2 XMarkupLabel（iOS）

```swift
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
        loadMediaAttachments(mutable)
    }

    private func loadMediaAttachments(_ nsAttr: NSMutableAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad else { return }
        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(in: nsAttr,
            update: { [weak self] _ in
                // UILabel 只能整体刷新
                DispatchQueue.main.async {
                    self?.setNeedsDisplay()
                }
            },
            completion: nil
        )
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        guard let text else { return }
        HorizontalRuleUpdater.update(in: text, containerWidth: bounds.width)
    }
}
```

### 3.3 BlockquoteLayoutManager（iOS）

NSLayoutManager 子类，在 `drawBackground(forGlyphRange:at:)` 中检测 `XMarkupBlockKindKey = "blockquote"`，用 Core Graphics 绘制左侧竖线。

```swift
class BlockquoteLayoutManager: NSLayoutManager {
    weak var markupConfig: XMarkupViewConfig?

    override func drawBackground(forGlyphRange glyphRange: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphRange, at: origin)
        guard let config = markupConfig,
              let textStorage,
              let container = textContainers.first else { return }

        let charRange = characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let key = NSAttributedString.Key(XMarkupBlockKindKey.name)

        textStorage.enumerateAttribute(key, in: charRange) { value, subrange, _ in
            guard (value as? String) == "blockquote" else { return }

            let paraGlyphRange = glyphRange(forCharacterRange: subrange, actualCharacterRange: nil)
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
```

关键行为：
- 竖线从第一行顶部延伸到整个段落范围的底部
- 多段落 blockquote 自动连续竖线
- 位置相对于缩进后的文本起始位置偏移 `borderOffset`
- 通过 `markupConfig` 获取自定义尺寸和颜色

### 3.4 HorizontalRuleUpdater（iOS/macOS）

```swift
enum HorizontalRuleUpdater {
    static func update(in textStorage: NSTextStorage,
                       containerWidth: CGFloat,
                       minWidth: CGFloat = 100) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let blockKindKey = NSAttributedString.Key(XMarkupBlockKindKey.name)
        textStorage.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let attachment = value as? NSTextAttachment,
                  let kind = textStorage.attribute(blockKindKey, at: range.location) as? String,
                  kind == "horizontalRule" else { return }
            // 更新宽度为容器宽度，至少 minWidth
            attachment.bounds.size.width = max(containerWidth, minWidth)
        }
    }
}
```

---

### 3.5 AsyncMediaLoader+UI（iOS/macOS）

在 `load(nsAttr:)` 中集成 `AsyncMediaLoader`：

- `.updated(range:)`: 调用 `layoutManager.invalidateDisplay(for:)` 刷新指定区域
- `.completed`: 调用 `layoutManager.invalidateLayout(for:)` 触发最终布局
- `enableMediaAutoLoad` 关闭时跳过

```swift
enum MediaLoadHelper {
    /// 异步加载附件，返回后自动刷新 layoutManager
    static func load(
        in nsAttr: NSMutableAttributedString,
        layoutManager: NSLayoutManager?,
        loader: AsyncMediaLoader? = nil
    ) {
        let l = loader ?? AsyncMediaLoader()
        l.loadAttachments(in: nsAttr,
            update: { event in
                guard case .updated(let range) = event else { return }
                layoutManager?.invalidateDisplay(for: range)
            },
            completion: {
                let full = NSRange(location: 0, length: nsAttr.length)
                layoutManager?.invalidateLayout(for: full)
            }
        )
    }
}
```

各视图的 `load(nsAttr:)` 仅在 `config.enableMediaAutoLoad == true` 时调用此辅助方法。

---

## 4. macOS 专用渲染

### 4.1 macOS XMarkupTextView

`XMarkupTextView` 通过 `#if os(macOS)` 条件编译适配 macOS NSTextView：

```swift
#if os(macOS)
extension XMarkupTextView {  // XMarkupTextView == NSTextView on macOS

    public var mediaLoader: AsyncMediaLoader?

    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let attr = document.render(theme: theme)
        let nsAttr = NSAttributedStringRenderer().render(attr)
        textStorage?.setAttributedString(nsAttr)
        applyBlockStyleEnhancements(theme: theme)
        loadMediaAttachments(nsAttr)
    }

    private func loadMediaAttachments(_ nsAttr: NSAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad,
              let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }
        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(in: mutable,
            update: { [weak self] event in
                guard let self else { return }
                if case .updated(let range) = event {
                    self.layoutManager?.invalidateDisplay(for: range)
                }
            },
            completion: { [weak self] in
                self?.layoutManager?.invalidateLayout(
                    for: NSRange(location: 0, length: self?.textStorage?.length ?? 0)
                )
            }
        )
    }
}
#endif
```

### 4.2 macOS 专用渲染器

#### XMarkupBlockRenderer

读取 `MarkupTheme.blockStyles`，用 AppKit 的 `NSTextBlock` 实现 pre/blockquote 的全宽背景和 per-edge 边框。

#### XMarkupTableRenderer

在 macOS 上利用 AppKit 独有的 `NSTextTable` 渲染表格：

```swift
func renderTable(_ structure: TableStructure,
                  theme: MarkupTheme) -> NSAttributedString {
    let textTable = NSTextTable()
    textTable.columnCount = max(structure.columnCount, 1)
    // ... NSTextTableBlock per cell, 原生表格渲染
}
```

---

## 5. 配置项

```swift
public struct XMarkupViewConfig: Sendable {
    // hr 自适应
    public var hrMinWidth: CGFloat = 100

    // blockquote 左边框
    public var blockquoteBorderWidth: CGFloat = 3
    public var blockquoteBorderColor: XMColor = .systemGray
    /// 竖线相对缩进后文本起点偏移（负值向左偏移）
    public var blockquoteBorderOffset: CGFloat = -6

    // 异步媒体加载
    /// 加载文档后自动运行 AsyncMediaLoader 下载附件图片
    public var enableMediaAutoLoad: Bool = true

    // macOS 表格
    public var enableTableRendering: Bool = false // 默认纯文本
}
```

---

## 6. 与 Core 的协同

### 已经完成（不需要 UI 层额外做的）

| 功能 | 位置 | 状态 |
|:--|:--|:--|
| 列表（NSTextList） | Core NSTextList | ✅ 已实现 |
| blockquote 缩进 12pt | Core NSParagraphStyle | ✅ 可配置 |
| hr NSTextAttachment | Core 矢量线 | ✅ 已实现 |
| 表格解析 + 文本近似 | Core TableRenderer | ✅ 已实现 |
| inlinePresentationIntent | Core InlineRenderer | ✅ 已实现 |

### UI 层新增能力

| 功能 | iOS | macOS |
|:--|:--|:--|
| hr 自适应宽度 | XMarkupTextView/Label | XMarkupTextView (macOS) |
| blockquote 左边框竖线 | BlockquoteLayoutManager | NSTextBlock per-edge |
| 表格原生渲染 | 留空（YAGNI） | NSTextTable |
| blockquote/pre 全宽背景 | 留空 | NSTextBlock.backgroundColor |

---

## 7. 非目标（明确不做的）

- ❌ 自定义字体注册/下载
- ❌ 图片缓存/下载（由 AsyncMediaLoader 提供）
- ❌ 链接长按/点击交互代理
- ❌ iOS 表格的 NSTextAttachmentViewProvider 实现（复杂度与价值不符）
- ❌ 文本编辑/输入能力（XMarkup 是只读渲染器）

---

## 8. 实施检查清单

- [ ] **P0**: Package.swift 新增 XMarkupUI target
- [ ] **P0**: XMarkupViewConfig 配置模型
- [ ] **P0**: HorizontalRuleUpdater hr 自适应
- [ ] **P0**: BlockquoteLayoutManager 竖线绘制
- [ ] **P0**: XMarkupTextView iOS 文本视图
- [ ] **P0**: AsyncMediaLoader+UI 集成
- [ ] **P0**: BlockquoteLayoutManager + XMarkupTextView 集成测试
- [ ] **P1**: XMarkupLabel iOS 标签视图
- [ ] **P1**: XMarkupTextView macOS 文本视图
- [ ] **P2**: macOS NSTextBlockRenderer
- [ ] **P2**: macOS NSTextTableRenderer
- [ ] **测试**: hr 自适应验证
- [ ] **测试**: blockquote 竖线视觉验证
- [ ] **测试**: macOS NSTextTable 渲染
