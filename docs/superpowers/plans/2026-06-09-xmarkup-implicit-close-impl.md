# HTML 隐式关闭 + Adoption Agency + 日志系统 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现 HTML5 隐式关闭规则 + Adoption Agency + 结构化日志系统

**架构：** TreeBuilder 纯栈操作扩展 + Logger 静态类 + XMConfig 回调扩展。不改变管线架构，单趟 O(n)。

**技术栈：** C++17, CMake, GoogleTest

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `core/src/logger.h` | 新增 | Logger 类声明：级别过滤 + 回调分发 |
| `core/src/logger.cpp` | 新增 | Logger 实现：init/error/warn/info/trace |
| `core/include/xmarkup/xmarkup.h` | 修改 | 新增 XMLogLevel、XMLogCallback、XMConfig 扩展字段 |
| `core/src/api.cpp` | 修改 | Logger::init() 调用 + 注释更新 |
| `core/src/parser.cpp` | 修改 | Logger::init() + ERROR/INFO 日志插桩 |
| `core/src/tokenizer.cpp` | 修改 | TRACE 日志插桩（状态转换、标签小写化） |
| `core/src/style_resolver.cpp` | 修改 | TRACE 日志插桩（CSS 标准化、标签映射） |
| `core/src/tree_builder.h` | 修改 | 查表函数声明 + pending_adoption_ + 常量 |
| `core/src/tree_builder.cpp` | 修改 | 查表函数 + 隐式关闭 + adoption + 日志插桩 |
| `core/CMakeLists.txt` | 修改 | 添加 logger.cpp |
| `docs/superpowers/specs/2026-06-05-xmarkup-core-design.md` | 修改 | §3.1 + §4.2 + §11.8 更新 |
| `tests/test_tree_builder.cpp` | 修改 | 调整现有测试 + 新增 12 个测试 |
| `tests/test_api.cpp` | 修改 | 新增日志回调测试 |

---

### 任务 1：日志系统基础设施

**文件：**
- 创建：`core/src/logger.h`
- 创建：`core/src/logger.cpp`
- 修改：`core/include/xmarkup/xmarkup.h`
- 修改：`core/CMakeLists.txt`
- 修改：`core/src/api.cpp`
- 测试：`tests/test_api.cpp`

- [ ] **步骤 1：在 xmarkup.h 中添加日志类型和 Config 扩展**

在 `XMStyleType` 枚举之后添加日志级别枚举和回调类型：

```c
/** @brief 日志级别 */
typedef enum XMLogLevel {
    XM_LOG_ERROR = 0,  /**< 解析异常 */
    XM_LOG_WARN  = 1,  /**< 容错决策（隐式关闭等） */
    XM_LOG_INFO  = 2,  /**< 关键决策节点 */
    XM_LOG_TRACE = 3,  /**< 详细步骤 */
} XMLogLevel;

/** @brief 日志回调函数类型 */
typedef void (*XMLogCallback)(XMLogLevel level, const char* message, void* context);
```

修改 `XMConfig` 结构体，在 `base_font_size` 之后添加三个字段：

```c
typedef struct XMConfig {
    uint8_t  enable_autocorrect;
    uint16_t max_nesting_depth;
    float    base_font_size;
    XMLogCallback log_callback;    /**< 日志回调，NULL = 不输出 */
    void*         log_context;     /**< 回调用户上下文 */
    XMLogLevel    log_level;       /**< 最低输出级别，默认 XM_LOG_ERROR */
} XMConfig;
```

更新 `xmarkup_create` 的文档注释，说明新增字段的默认行为。

- [ ] **步骤 2：创建 logger.h**

```cpp
#pragma once

#include "xmarkup/xmarkup.h"
#include <cstdarg>

namespace xmarkup {

/**
 * @brief 内部日志工具
 *
 * 通过 XMConfig.log_callback 向宿主输出日志。
 * callback 为 NULL 时所有方法为空操作，零性能开销。
 */
class Logger {
public:
    /** @brief 初始化日志器（由 api.cpp 调用） */
    static void init(XMLogCallback callback, void* context, XMLogLevel level);

    static void error(const char* fmt, ...);
    static void warn(const char* fmt, ...);
    static void info(const char* fmt, ...);
    static void trace(const char* fmt, ...);

private:
    static void log(XMLogLevel level, const char* fmt, va_list args);

    static XMLogCallback callback_;
    static void*         context_;
    static XMLogLevel    min_level_;
};

} // namespace xmarkup
```

