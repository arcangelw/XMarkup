# XMarkup HTML 隐式关闭 + Adoption Agency 设计规格说明书

> 日期：2026-06-09
> 状态：待用户审查
> 前置：Code Review 修复完成（标签名大小写不敏感已实现）

---

## 1. 概述

### 1.1 问题

当前 TreeBuilder 对未闭合标签的处理是"所有未闭合标签留在栈中作为嵌套子节点"。但 HTML5 规范定义了更复杂的隐式关闭规则，当前实现导致以下场景输出不符合 HTML 规范：

```html
<p>第一段<p>第二段</p>
<!-- 当前：<p>第一段<p>第二段</p></p>  （第二段嵌套在第一段内）-->
<!-- 期望：<p>第一段</p><p>第二段</p>  （前一个 <p> 自动关闭）-->

<b>粗体<p>段落</p></b>
<!-- 当前：<b>粗体<p>段落</p></b>  （p 嵌套在 b 内）-->
<!-- 期望：<b>粗体</b><p><b>段落</b></p>  （b 重建到 p 内）-->
```

### 1.2 目标

1. 实现 HTML5 隐式关闭规则的实用子集（6 条规则），**始终生效**
2. 实现 Adoption Agency Algorithm（行内标签遇块级元素时的重建），由 `enable_autocorrect` 配置控制
3. 性能保障：adoption 深度上限 + 跳过无语义标签
4. 更新设计规格文档

### 1.3 关键决策

| 决策项 | 选定方案 | 理由 |
|--------|---------|------|
| 实现方式 | TreeBuilder 纯栈操作 | 不改变管线架构，单趟 O(n) |
| 隐式关闭 | 始终生效 | 是 HTML 基本规范行为，非可选特性 |
| Adoption agency | `enable_autocorrect` 控制 | 高级行为，需要时可关闭以获极致性能 |
| 深度限制 | `max_adoption_depth = 32` | O(1) 上限，覆盖所有实际场景 |
| 无语义标签跳过 | `span`/`sub`/`sup` 不重建 | 减少克隆和栈操作 |
| 作用域边界 | `div`/`blockquote`/`table` 等阻止向上查找 | 防止隐式关闭跨越容器 |

---

## 2. 标签分类体系

### 2.1 新增查表函数

| 函数 | 返回 true 的标签 | 用途 |
|------|------------------|------|
| `is_auto_closable(tag)` | `p`, `li`, `dt`, `dd`, `tr`, `td`, `th`, `thead`, `tbody`, `tfoot`, `h1`-`h6` | 判断标签是否参与隐式关闭 |
| `should_auto_close(parent, new_tag)` | 见下方规则表 | 判断新标签是否触发父标签隐式关闭 |
| `is_formatting_tag(tag)` | `b`, `strong`, `i`, `em`, `u`, `s`, `strike`, `del`, `a`, `code`, `mark`, `sub`, `sup`, `span` | Adoption agency 收集目标 |
| `has_formatting_semantics(tag)` | `b`, `strong`, `i`, `em`, `u`, `s`, `strike`, `del`, `a`, `code`, `mark` | Adoption agency 实际重建目标（排除 `span`/`sub`/`sup`） |
| `is_scope_boundary(tag)` | `div`, `blockquote`, `pre`, `table`, `ul`, `ol`, `video`, `audio`, `article`, `section`, `header`, `footer`, `main`, `nav`, `aside` | 隐式关闭扫描停止边界 |

### 2.2 `should_auto_close()` 规则表

| 当前栈中标签 | 触发关闭的新标签 |
|-------------|-----------------|
| `p` | 任何块级元素（含 `<p>` 自身） |
| `li` | `<li>` |
| `dt` | `<dt>` 或 `<dd>` |
| `dd` | `<dt>` 或 `<dd>` |
| `tr` | `<tr>` |
| `td` | `<td>` 或 `<th>` 或 `<tr>` |
| `th` | `<td>` 或 `<th>` 或 `<tr>` |
| `thead` | `<tbody>` 或 `<tfoot>` |
| `tbody` | `<tbody>` 或 `<tfoot>` |
| `tfoot` | `<tbody>` |
| `h1`-`h6` | 任何块级元素 |

### 2.3 块级元素扩展

现有 `is_block_level()` 函数需扩展，增加以下标签的块级判定：

```
p, li, dt, dd, tr, td, th, thead, tbody, tfoot
```

这些在现有 `is_block_level()` 中未包含，但它们在隐式关闭规则中表现为块级行为。

---

## 3. 隐式关闭规则（始终生效）

### 3.1 算法

在 `handle_start_tag()` 入栈之前执行：

