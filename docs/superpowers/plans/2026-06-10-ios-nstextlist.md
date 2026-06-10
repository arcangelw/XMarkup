# NSTextList 替换手动列表符号

## 变更

### 1. MarkupDocumentBuilder.swift — 删除手动符号拼接

删除：
- `applyListMarker()` 函数（~30 行）
- `buildBlock()` 中对 `applyListMarker` 的调用
- `emitBlock()` 中对 `applyListMarker` 的调用
- inline range 的 `markerLen` 偏移调整

新增：
- `flattenNode()` 参数添加 `listDepth: Int`，递归时检测 list 容器标签递增
- 叶子节点中根据 `listDepth` 重建 `BlockKind.listItem(isOrdered:indentLevel:)`

调用链不再依赖 `precedingBlocks`。

### 2. BlockRenderer.swift — 渲染时设 NSTextList

在 `renderBlock` 的 `paragraphStyle` 段中：

```swift
case let .listItem(isOrdered, indentLevel):
    let format: NSTextList.MarkerFormat = isOrdered ? .decimal : .disc
    var lists: [NSTextList] = []
    for level in 0...indentLevel {
        let fmt: NSTextList.MarkerFormat
        if level == 0 { fmt = format }
        else { fmt = isOrdered ? .decimal : .circle }
        lists.append(NSTextList(markerFormat: fmt, options: 0))
    }
    paragraphStyle.textLists = lists
    paragraphStyle.headIndent = CGFloat(indentLevel + 1) * 24
    paragraphStyle.firstLineHeadIndent = CGFloat(indentLevel + 1) * 24
```

无需 `tabStops` — `NSTextList` 搭配 `headIndent` 自动处理对齐。

### 3. 删除冗余代码

- `applyListMarker()` 不再需要，`precedingBlocks` 参数不再需要
- `buildBlock(blocks:inout)` 不再传入 blocks
- 列表序号由 `NSTextList` 的 `options` 自动管理

## 验证

- 无序列表：`<ul><li>A</li><li>B</li></ul>` → 自动渲染 • A, • B，选中复制不含符号
- 有序列表：`<ol><li>1</li><li>2</li></ol>` → 自动渲染 1. 1 / 2. 2
- 嵌套列表：`<ul><li>outer<ul><li>inner</li></ul></li></ul>` → 缩进正确
- 纯内联：`<b>text</b>` → 渲染不变

## 文件

| 文件 | 变更 |
|:--|:--|
| `MarkupDocumentBuilder.swift` | 删 ~30 行 / 增 ~10 行 |
| `BlockRenderer.swift` | 增 ~20 行 |