- [ ] **步骤 3：创建 logger.cpp**

```cpp
#include "logger.h"
#include <cstdio>

namespace xmarkup {

XMLogCallback Logger::callback_ = nullptr;
void*         Logger::context_  = nullptr;
XMLogLevel    Logger::min_level_ = XM_LOG_ERROR;

void Logger::init(XMLogCallback callback, void* context, XMLogLevel level) {
    callback_  = callback;
    context_   = context;
    min_level_ = level;
}

void Logger::log(XMLogLevel level, const char* fmt, va_list args) {
    if (!callback_ || level > min_level_) return;

    char buf[1024];
    std::vsnprintf(buf, sizeof(buf), fmt, args);
    callback_(level, buf, context_);
}

void Logger::error(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    log(XM_LOG_ERROR, fmt, args);
    va_end(args);
}

void Logger::warn(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    log(XM_LOG_WARN, fmt, args);
    va_end(args);
}

void Logger::info(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    log(XM_LOG_INFO, fmt, args);
    va_end(args);
}

void Logger::trace(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    log(XM_LOG_TRACE, fmt, args);
    va_end(args);
}

} // namespace xmarkup
```

- [ ] **步骤 4：更新 CMakeLists.txt 添加 logger.cpp**

在 `core/CMakeLists.txt` 的 `add_library` 源文件列表中添加 `src/logger.cpp`。

- [ ] **步骤 5：更新 api.cpp — 初始化 Logger + 更新默认配置**

修改 `api.cpp` 中的 `xmarkup_create`：

```cpp
static constexpr XMLogCallback kDefaultLogCallback = nullptr;
static constexpr void*          kDefaultLogContext  = nullptr;
static constexpr XMLogLevel    kDefaultLogLevel    = XM_LOG_ERROR;

XMParser* xmarkup_create(const XMConfig* config) {
    XMConfig cfg = {
        kDefaultAutocorrect, kDefaultMaxNestingDepth, kDefaultBaseFontSize,
        kDefaultLogCallback, kDefaultLogContext, kDefaultLogLevel
    };
    if (config) cfg = *config;

    // 初始化日志器
    Logger::init(cfg.log_callback, cfg.log_context, cfg.log_level);

    auto* p = new (std::nothrow) xmarkup::ParserInternal();
    if (!p) return nullptr;
    p->config = cfg;
    p->last_error = XM_OK;
    return reinterpret_cast<XMParser*>(p);
}
```

在 `api.cpp` 顶部添加 `#include "logger.h"`。

- [ ] **步骤 6：编写日志回调测试**

在 `tests/test_api.cpp` 添加：

```cpp
// === 日志系统测试 ===

namespace {
    struct LogCapture {
        std::vector<std::pair<XMLogLevel, std::string>> entries;
        static void callback(XMLogLevel level, const char* message, void* context) {
            auto* capture = static_cast<LogCapture*>(context);
            capture->entries.emplace_back(level, std::string(message));
        }
    };
}

TEST_F(APITest, LogCallbackReceivesMessages) {
    LogCapture capture;
    xmarkup_destroy(parser_);
    XMConfig cfg = {1, 256, 16.0f, LogCapture::callback, &capture, XM_LOG_INFO};
    parser_ = xmarkup_create(&cfg);

    auto* r = parse("<b>hello</b>");
    ASSERT_NE(r, nullptr);
    xmarkup_result_free(r);

    // 应至少收到 INFO 级别的 parse start/done 消息
    EXPECT_GE(capture.entries.size(), 2u);
    bool has_info = false;
    for (auto& [level, msg] : capture.entries) {
        if (level == XM_LOG_INFO) has_info = true;
    }
    EXPECT_TRUE(has_info);
}

TEST_F(APITest, LogCallbackNullNoop) {
    xmarkup_destroy(parser_);
    XMConfig cfg = {1, 256, 16.0f, nullptr, nullptr, XM_LOG_TRACE};
    parser_ = xmarkup_create(&cfg);
    // callback 为 NULL，不应崩溃
    auto* r = parse("<b>test</b>");
    ASSERT_NE(r, nullptr);
    xmarkup_result_free(r);
}
```

- [ ] **步骤 7：在 parser.cpp 中添加 INFO/ERROR 日志**