```
输入：new_tag（即将入栈的新标签名）

1. 从栈顶向下扫描
2. 对每个栈中元素：
   a. 如果 should_auto_close(栈元素, new_tag) 为 true：
      - 弹出从栈顶到该元素（含）的所有节点
      - 返回
   b. 如果 is_scope_boundary(栈元素) 为 true：
      - 停止扫描（不跨越容器边界）
      - 返回
3. 扫描到栈底未找到匹配：无操作
```

### 3.2 示例

```
输入：<div><p>第一段<p>第二段</p></div>

栈变化：
[root]                        ← 初始
[root, div]                   ← <div> 入栈（div 是 scope boundary）
[root, div, p1]               ← <p1> 入栈
                              ← <p> 遇到新 <p>：
                                扫描栈顶 p1 → should_auto_close("p", "p") → true
                                弹出 p1
[root, div]                   ← p1 隐式关闭
[root, div, p2]               ← <p2> 入栈

AST：
div
├── p1: "第一段"
└── p2: "第二段"
```

### 3.3 scope boundary 作用

```
输入：<div><p>text</div>

扫描 <div> 时遇到 scope boundary → 停止
<p> 不被隐式关闭，由现有 handle_end_tag("</div>") 处理
```

---

## 4. Adoption Agency Algorithm（`enable_autocorrect = 1` 时生效）

### 4.1 触发条件

```
条件：新标签是块级元素 AND 栈顶（或栈顶附近）存在行内格式化标签
```

### 4.2 算法步骤

```
输入：new_tag（块级标签名）

1. 从栈顶向下，收集连续的行内格式化标签，直到遇到非格式化标签或 scope boundary
   - 记录所有格式化标签（含无语义的 span/sub/sup）
   - 筛选出 has_formatting_semantics() 的标签为重建列表

2. 如果重建列表为空 → 无需 adoption，返回

3. 深度限制：如果重建列表 > 32 项，截断

4. 弹出所有收集到的格式化标签（含无语义的）
   stack_.resize(stack_.size() - collected_count)

5. [后续在 handle_start_tag 的入栈阶段执行]
   a. 新块级元素正常入栈
   b. 按重建列表的逆序，为每个标签创建克隆节点并入栈
```

### 4.3 完整示例

```
输入：<div><b><i>text<p>para</p></i></b></div>

栈变化：
[root]                                    ← 初始
[root, div]                               ← <div>
[root, div, b]                            ← <b>
[root, div, b, i]                         ← <i>
                                          ← <p> 触发：
                                            隐式关闭：<i> 和 <b> 不是 auto_closable → 跳过
                                            Adoption：收集 [i, b]，均为有语义
[root, div]                               ← 弹出 i, b
[root, div, p]                            ← <p> 入栈
[root, div, p, b']                        ← 重建 b'
[root, div, p, b', i']                    ← 重建 i'

AST：
div
├── b
│   └── i
│       └── "text"
└── p
    └── b'
        └── i'
            └── "para"
```

### 4.4 `</i></b>` 的处理

Adoption 后栈中有 `[root, div, p, b', i']`。当遇到 `</p>` 时，现有 `handle_end_tag()` 从栈顶向下找 `<p>`，中间的 `<b'>`、`<i'>` 被连带弹出。后续的 `</i>` 和 `</b>` 在栈中找不到匹配（它们指向的是已弹出的 `<b'>`/`<i'>`，不是原始 `<b>`/`<i>`），被忽略。

### 4.5 跳过无语义标签示例

```
输入：<div><span><b>text<p>para</p></b></span></div>

Adoption 收集：[span, b]（均为 formatting_tag）
重建列表：[b]（仅 b 有 formatting_semantics，span 被跳过）
弹出：span 和 b 都弹出

栈变化：
[root, div, span, b]        ← 收集前
[root, div]                  ← 弹出 b, span
[root, div, p]               ← <p> 入栈
[root, div, p, b']           ← 只重建 b'（不重建 span）

AST：
div
├── span
│   └── b
│       └── "text"
└── p
    └── b'
        └── "para"
```

### 4.6 深度限制示例

```
输入：<div><b><i><u><s><mark>...(50 层)...<p>para</p>

收集到 50 个格式化标签 → 截断到 32 个
只重建前 32 层，后续 18 层丢弃
栈操作 O(32)，有硬性上限
```

---

## 5. 配置行为

| 配置 | 值 | 隐式关闭 | Adoption Agency |
|------|---|---------|-----------------|
| `enable_autocorrect` | `0` | ✅ 始终生效 | ❌ 不执行 |
| `enable_autocorrect` | `1`（默认） | ✅ 始终生效 | ✅ 执行 |

---

## 6. 性能保障

