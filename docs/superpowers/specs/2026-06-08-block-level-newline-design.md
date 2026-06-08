# 块级元素换行规则设计

> **日期**：2026-06-08
> **状态**：待审查
> **影响范围**：核心引擎 `style_resolver.cpp`，所有平台（iOS/Android/HarmonyOS）

---

## 1. 问题描述

XMarkup 核心引擎将 HTML 解析为纯文本 + 样式区间时，**块级元素之间缺少换行分隔**，导致渲染结果与浏览器表现不一致。

### 1.1 当前行为 vs 期望行为

| HTML 输入 | 当前输出 | 期望输出 | 问题 |
|---|---|---|---|
| `<h1>Title</h1><p>Para</p>` | `TitlePara↵` | `Title↵Para↵` | h1 和 p 粘连 |
| `text<h1>Title</h1>` | `textTitle` | `text↵Title↵` | 内联文本和 h1 粘连 |
| `<h1>Title</h1>text` | `Titletext` | `Title↵text` | h1 和内联文本粘连 |
| `<h1>T</h1><h2>S</h2>` | `TS` | `T↵S↵` | 连续标题粘连 |
| `<ul><li>A</li><li>B</li></ul>` | `AB` | `A↵B↵` | 列表项粘连 |
| `<p>A</p><ul><li>B</li></ul><p>C</p>` | `A↵B C↵` | `A↵B↵C↵` | 列表与段落粘连 |
| `<h1>T</h1><hr><p>P</p>` | `T[OBJ]P↵` | `T↵[OBJ]↵P↵` | hr 前后无换行 |
| `before<h1>T</h1>after` | `beforeTafter` | `before↵T↵after` | 最极端的粘连 |

### 1.2 根因

`core/src/style_resolver.cpp` 的 `dfs()` 方法中，仅 `<p>` 标签在**尾部**追加了 `\n`：

```cpp
// 当前代码：只有 p 有尾部换行
if (tag_type == XM_TAG_PARAGRAPH && byte_offset_ > span_start) {
    result_.text += "\n";
    byte_offset_ += 1;
}
```

其他所有块级标签（h1~h6、blockquote、pre、div、ul、ol、li、table、tr、hr）**既没有前缀换行，也没有后缀换行**。

---

## 2. HTML 块级盒模型分析

### 2.1 什么是块级元素

HTML/CSS 中，元素分为**块级（block-level）**和**行内（inline-level）**两类。块级元素在视觉格式化模型中的核心特征是**生成块级盒子，独占一行**。

### 2.2 XMarkup 标签分类

根据 HTML 规范，将 XMarkup 已有的标签分为三类：

#### 块级元素（block-level）

这些元素**必须**在前后产生换行，使其内容与其他内容分离：

| 标签 | XMTagType | 说明 |
|---|---|---|
| `<p>` | `XM_TAG_PARAGRAPH` (20) | 段落 |
| `<h1>`~`<h6>` | `XM_TAG_HEADING_1`~`6` (21-26) | 标题 |
| `<blockquote>` | `XM_TAG_BLOCKQUOTE` (27) | 引用块 |
| `<pre>` | `XM_TAG_PREFORMATTED` (28) | 预格式化 |
| `<div>` | `XM_TAG_DIVISION` (72) | 通用块容器 |
| `<ul>` | `XM_TAG_LIST_UNORDERED` (50) | 无序列表 |
| `<ol>` | `XM_TAG_LIST_ORDERED` (51) | 有序列表 |
| `<li>` | `XM_TAG_LIST_ITEM` (52) | 列表项 |
| `<table>` | `XM_TAG_TABLE` (60) | 表格 |
| `<tr>` | `XM_TAG_TABLE_ROW` (61) | 表格行 |
| `<hr>` | `XM_TAG_HORIZONTAL_RULE` (70) | 水平线 |

#### 行内元素（inline-level）

这些元素**不会**产生换行，与周围文本在同一行内：