在 `parser.cpp` 的 `parse()` 方法中：
- 方法开始处：`Logger::info("parse start: length=%zu", length);`
- 成功返回前：`Logger::info("parse done: text_len=%u, span_count=%u, error=0", result->text_len, result->span_count);`
- 内存分配失败处：`Logger::error("alloc failed: XMResult");`

添加 `#include "logger.h"`。

- [ ] **步骤 8：构建并运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && xcodegen generate .. 2>/dev/null; cd /Users/arcangelw/GitHub/XMarkup/build && cmake .. && cmake --build . && for t in tests/test_*; do ./$t --gtest_brief=1; done`
预期：全部通过

- [ ] **步骤 9：Commit**

```bash
git add core/src/logger.h core/src/logger.cpp core/include/xmarkup/xmarkup.h core/CMakeLists.txt core/src/api.cpp core/src/parser.cpp tests/test_api.cpp
git commit -m "feat(core): 日志系统 — XMLogLevel/XMLogCallback/Logger + INFO/ERROR 插桩"
```

---

### 任务 2：标签分类查表函数

**文件：**
- 修改：`core/src/tree_builder.h`
- 修改：`core/src/tree_builder.cpp`
- 测试：`tests/test_tree_builder.cpp`

- [ ] **步骤 1：在 tree_builder.h 中声明查表函数**

在 `TreeBuilder` 类的 private 区域添加静态方法声明：

```cpp
    // === 标签分类查表 ===
    static bool is_auto_closable(const std::string& tag);
    static bool should_auto_close(const std::string& parent_tag, const std::string& new_tag);
    static bool is_extended_block_level(const std::string& tag);
    static bool is_formatting_tag(const std::string& tag);
    static bool has_formatting_semantics(const std::string& tag);
    static bool is_scope_boundary(const std::string& tag);
```

添加 `pending_adoption_` 成员和深度限制常量：

```cpp
    static constexpr size_t kMaxAdoptionDepth = 32;
    std::vector<std::string> pending_adoption_;
```

- [ ] **步骤 2：在 tree_builder.cpp 中实现查表函数**

使用 `static unordered_map` 实现每个查表函数。关键实现：

```cpp
// 自动关闭标签集
static bool is_auto_closable(const std::string& tag) {
    static const std::unordered_set<std::string> tags = {
        "p", "li", "dt", "dd", "tr", "td", "th", "thead", "tbody", "tfoot",
        "h1", "h2", "h3", "h4", "h5", "h6"
    };
    return tags.count(tag) > 0;
}

// 扩展块级判定（包含 p/li/tr 等）
static bool is_extended_block_level(const std::string& tag) {
    if (is_block_level(/* 从 map_tag 转换 */)) return true;
    static const std::unordered_set<std::string> extra = {
        "p", "li", "dt", "dd", "tr", "td", "th", "thead", "tbody", "tfoot"
    };
    return extra.count(tag) > 0;
}

// should_auto_close 实现规则表（见规格 §2.2）
static bool should_auto_close(const std::string& parent, const std::string& new_tag) {
    if (parent == "p") return is_extended_block_level(new_tag);
    if (parent == "li") return new_tag == "li";
    if (parent == "dt") return new_tag == "dt" || new_tag == "dd";
    if (parent == "dd") return new_tag == "dt" || new_tag == "dd";
    if (parent == "tr") return new_tag == "tr";
    if (parent == "td") return new_tag == "td" || new_tag == "th" || new_tag == "tr";
    if (parent == "th") return new_tag == "td" || new_tag == "th" || new_tag == "tr";
    if (parent == "thead") return new_tag == "tbody" || new_tag == "tfoot";
    if (parent == "tbody") return new_tag == "tbody" || new_tag == "tfoot";
    if (parent == "tfoot") return new_tag == "tbody";
    if (tag == "h1" || tag == "h2" || tag == "h3" || tag == "h4" || tag == "h5" || tag == "h6") {
        return is_extended_block_level(new_tag);
    }
    return false;
}

// 行内格式化标签
static bool is_formatting_tag(const std::string& tag) {
    static const std::unordered_set<std::string> tags = {
        "b", "strong", "i", "em", "u", "s", "strike", "del",
        "a", "code", "mark", "sub", "sup", "span"
    };
    return tags.count(tag) > 0;
}

