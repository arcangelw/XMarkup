# MarkupDocumentBuilder 块构建重构复盘

## 问题根源

当前块级构建设计的假设：

```
"父容器块的文本范围 = 子块文本范围之和"
```

但这个假设在以下场景不成立：

| 场景 | 父范围 | 子范围 | 父 > 子和? |
|:--|:--:|:--:|:--:|
| `<div>before<p>text</p></div>` | (0,12) | (7,12) | ✅ text "before" 在父但不在子 |
| `<ul><li>outer<ul><li>inner</li></ul></li></ul>` | 多层重叠 | 不同范围 | ✅ 每层li范围不同 |
| `<table><tr><td>A</td><td>B</td></tr></table>` | 三层嵌套 | 逐层缩小 | ✅ 结构层次丢失 |

## 改进方案：构建 Span 树 → 平铺为块

不再用"去重"思路，而是：

```
输入: 扁平 blockSpans[]
  ↓ 
1. 按 (start ASC, length DESC) 排序
  ↓
2. 构建 SpanNode 树（父子关系基于范围包含）
  ↓
3. 遍历树，计算每个节点的"孤立文本范围"
   = 节点范围 − 所有子节点范围
  ↓
4. 每个孤立文本范围 → 1 个 MarkupBlock
   每个子节点 → 递归生成 MarkupBlock(s)
```

## 各场景的正确输出

### 场景 1：纯容器 ⊂ 单子块
```
<div><p>text</p></div>
  div(0,5) → 子 p(0,5) → 孤立范围 = 空 → 不产出块
  p(0,5) → 无子节点 → 产出块 kind=paragraph
结果: 1 个段落块 ✅（同当前行为）
```

### 场景 2：父容器有孤立文本（修复未闭合丢失）
```
<div>before<p>text</p></div>
  div(0,12) → 子 p(7,12) → 孤立范围 = (0,7) → 产出块 kind=division text="before"
  p(7,12) → 无子节点 → 产出块 kind=paragraph text="text"
结果: division["before"] + paragraph["text"] ✅ 不再丢失
```

### 场景 3：语义容器 ⊂ 单子块（blockquote）
```
<blockquote><p>text</p></blockquote>
  blockquote(0,5) → 子 p(0,5) → 孤立范围 = 空 → 不产出块
  p(0,5) → 无子节点 → 产出块 kind=paragraph
```
问题：p 失去了 blockquote 上下文。

**方案：** 子块范围 = 父块范围 时，子块继承父块类型。
```
修正: p 继承 blockquote kind → 产出块 kind=blockquote text="text" ✅
```

### 场景 4：嵌套列表
```
<ul><li>outer<ul><li>inner</li></ul></li></ul>
  ul_outer(0,12) → 子 li_outer(0,12) → 孤立范围 = 空
    li_outer(0,12) → 子 ul_inner(6,12), li_inner(6,12) → 孤立范围 = (0,6)
      → 产出块 kind=listItem text="outer"
    ul_inner(6,12) → 子 li_inner(6,12) → 孤立范围 = 空
    li_inner(6,12) → 无子节点 → 产出块 kind=listItem text="inner"
结果: listItem["outer"] + listItem["inner"] ✅ 嵌套保留
```

### 场景 5：表格
```
<table><tr><td>A</td><td>B</td></tr></table>
  table(0,6) → 子 tr(0,6) → 孤立范围 = 空
  tr(0,6) → 子 td(0,3), td(3,6) → 孤立范围 = 空
  td(0,3) → 产出块 kind=division text="A"
  td(3,6) → 产出块 kind=division text="B"
```
另: 对 table 结构特殊处理，构建 TableStructure。

## 关键规则

### 规则 1：继承（子块完全覆盖父范围时）

```
if child.range == parent.range {
    child 继承 parent 的 blockKind
}
```
用于 blockquote/article/section 等语义容器。

### 规则 2：纯容器标记

division/span 作为"纯容器"不参与继承（它们没有自身语义）。

### 规则 3：table 结构构建

当 `span.tag == .table` 时，其子节点结构为：
```
table → tr[] → td/th[]
```
构建 `TableStructure{rows: [[td blocks]]}` 用于 `BlockKind.table`。

## 实现变更

| 文件 | 变更 |
|:--|:--|
| 新增 `SpanNode` 树构建逻辑 | `MarkupDocumentBuilder.swift` |
| 替换当前 blockSpans.filter 去重 | 同上 |
| 修改 `blockKind(for:allSpans:)` → 改为基于树上下文 | 同上 |
| table 结构构建 | 同上 |
| 删除 `fallbackKind` 降级逻辑 | 不再需要 |