| 标签 | XMTagType |
|---|---|
| `<b>`, `<strong>` | `XM_TAG_BOLD` (1) |
| `<i>`, `<em>` | `XM_TAG_ITALIC` (2) |
| `<u>` | `XM_TAG_UNDERLINE` (3) |
| `<s>`, `<del>` | `XM_TAG_STRIKETHROUGH` (4) |
| `<sub>` | `XM_TAG_SUBSCRIPT` (5) |
| `<sup>` | `XM_TAG_SUPERSCRIPT` (6) |
| `<mark>` | `XM_TAG_MARK` (7) |
| `<code>` | `XM_TAG_CODE` (8) |
| `<a>` | `XM_TAG_LINK` (40) |
| `<span>` | `XM_TAG_SPAN` (73) |

#### Void 元素（特殊处理）

这些元素没有子节点，已有特殊占位逻辑：

| 标签 | XMTagType | 当前处理 |
|---|---|---|
| `<img>` | `XM_TAG_IMAGE` (41) | 插入 U+FFFC |
| `<video>` | `XM_TAG_VIDEO` (42) | 插入 U+FFFC |
| `<audio>` | `XM_TAG_AUDIO` (44) | 插入 U+FFFC |
| `<br>` | `XM_TAG_LINE_BREAK` (71) | 插入 `\n` |

> 注意：`<hr>` 既是 void 元素（插入 U+FFFC）又是块级元素（需要前后换行）。
> `<br>` 虽然插入 `\n`，但它只是行内断行，不是块级分隔。

---

## 3. 换行规则设计

### 3.1 核心原则

**块级元素 = 前后各一个换行的隔离单元。**

具体规则：

1. **块级元素进入前**：如果已输出文本非空，且最后一个字符不是 `\n`，追加一个 `\n`
2. **块级元素退出后**：如果最后一个字符不是 `\n`，追加一个 `\n`
3. **连续块级元素之间**：前一个块的尾部 `\n` 自动作为后一个块的"前缀换行"，不会产生多余空行

### 3.2 规则形式化

```
function ensure_newline():
    if result_.text 不为空 and result_.text 的最后一个字符 != '\n':
        result_.text += '\n'
        byte_offset_ += 1

// DFS 进入块级元素时
if is_block_level(tag_type):
    ensure_newline()

// ... 处理子节点 ...

// DFS 退出块级元素时
if is_block_level(tag_type):
    ensure_newline()
```

### 3.3 对各场景的影响验证

| HTML | 进入 h1 前 | h1 子节点 | 退出 h1 后 | 进入 p 前 | p 子节点 | 退出 p 后 | 最终文本 |
|---|---|---|---|---|---|---|---|
| `<h1>T</h1><p>P</p>` | text="" (空，跳过) | → "T" | last='T'≠`\n` → "T\n" | last='\n' (跳过) | → "T\nP" | last='P'≠`\n` → "T\nP\n" | `T↵P↵` ✓ |
| `text<h1>T</h1>more` | text="text", last='t'≠`\n` → "text\n" | → "text\nT" | last='T'≠`\n` → "text\nT\n" | (无 p) | → "text\nT\nmore" | (无块级) | `text↵T↵more` ✓ |
| `<p>A</p><p>B</p>` | text="" (空，跳过) | → "A" | last='A'→"A\n" | last='\n'(跳过) | → "A\nB" | last='B'→"A\nB\n" | `A↵B↵` ✓ |
| `<h1>T</h1><h2>S</h2>` | text="" (空) | → "T" | → "T\n" | last='\n'(跳过) | → "T\nS" | → "T\nS\n" | `T↵S↵` ✓ |

### 3.4 特殊场景

#### 3.4.1 嵌套块级

```html
<div><h1>T</h1><p>P</p></div>
```

DFS 顺序：进入 div → 进入 h1 → 退出 h1 → 进入 p → 退出 p → 退出 div

| 步骤 | 动作 | text | 说明 |
|---|---|---|---|
| 进入 div | ensure_newline | "" (空，跳过) | 正确：最外层无需前缀 |
| 进入 h1 | ensure_newline | "" (空，跳过) | 正确：div 内第一个元素 |
| 子节点 | 追加 "T" | "T" | |
| 退出 h1 | ensure_newline | "T\n" | h1 后换行 |
| 进入 p | ensure_newline | "T\n" (last='\n'，跳过) | 连续块级，复用 h1 的尾部 \n |
| 子节点 | 追加 "P" | "T\nP" | |
| 退出 p | ensure_newline | "T\nP\n" | p 后换行 |
| 退出 div | ensure_newline | "T\nP\n" (last='\n'，跳过) | 正确：不产生多余 \n |