// 有格式语义的标签（adoption 实际重建）
static bool has_formatting_semantics(const std::string& tag) {
    static const std::unordered_set<std::string> tags = {
        "b", "strong", "i", "em", "u", "s", "strike", "del",
        "a", "code", "mark"
    };
    return tags.count(tag) > 0;
}

// 作用域边界标签
static bool is_scope_boundary(const std::string& tag) {
    static const std::unordered_set<std::string> tags = {
        "div", "blockquote", "pre", "table", "ul", "ol",
        "video", "audio", "article", "section", "header",
        "footer", "main", "nav", "aside"
    };
    return tags.count(tag) > 0;
}
```

注意：`tag_name` 已在任务 5 中改为 `std::string`，查表函数参数可直接用 `const std::string&`。

- [ ] **步骤 3：移除 `(void)autocorrect_;`，让 autocorrect_ 真正生效**

在 `TreeBuilder` 构造函数中删除 `(void)autocorrect_;` 这行。

- [ ] **步骤 4：构建并运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && for t in tests/test_*; do ./$t --gtest_brief=1; done`
预期：全部通过（新函数暂未调用，不影响行为）

- [ ] **步骤 5：Commit**

```bash
git add core/src/tree_builder.h core/src/tree_builder.cpp
git commit -m "feat(core): 标签分类查表函数 — auto_closable/formatting/scope_boundary"
```

---

### 任务 3：隐式关闭规则实现

**文件：**
- 修改：`core/src/tree_builder.cpp`
- 测试：`tests/test_tree_builder.cpp`

- [ ] **步骤 1：实现 perform_implicit_close()**

在 `tree_builder.cpp` 中添加：

```cpp
void TreeBuilder::perform_implicit_close(const std::string& new_tag) {
    size_t pop_count = 0;
    for (auto it = stack_.rbegin(); it != stack_.rend() - 1; ++it) {
        const auto& parent_tag = (*it)->tag_name;

        if (should_auto_close(parent_tag, new_tag)) {
            Logger::warn("implicit close: <%s> closed by <%s>", parent_tag.c_str(), new_tag.c_str());
            stack_.resize(stack_.size() - pop_count - 1);
            return;
        }

        if (is_scope_boundary(parent_tag)) {
            Logger::trace("implicit scan: scope boundary <%s> stops scan", parent_tag.c_str());
            break;
        }

        pop_count++;
    }
}
```

- [ ] **步骤 2：在 handle_start_tag() 中调用 perform_implicit_close**

在 `handle_start_tag()` 的 void 元素检查之后、深度限制检查之前插入调用：

```cpp
void TreeBuilder::handle_start_tag(const Token& tok) {
    // void 元素不入栈
    if (is_void_element(tok.tag_name)) { ... return; }

    // 【新增】隐式关闭检查（始终生效）
    perform_implicit_close(tok.tag_name);

    // 【新增】Adoption agency（enable_autocorrect 时生效）— 任务 4 实现
    // if (autocorrect_) perform_adoption_agency(tok.tag_name);

    // 深度限制检查
    if (stack_.size() >= static_cast<size_t>(max_depth_) + 1) return;

    // ... 原有入栈逻辑不变
}
```

- [ ] **步骤 3：在 handle_end_tag() 中添加 WARN 日志**

在 `handle_end_tag()` 的"未找到匹配"分支添加：

```cpp
// 未找到匹配，多余的闭合标签忽略（HTML 容错）
Logger::warn("extra close tag ignored: </%s>", tok.tag_name.c_str());
```

在 `build()` 方法末尾（`stack_.clear()` 前），检查栈中剩余的非 ROOT 元素并记录 WARN：

```cpp
// 未闭合标签自动补齐
if (stack_.size() > 1) {
    std::string unclosed;
    for (size_t i = 1; i < stack_.size(); i++) {
        if (i > 1) unclosed += ", ";
        unclosed += "<" + stack_[i]->tag_name + ">";
    }
    Logger::warn("unclosed tags auto-closed: [%s]", unclosed.c_str());
}
stack_.clear();
```

- [ ] **步骤 4：调整现有测试 MisnestedTags**

`test_tree_builder.cpp` 中的 `MisnestedTags` 测试需要调整预期，因为隐式关闭会改变树结构。先运行测试看哪些失败，然后按新行为更新断言。

- [ ] **步骤 5：新增隐式关闭测试**

在 `test_tree_builder.cpp` 添加 6 个测试：