| 机制 | 保障 | 场景 |
|------|------|------|
| 隐式关闭单向扫描 | O(depth)，scope boundary 截断 | 每次入栈前检查一次 |
| Adoption 收集 | O(collected)，最多 32 层 | 只在块级+行内交叉时触发 |
| Adoption 克隆 | O(adoption_depth) | 受 max_adoption_depth 限制 |
| 查表 | O(1) `unordered_map` | 所有标签分类 |
| 现有深度限制 | `max_nesting_depth` 仍有效 | 整体栈深度有硬上限 |

**复杂度总结：** 单趟管线仍为 O(n)，隐式关闭和 adoption 的额外开销均为 O(1) 常数级（受深度上限限制）。

---

## 7. 对现有行为的影响

### 7.1 行为变化表

| 场景 | 旧行为 | 新行为 | 影响 |
|------|--------|--------|------|
| `<p>A<p>B</p>` | B 嵌套在 A 内 | A、B 平级 | ✅ 更符合规范 |
| `<ul><li>A<li>B</ul>` | B 嵌套在 A 内 | A、B 平级 | ✅ 更符合规范 |
| `<b>text<p>para` | p 嵌套在 b 内 | b 重建到 p 内 | ✅ 格式延续正确 |
| `<div><p>text</div>` | 不变 | 不变 | 无影响 |
| 正确嵌套的 HTML | 不变 | 不变 | 无影响 |
| `<div><p>text<p>more</div>` | 嵌套 | 平级 | ✅ scope boundary 生效 |

### 7.2 需要更新的测试

| 测试文件 | 需调整的测试 | 原因 |
|---------|-------------|------|
| `test_tree_builder.cpp` | `MisnestedTags` | 隐式关闭改变了树结构预期 |
| `test_style_resolver.cpp` | 部分 block newline 测试 | 段落结构变化可能影响换行 |
| `test_api.cpp` | 可能的 span 范围变化 | 段落结构变化影响 range |

### 7.3 新增测试

| 测试 | 覆盖规则 |
|------|---------|
| `ImplicitClose_PSameP` | 规则 1+2：`<p>` 遇 `<p>` |
| `ImplicitClose_PBlock` | 规则 1：`<p>` 遇 `<div>` |
| `ImplicitClose_LILI` | 规则 3：`<li>` 遇 `<li>` |
| `ImplicitClose_DtDd` | 规则 4：`<dt>`/`<dd>` 互关 |
| `ImplicitClose_TrTr` | 规则 5：`<tr>` 遇 `<tr>` |
| `ImplicitClose_TdTh` | 规则 6：`<td>`/`<th>` 互关 |
| `ImplicitClose_ScopeBoundary` | scope boundary 阻止跨容器 |
| `Adoption_BasicBP` | `<b>` 内遇 `<p>` 基本重建 |
| `Adoption_MultiLayer` | 多层行内重建 |
| `Adoption_SkipSpan` | 无语义标签跳过 |
| `Adoption_DepthLimit` | 超过 32 层截断 |
| `Adoption_Disabled` | `enable_autocorrect=0` 不触发 |

---

## 8. 需要更新的文档

| 文档 | 更新内容 |
|------|----------|
| `docs/superpowers/specs/2026-06-05-xmarkup-core-design.md` §4.2 | 更新自动纠错规则表 + 添加隐式关闭规则 + adoption agency 描述 + scope boundary |
| 同上 §11.8 | 更新自动纠错场景的输入→输出契约（`<p><p>` → 平级而非嵌套） |
| `core/src/tree_builder.h` | 移除 `(void)autocorrect_;`，更新类文档 |
| `core/src/api.cpp` | `enable_autocorrect` 注释更新：说明它控制 adoption agency |
| `core/include/xmarkup/xmarkup.h` | `enable_autocorrect` 字段注释更新 |

---

## 9. 文件变更清单

| 文件 | 操作 | 职责变更 |
|------|------|----------|
| `core/src/tree_builder.h` | 修改 | 添加查表函数声明、`pending_adoption_` 成员、`max_adoption_depth` 常量 |
| `core/src/tree_builder.cpp` | 修改 | 实现查表函数 + `perform_implicit_close()` + `perform_adoption_agency()` + 修改 `handle_start_tag()` |
| `core/src/api.cpp` | 修改 | 更新 `enable_autocorrect` 注释 |
| `core/include/xmarkup/xmarkup.h` | 修改 | 更新 `enable_autocorrect` 字段注释 |
| `docs/superpowers/specs/2026-06-05-xmarkup-core-design.md` | 修改 | §4.2 和 §11.8 内容更新 |
| `tests/test_tree_builder.cpp` | 修改 | 调整现有测试 + 新增 12 个隐式关闭/adoption 测试 |