结果：`T↵P↵` ✓

#### 3.4.2 列表

```html
<p>A</p><ul><li>B</li><li>C</li></ul><p>D</p>
```

| 步骤 | 动作 | text |
|---|---|---|
| 进入 p | ensure_newline | "" (空) |
| 退出 p | ensure_newline | "A\n" |
| 进入 ul | ensure_newline | "A\n" (last='\n'，跳过) |
| 进入 li(1) | ensure_newline | "A\n" (跳过) |
| 退出 li(1) | ensure_newline | "A\nB\n" |
| 进入 li(2) | ensure_newline | "A\nB\n" (跳过) |
| 退出 li(2) | ensure_newline | "A\nB\nC\n" |
| 退出 ul | ensure_newline | "A\nB\nC\n" (跳过) |
| 进入 p(2) | ensure_newline | "A\nB\nC\n" (跳过) |
| 退出 p(2) | ensure_newline | "A\nB\nC\nD\n" |

结果：`A↵B↵C↵D↵` ✓

#### 3.4.3 `<hr>` 水平线

```html
<p>A</p><hr><p>B</p>
```

`<hr>` 既是 void 元素（插入 U+FFFC）又是块级元素。

| 步骤 | 动作 | text |
|---|---|---|
| 进入 p | ensure_newline | "" (空) |
| 退出 p | ensure_newline | "A\n" |
| 进入 hr | ensure_newline | "A\n" (跳过) |
| void 插入 | U+FFFC | "A\n□" |
| 退出 hr | ensure_newline | "A\n□\n" |
| 进入 p(2) | ensure_newline | "A\n□\n" (跳过) |
| 退出 p(2) | ensure_newline | "A\n□\nB\n" |

结果：`A↵□↵B↵` ✓

#### 3.4.4 `<br>` 换行

```html
<p>A<br>B</p>
```

`<br>` 不是块级元素，只是行内断行，已有 `\n` 插入逻辑。不需要走块级换行规则。

| 步骤 | 动作 | text |
|---|---|---|
| 进入 p | ensure_newline | "" (空) |
| 子节点 text | | "A" |
| br 插入 | \n | "A\n" |
| 子节点 text | | "A\nB" |
| 退出 p | ensure_newline | "A\nB\n" |

结果：`A↵B↵` ✓

#### 3.4.5 空块级元素

```html
<p>A</p><p></p><p>B</p>
```

| 步骤 | 动作 | text |
|---|---|---|
| 进入 p(1) | ensure_newline | "" (空) |
| 退出 p(1) | ensure_newline | "A\n" |
| 进入 p(2) | ensure_newline | "A\n" (跳过) |
| 退出 p(2) | ensure_newline | "A\n" (空内容，last='\n'，跳过) | ← 关键：空块级不产生多余 \n |
| 进入 p(3) | ensure_newline | "A\n" (跳过) |
| 退出 p(3) | ensure_newline | "A\nB\n" |

结果：`A↵B↵` ✓（空 `<p>` 被忽略，不产生额外空行）

#### 3.4.6 `<pre>` 预格式化

```html
<p>A</p><pre>code\n  indent</pre><p>B</p>
```

| 步骤 | 动作 | text |
|---|---|---|
| 退出 p(1) | | "A\n" |
| 进入 pre | ensure_newline | "A\n" (跳过) |
| 子节点 | 白色保留，原样追加 | "A\ncode\n  indent" |
| 退出 pre | ensure_newline | "A\ncode\n  indent\n" |
| 进入 p(2) | ensure_newline | "A\ncode\n  indent\n" (跳过) |
| 退出 p(2) | | "A\ncode\n  indent\nB\n" |

结果：`A↵code↵  indent↵B↵` ✓（pre 内部空白完整保留）

#### 3.4.7 `<table>` 表格

```html
<table><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></table>
```

每个 `<tr>` 是块级（行间换行），每个 `<td>` 也是块级（单元格间换行）：