```cpp
TEST_F(TreeBuilderTest, ImplicitClose_PSameP) {
    auto root = parse("<p>第一段<p>第二段</p>");
    // 两个 <p> 应该是平级，不是嵌套
    ASSERT_EQ(root.children.size(), 2u);
    EXPECT_EQ(root.children[0].tag_name, "p");
    EXPECT_EQ(root.children[1].tag_name, "p");
}

TEST_F(TreeBuilderTest, ImplicitClose_PBlockDiv) {
    auto root = parse("<p>text<div>block</div>");
    ASSERT_EQ(root.children.size(), 2u);
    EXPECT_EQ(root.children[0].tag_name, "p");
    EXPECT_EQ(root.children[1].tag_name, "div");
}

TEST_F(TreeBuilderTest, ImplicitClose_LILI) {
    auto root = parse("<ul><li>A<li>B</ul>");
    auto& ul = root.children[0];
    EXPECT_EQ(ul.tag_name, "ul");
    // 两个 <li> 应该是平级
    ASSERT_EQ(ul.children.size(), 2u);
    EXPECT_EQ(ul.children[0].tag_name, "li");
    EXPECT_EQ(ul.children[1].tag_name, "li");
}

TEST_F(TreeBuilderTest, ImplicitClose_DtDd) {
    auto root = parse("<dl><dt>term<dd>def</dl>");
    auto& dl = root.children[0];
    EXPECT_EQ(dl.tag_name, "dl");
    ASSERT_EQ(dl.children.size(), 2u);
    EXPECT_EQ(dl.children[0].tag_name, "dt");
    EXPECT_EQ(dl.children[1].tag_name, "dd");
}

TEST_F(TreeBuilderTest, ImplicitClose_TrTr) {
    auto root = parse("<table><tr><td>A</td></tr><tr><td>B</td></tr></table>");
    auto& table = root.children[0];
    auto& tbody = table.children[0]; // implicit tbody
    ASSERT_GE(tbody.children.size(), 2u);
}

TEST_F(TreeBuilderTest, ImplicitClose_ScopeBoundary) {
    auto root = parse("<div><p>text<p>more</div>");
    auto& div = root.children[0];
    // 第二个 <p> 关闭第一个，但不跳出 <div>
    ASSERT_EQ(div.children.size(), 2u);
    EXPECT_EQ(div.children[0].tag_name, "p");
    EXPECT_EQ(div.children[1].tag_name, "p");
}
```

注意：实际断言需要运行后根据真实树结构调整，尤其 `<table>` 的隐式 tbody 和 `<dl>` 的结构。

- [ ] **步骤 6：运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && for t in tests/test_*; do ./$t --gtest_brief=1; done`
预期：全部通过

- [ ] **步骤 7：Commit**

```bash
git add core/src/tree_builder.cpp tests/test_tree_builder.cpp
git commit -m "feat(core): HTML 隐式关闭规则 — 6 条规则 + scope boundary + WARN 日志"
```

---

### 任务 4：Adoption Agency Algorithm 实现

**文件：**
- 修改：`core/src/tree_builder.cpp`
- 测试：`tests/test_tree_builder.cpp`

- [ ] **步骤 1：实现 perform_adoption_agency()**

```cpp
void TreeBuilder::perform_adoption_agency(const std::string& new_tag) {
    // 只在块级元素触发
    if (!is_extended_block_level(new_tag)) return;

    // 从栈顶收集连续的行内格式化标签
    std::vector<std::string> all_collected;   // 所有格式化标签（含无语义）
    std::vector<std::string> rebuild_list;     // 有语义的重建列表

    size_t scan = stack_.size();
    while (scan > 1) {
        scan--;
        const auto& tag = stack_[scan]->tag_name;
        if (!is_formatting_tag(tag)) break;
        all_collected.push_back(tag);
        if (has_formatting_semantics(tag)) {
            rebuild_list.push_back(tag);
        }
    }

    if (rebuild_list.empty()) return;

    // 深度限制
    if (rebuild_list.size() > kMaxAdoptionDepth) {
        rebuild_list.resize(kMaxAdoptionDepth);
        Logger::warn("adoption depth truncated to %zu", kMaxAdoptionDepth);
    }

    // 日志
    std::string tags_str;
    for (size_t i = 0; i < rebuild_list.size(); i++) {
        if (i > 0) tags_str += ", ";
        tags_str += rebuild_list[i];
    }
    Logger::warn("adoption: [%s] rebuilt inside <%s>", tags_str.c_str(), new_tag.c_str());

    // 弹出所有收集到的标签（含无语义的）
    size_t pop_count = stack_.size() - scan - 1;
    stack_.resize(stack_.size() - pop_count);

    // 保存重建列表，在入栈阶段使用
    pending_adoption_ = std::move(rebuild_list);
}
```

- [ ] **步骤 2：修改 handle_start_tag() 的入栈阶段，处理 adoption 重建**

在 `handle_start_tag()` 中，取消任务 3 的注释，启用 adoption 调用：

```cpp
// 【新增】Adoption agency（enable_autocorrect 时生效）
if (autocorrect_) {
    perform_adoption_agency(tok.tag_name);
}
```

在节点入栈后，处理 `pending_adoption_` 重建：

```cpp
// 原有：创建节点、入栈
ASTNode elem;
elem.type = ASTNode::ELEMENT;
elem.tag_name = tok.tag_name;
elem.attributes = tok.attributes;
stack_.back()->children.push_back(std::move(elem));
stack_.push_back(&stack_.back()->children.back());

// 【新增】Adoption 重建行内格式化链
if (!pending_adoption_.empty()) {
    for (auto it = pending_adoption_.rbegin(); it != pending_adoption_.rend(); ++it) {
        ASTNode fmt_clone;
        fmt_clone.type = ASTNode::ELEMENT;
        fmt_clone.tag_name = *it;
        Logger::trace("adoption rebuild: pushing <%s> clone", it->c_str());
        stack_.back()->children.push_back(std::move(fmt_clone));
        stack_.push_back(&stack_.back()->children.back());
    }
    pending_adoption_.clear();
}
```

- [ ] **步骤 3：新增 Adoption 测试**

```cpp
TEST_F(TreeBuilderTest, Adoption_BasicBP) {
    auto root = parse("<div><b>text<p>para</p></b></div>");
    auto& div = root.children[0];
    // <b> 包含 "text"，<p> 包含 <b'> → "para"
    ASSERT_EQ(div.children.size(), 2u);
    EXPECT_EQ(div.children[0].tag_name, "b");
    EXPECT_EQ(div.children[1].tag_name, "p");
    // <p> 内应有重建的 <b>
    auto& p = div.children[1];
    ASSERT_FALSE(p.children.empty());
    EXPECT_EQ(p.children[0].tag_name, "b");
}

TEST_F(TreeBuilderTest, Adoption_MultiLayer) {
    auto root = parse("<div><b><i>text<p>para</p></i></b></div>");
    auto& div = root.children[0];
    ASSERT_EQ(div.children.size(), 2u);
    auto& p = div.children[1];
    EXPECT_EQ(p.tag_name, "p");
    // <p> 内应重建 <b> → <i>
    ASSERT_GE(p.children.size(), 1u);
    auto& b_clone = p.children[0];
    EXPECT_EQ(b_clone.tag_name, "b");
    ASSERT_GE(b_clone.children.size(), 1u);
    EXPECT_EQ(b_clone.children[0].tag_name, "i");
}

TEST_F(TreeBuilderTest, Adoption_SkipSpan) {
    auto root = parse("<div><span><b>text<p>para</p></b></span></div>");
    auto& div = root.children[0];
    auto& p = div.children[1];
    EXPECT_EQ(p.tag_name, "p");
    // 只重建 <b>，不重建 <span>
    ASSERT_GE(p.children.size(), 1u);
    EXPECT_EQ(p.children[0].tag_name, "b");
}

TEST_F(TreeBuilderTest, Adoption_Disabled) {
    // enable_autocorrect = false 时不触发 adoption
    Tokenizer tok("<div><b>text<p>para</p></b></div>");
    std::vector<Token> tokens;
    while (tok.has_next()) tokens.push_back(tok.next());
    TreeBuilder builder(256, false);  // autocorrect = false
    auto root = builder.build(tokens);
    auto& div = root.children[0];
    // <p> 应嵌套在 <b> 内（旧行为）
    ASSERT_EQ(div.children.size(), 1u);
    EXPECT_EQ(div.children[0].tag_name, "b");
}
```

注意：实际断言需要运行后根据树结构调整。

- [ ] **步骤 4：运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && for t in tests/test_*; do ./$t --gtest_brief=1; done`
预期：全部通过