| 步骤 | text |
|---|---|
| 进入 table | "" |
| 进入 tr(1) | "" |
| 进入 td(1) | "" |
| 退出 td(1) | "A\n" |
| 进入 td(2) | "A\n" (跳过) |
| 退出 td(2) | "A\nB\n" |
| 退出 tr(1) | "A\nB\n" (跳过) |
| 进入 tr(2) | "A\nB\n" (跳过) |
| 进入 td(3) | "A\nB\n" (跳过) |
| 退出 td(3) | "A\nB\nC\n" |
| 进入 td(4) | "A\nB\nC\n" (跳过) |
| 退出 td(4) | "A\nB\nC\nD\n" |
| 退出 tr(2) | "A\nB\nC\nD\n" (跳过) |
| 退出 table | "A\nB\nC\nD\n" (跳过) |

结果：`A↵B↵C↵D↵` ✓

> **表格的局限性**：纯文本无法表达列对齐，XMarkup 的职责是保证单元格内容不粘连。列布局需要各平台桥接层在渲染时自行处理。

---

## 4. 实现方案

### 4.1 修改文件

- `core/src/style_resolver.cpp`：修改 `dfs()` 方法

### 4.2 改动点

#### 4.2.1 新增 `is_block_level()` 辅助函数

```cpp
/// 判断标签是否为块级元素
static bool is_block_level(int tag_type) {
    switch (tag_type) {
    case XM_TAG_PARAGRAPH:
    case XM_TAG_HEADING_1: case XM_TAG_HEADING_2:
    case XM_TAG_HEADING_3: case XM_TAG_HEADING_4:
    case XM_TAG_HEADING_5: case XM_TAG_HEADING_6:
    case XM_TAG_BLOCKQUOTE:
    case XM_TAG_PREFORMATTED:
    case XM_TAG_DIVISION:
    case XM_TAG_LIST_ORDERED:
    case XM_TAG_LIST_UNORDERED:
    case XM_TAG_LIST_ITEM:
    case XM_TAG_TABLE:
    case XM_TAG_TABLE_ROW:
    case XM_TAG_TABLE_CELL:
    case XM_TAG_TABLE_HEADER:
    case XM_TAG_HORIZONTAL_RULE:
        return true;
    default:
        return false;
    }
}
```

#### 4.2.2 新增 `ensure_newline()` 辅助方法

```cpp
/// 如果已输出文本非空且末尾不是 \n，追加一个换行
void StyleResolver::ensure_newline() {
    if (!result_.text.empty() && result_.text.back() != '\n') {
        result_.text += '\n';
        byte_offset_ += 1;
    }
}
```

#### 4.2.3 修改 `dfs()` 中的 ELEMENT 处理

在递归处理子节点**之前**（块级进入前），和递归处理子节点**之后**（块级退出后），各调用一次 `ensure_newline()`：

```cpp
if (node.type == ASTNode::ELEMENT) {
    int tag_type = map_tag(node.tag_name);
    // ... 省略特殊处理 ...

    // 块级元素：进入前确保换行
    bool is_block = is_block_level(tag_type);
    if (is_block) {
        ensure_newline();
    }

    // 记录 span 起始位置（在 ensure_newline 之后）
    uint32_t span_start = byte_offset_;

    // ... 产出 span、递归子节点、void 占位 ...

    // 段落级标签在子节点后追加换行分隔（旧逻辑，由 ensure_newline 替代）
    // if (tag_type == XM_TAG_PARAGRAPH && byte_offset_ > span_start) { ... }
    // ↑ 删除这段旧代码

    // 块级元素：退出后确保换行
    if (is_block) {
        ensure_newline();
    }

    // 更新 byte_end ...
}
```

### 4.3 关于 span range 的注意事项

**`span_start` 必须在 `ensure_newline()` 之后记录**，否则换行符会被包含在 span 的范围内。

例如 `<h1>Title</h1>`，如果 `span_start` 在 `ensure_newline()` 之前：
- `ensure_newline()` 前面无内容，不追加
- 不影响

但 `text<h1>Title</h1>`：
- `ensure_newline()` 追加 `\n`
- `span_start` 指向 `\n` 之后
- h1 span 范围 = [6, 11) = "Title"，不含前缀 `\n` ✓

退出时 `ensure_newline()`：
- 追加 `\n`，但 `byte_end` 已在之前更新为当前 `byte_offset_`
- 后缀 `\n` 不在 span 范围内 ✓

### 4.4 对 iOS 端的影响

iOS 端 `NSAttributedString+XMarkup.swift` 的 6 阶渲染管线**无需修改**。因为：
- 换行符 `\n` 已存在于文本中
- UITextView/NSTextView 原生支持 `\n` 换行显示
- 样式区间（span）的 range 仍然是正确的（换行符在 span 范围外）

但需要移除当前 Pass 2 中 `<p>` 尾部 `\n` 的任何特殊处理（如果有的话）。当前代码中 Pass 2 并没有对 `\n` 做特殊处理，所以**无需修改 iOS 端**。

---

## 5. 测试计划

### 5.1 新增 C++ 单元测试（在 `tests/test_style_resolver.cpp` 中）

| 测试用例 | 输入 | 期望文本 |
|---|---|---|
| 连续块级 h1+p | `<h1>T</h1><p>P</p>` | `T\nP\n` |
| 连续标题 h1+h2 | `<h1>T</h1><h2>S</h2>` | `T\nS\n` |
| 内联+块级 | `text<h1>T</h1>` | `text\nT\n` |
| 块级+内联 | `<h1>T</h1>text` | `T\ntext` |
| 内联+块级+内联 | `a<h1>T</h1>b` | `a\nT\nb` |
| 连续段落 p+p+p | `<p>A</p><p>B</p><p>C</p>` | `A\nB\nC\n` |
| 列表项分隔 | `<ul><li>A</li><li>B</li></ul>` | `A\nB\n` |
| 有序列表 | `<ol><li>A</li><li>B</li></ol>` | `A\nB\n` |
| hr 前后换行 | `<p>A</p><hr><p>B</p>` | `A\n[OBJ]\nB\n` |
| 表格单元格 | `<table><tr><td>A</td><td>B</td></tr></table>` | `A\nB\n` |
| 嵌套 div>h1+p | `<div><h1>T</h1><p>P</p></div>` | `T\nP\n` |
| blockquote>p | `<blockquote><p>Q</p></blockquote>` | `Q\n\n` |
| pre 前后换行 | `<p>A</p><pre>code</pre><p>B</p>` | `A\ncode\nB\n` |
| 空块级 | `<p>A</p><p></p><p>B</p>` | `A\nB\n` |
| br 非块级 | `<p>A<br>B</p>` | `A\nB\n` |
| div 内混合 | `<div>text<h1>T</h1>more</div>` | `text\nT\nmore\n` |

### 5.2 不需要修改的测试

现有测试中如果硬编码了旧的文本输出（如 `TitlePara\n`），需要更新为新的期望值（`Title\nPara\n`）。

---

## 6. 不在范围内

以下内容**不**在本次设计中：

1. **段落间距（margin）**：HTML 中块级元素之间有 margin（如 h1 下方的 margin），在纯文本中无法表达。需要各平台桥接层在渲染时通过 `postProcessor` 或 `XMarkupStyleConfig` 自行添加段落间距（如 `.paragraphStyle` 属性）。
2. **列表标记（bullet/number）**：`<li>` 的前置符号（• / 1. 2. 3.）不在纯文本中生成，由各平台渲染层负责。
3. **表格布局**：纯文本无法表达列对齐，只保证单元格内容不粘连。
4. **`XMarkup+TextView.swift` 重构**：与换行规则无关，属于独立的设计改进，不在本次范围内。

---

## 7. 总结

| 项 | 决策 |
|---|---|
| 换行策略 | 块级元素前后各 `ensure_newline()` |
| 换行去重 | `ensure_newline()` 检查最后字符是否为 `\n` |
| 空块级 | 不产生额外换行 |
| `<br>` | 不变，仍是行内 `\n` |
| `<hr>` | 块级，U+FFFC 前后 `ensure_newline()` |
| 修改范围 | 仅 `core/src/style_resolver.cpp` |
| 平台影响 | 所有平台自动受益，无需修改桥接层 |