- [ ] **步骤 5：Commit**

```bash
git add core/src/tree_builder.cpp tests/test_tree_builder.cpp
git commit -m "feat(core): Adoption Agency — 行内标签重建 + 深度限制 + 语义跳过"
```

---

### 任务 5：TRACE 日志插桩

**文件：**
- 修改：`core/src/tokenizer.cpp`
- 修改：`core/src/style_resolver.cpp`

- [ ] **步骤 1：Tokenizer TRACE 日志**

在 `tokenizer.cpp` 关键位置添加 Logger::trace 调用：

- `TAG_NAME` 状态读取标签名后：
  ```cpp
  Logger::trace("tag normalize: %.*s → %s", (int)raw_tag.size(), raw_tag.data(), tag_lower.c_str());
  ```
- `COMMENT` 状态跳过注释时：
  ```cpp
  Logger::trace("tokenizer: skipping comment");
  ```
- `skip_rawtext` 跳过 script/style 时：
  ```cpp
  Logger::trace("tokenizer: skipping rawtext for </%s>", end_tag);
  ```

添加 `#include "logger.h"`。

- [ ] **步骤 2：StyleResolver TRACE 日志**

在 `style_resolver.cpp` 关键位置添加：

- `map_tag()` 映射命中时：
  ```cpp
  Logger::trace("map tag: %s → XM_TAG_%d", tag_name.data(), map[tag_name]);
  ```
- `normalize_color()` 标准化后：
  ```cpp
  Logger::trace("normalize color: %.*s → %s", (int)value.size(), value.data(), result.c_str());
  ```
- `normalize_font_size()` 标准化后：
  ```cpp
  Logger::trace("normalize font-size: %.*s → %s", (int)value.size(), value.data(), result.c_str());
  ```

添加 `#include "logger.h"`。

- [ ] **步骤 3：运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && for t in tests/test_*; do ./$t --gtest_brief=1; done`
预期：全部通过（TRACE 日志不影响行为）

- [ ] **步骤 4：Commit**

```bash
git add core/src/tokenizer.cpp core/src/style_resolver.cpp
git commit -m "feat(core): TRACE 日志插桩 — tokenizer 状态转换 + style_resolver 标准化"
```

---

### 任务 6：更新设计规格文档

**文件：**
- 修改：`docs/superpowers/specs/2026-06-05-xmarkup-core-design.md`

- [ ] **步骤 1：更新 §3.1 公共头文件**

在 xmarkup.h 设计部分添加 `XMLogLevel`、`XMLogCallback`，更新 `XMConfig` 结构体定义。

- [ ] **步骤 2：更新 §4.2 自动纠错规则**

将现有的纠错规则表替换为完整的隐式关闭规则表 + adoption agency 描述 + scope boundary 说明 + `enable_autocorrect` 配置行为。

- [ ] **步骤 3：更新 §11.8 自动纠错场景**

更新 `<p><p>` 的预期输出（从嵌套改为平级），添加隐式关闭和 adoption 的输入→输出契约示例。

- [ ] **步骤 4：Commit**

```bash
git add docs/superpowers/specs/2026-06-05-xmarkup-core-design.md
git commit -m "docs: 更新核心设计规格 — 隐式关闭规则 + adoption agency + 日志系统"
```

---

### 任务 7：最终验证 + style_resolver 测试调整

**文件：**
- 可能修改：`tests/test_style_resolver.cpp`、`tests/test_api.cpp`

- [ ] **步骤 1：运行全量测试**

运行：`cd /Users/arcangelw/GitHub/XMarkup/build && cmake --build . && for t in tests/test_*; do ./$t --gtest_brief=1; done`

- [ ] **步骤 2：修复因隐式关闭行为变化导致的测试失败**

style_resolver 和 api 测试中的 span range 可能因隐式关闭改变了树结构而需要更新。逐个修复失败的断言。

- [ ] **步骤 3：运行 ASAN 构建**

运行：`cd /Users/arcangelw/GitHub/XMarkup && mkdir -p build-asan && cd build-asan && cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer" && cmake --build . && for t in tests/test_*; do ./$t --gtest_brief=1; done`
预期：无内存泄漏

- [ ] **步骤 4：Commit**

```bash
git add tests/ docs/
git commit -m "test: 适配隐式关闭行为变化的测试更新 + ASAN 验证"
```
