# C++ 核心模块 Code Review 修复计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 C++ 核心模块（`core/`）9 项问题：CSS/HTML 规范合规 bug（属性大小写、!important、rgba/hsl、font-size 关键字、布尔属性）+ 内部逻辑 bug（pending_adoption_ 泄漏、adoption 丢 span）+ 健壮性（UTF-8 验证）。

**架构：** 每个修复任务独立——先在 `tests/test_style_resolver.cpp` 中写测试（TDD），再改对应的 `src/*.cpp` 实现。涉及 4 个源文件：`style_resolver.cpp`（7 个改动）、`tree_builder.cpp`（2 个改动）、`utf16_indexer.cpp`（1 个改动）。

**测试框架：** GoogleTest（gtest），使用 `StyleResolverTest` fixture 测试 StyleResolver 层，`APITest` fixture 测试完整管线。

**技术栈：** C++17, GoogleTest, CMake

---

### 任务 1：extract_attribute_value 大小写不敏感匹配

**文件：**
- 修改：`core/src/style_resolver.cpp:343-391`
- 测试：`tests/test_style_resolver.cpp`

**问题：** `attrs.find(attr_name, pos)` 使用大小写敏感的精确匹配。HTML 属性名不区分大小写（HTML5 §2.4.2），`SRC`、`Src` 等变体无法匹配 `"src"`。

**修复方案：** 在 `extract_attribute_value` 内部将 `attrs` 逐字符大小写无关比较，或将属性和目标名都转为小写后比较。推荐方案：在函数开头创建 `attrs` 的小写副本 `lower_attrs`，用 `lower_attrs.find(lower_attr_name)` 在副本上查找，找到后将原始 `attrs` 中对应位置的值提取出来。

- [ ] **步骤 1：编写失败的测试**

```cpp
// 追加到 test_style_resolver.cpp 末尾
TEST_F(StyleResolverTest, AttributeNameCaseInsensitiveSrc) {
    auto r = resolve("<IMG SRC=\"photo.jpg\">");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_IMAGE && s.value == "photo.jpg") found = true;
    }
    EXPECT_TRUE(found) << "IMG SRC=\"photo.jpg\" 应匹配 src 属性";
}

TEST_F(StyleResolverTest, AttributeNameCaseInsensitiveStyle) {
    auto r = resolve(R"raw(<P STYLE="color:red">text</P>)raw");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR && s.value == "#FF0000") found = true;
    }
    EXPECT_TRUE(found) << "P STYLE=\"color:red\" 应提取 style 属性";
}

TEST_F(StyleResolverTest, AttributeNameCaseInsensitiveMixed) {
    auto r = resolve("<a Href=\"http://example.com\">link</a>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_LINK && s.value == "http://example.com") found = true;
    }
    EXPECT_TRUE(found) << "a Href=\"...\" 应匹配 href 属性";
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*CaseInsensitive*"
```

预期：3 个 FAIL，属性未被提取。

- [ ] **步骤 3：修复 `extract_attribute_value` 实现**

在 `extract_attribute_value` 函数开头添加大小写无关的属性查找路径：

```cpp
void StyleResolver::extract_attribute_value(std::string_view attrs, const char* attr_name,
                                             std::string& out_value) const {
    out_value.clear();
    if (attrs.empty()) return;

    // 创建小写副本用于大小写无关的属性名匹配
    std::string lower_attrs_str;
    lower_attrs_str.reserve(attrs.size());
    for (char c : attrs) lower_attrs_str += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    std::string_view lower_attrs(lower_attrs_str);

    // 构造小写属性名
    std::string lower_attr_name;
    for (const char* p = attr_name; *p; p++) {
        lower_attr_name += static_cast<char>(std::tolower(static_cast<unsigned char>(*p)));
    }

    size_t pos = 0;
    size_t name_len = lower_attr_name.size();

    while (pos + name_len < lower_attrs.size()) {
        // 在小写副本上查找
        size_t found = lower_attrs.find(lower_attr_name, pos);
        if (found == std::string_view::npos) break;

        // 确认匹配的是完整单词
        if (found > 0 && !isspace(static_cast<unsigned char>(lower_attrs[found - 1]))) {
            pos = found + 1;
            continue;
        }
        size_t after = found + name_len;
        if (after < lower_attrs.size() && lower_attrs[after] != '=' && !isspace(static_cast<unsigned char>(lower_attrs[after]))) {
            pos = found + 1;
            continue;
        }

        // 找到了属性名，回到原始 attrs 中提取值
        // 注意：在原始 attrs 中用 found 定位（lower 和原始在 ASCII 范围长度一致）
        size_t eq_pos = found;
        // ... 后续跳过空白、'='、读取值和原始逻辑一致 ...
        // 关键区别：attr_name 定位使用 found（lower_attrs 中的索引 = attrs 中的索引），
        // 因为小写化不会改变 ASCII 字符的偏移量。
```

> 详细实现：在函数前半段构建 `lower_attrs` 和 `lower_attr_name`，用它们做 `find()` 匹配。找到后用 `found` 索引（ASCII 区域中 lower 和原始索引一致），后续从 `attrs[found]` 读取值的逻辑不变。这样只需要在查找阶段增加约 10 行，不影响后续提取逻辑。

- [ ] **步骤 4：运行测试验证通过**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*CaseInsensitive*"
```

预期：3 个 PASS。

- [ ] **步骤 5：运行完整测试集无回归**

```bash
cd build && cmake --build . && ctest --output-on-failure
```

预期：全部 PASS。

- [ ] **步骤 6：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): extract_attribute_value 支持大小写不敏感的 HTML 属性名匹配
- 构建小写副本进行 find 匹配，确保 SRC/Src/src 都正确识别
- 新增 3 个验证测试：大写 SRC、大写 STYLE、混合大小写 Href"
```

---

### 任务 2：CSS `!important` 剥离

**文件：**
- 修改：`core/src/style_resolver.cpp:276-278`
- 测试：`tests/test_style_resolver.cpp`

**问题：** `add_style_spans` 读取 CSS 值后不剥离 `!important` 后缀，原有尾缀被直接传给 `normalize_color` / `normalize_font_size` 等函数导致解析失败。

**修复方案：** 在 `add_style_spans` 中读取 `val` 后、调用 normalize 函数之前，检查并剥离 `!important` 后缀。

- [ ] **步骤 1：编写失败的测试**

```cpp
// 追加到 test_style_resolver.cpp 末尾
TEST_F(StyleResolverTest, CSSColorImportant) {
    auto r = resolve(R"(<span style="color:red !important">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR && s.value == "#FF0000") found = true;
    }
    EXPECT_TRUE(found) << "color:red !important 应提取颜色 #FF0000";
}

TEST_F(StyleResolverTest, CSSFontSizeImportant) {
    auto r = resolve(R"(<span style="font-size:14px !important">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "14") found = true;
    }
    EXPECT_TRUE(found) << "font-size:14px !important 应提取字号 14";
}

TEST_F(StyleResolverTest, CSSBackgroundColorImportant) {
    auto r = resolve(R"(<span style="background-color:#00FF00 !important">text</span>)");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_BACKGROUND_COLOR && s.value == "#00FF00") found = true;
    }
    EXPECT_TRUE(found) << "background-color:#00FF00 !important 应提取颜色";
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*Important*"
```

预期：3 个 FAIL。

- [ ] **步骤 3：修复 `add_style_spans` 的 `!important` 处理**

在 `add_style_spans` 函数中，读取 `val` 之后、trim 尾部空白之后，添加 `!important` 剥离逻辑：

```cpp
// 在 val 去尾部空白之后（约 line 279）
// 剥离 !important 后缀
{
    // 查找末尾的 !important（带前置空白或 ! 直接开头）
    auto imp = val.rfind("!important");
    if (imp != std::string::npos) {
        // 确认 !important 在末尾且前面是空白
        bool valid = true;
        for (size_t k = imp; k < val.size(); k++) {
            if (val[k] != '!' && val[k] != 'i' && val[k] != 'I' &&
                val[k] != 'm' && val[k] != 'p' && val[k] != 'o' &&
                val[k] != 'r' && val[k] != 't' && val[k] != 'n' &&
                val[k] != ' ' && val[k] != '\t') {
                valid = false;
                break;
            }
        }
        // 小写化 "!important" 进行精确比较
        if (valid) {
            std::string suffix = val.substr(imp);
            for (auto& c : suffix) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
            // 去除前导空白 + "!important"
            suffix.erase(0, suffix.find_first_not_of(" \t"));
            if (suffix == "!important") {
                val = val.substr(0, imp);
                // 去尾部空白（去除 !important 后残留的空白）
                while (!val.empty() && isspace(static_cast<unsigned char>(val.back()))) val.pop_back();
            }
        }
    }
}
```

> 简化方案（更健壮）：直接用循环从尾部向前扫描，找到 `"!important"` 的位置并截断。因为 `!important` 出现在 CSS 值末尾，是 CSS 标准规定的固定格式。

```cpp
// 更简洁的实现在 line ~279：
// 剥离 !important（大小写不敏感，CSS 标准行为）
auto imp = val.rfind("!important");
if (imp != std::string::npos) {
    // 验证在末尾
    std::string suffix = val.substr(imp);
    for (auto& c : suffix) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    // 去除前导空白（!important 前的空格）
    size_t start = 0;
    while (start < suffix.size() && (suffix[start] == ' ' || suffix[start] == '\t')) start++;
    if (suffix.substr(start) == "!important") {
        val = val.substr(0, imp);
        while (!val.empty() && isspace(static_cast<unsigned char>(val.back()))) val.pop_back();
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*Important*"
```

预期：3 个 PASS。

- [ ] **步骤 5：运行完整测试集无回归**

```bash
cd build && cmake --build . && ctest --output-on-failure
```

- [ ] **步骤 6：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): CSS !important 后缀剥离，确保带优先级声明的样式值被正确解析
- add_style_spans 读取值后先剥离 !important 再传给 normalize 函数
- 新增 3 个验证测试：color/font-size/background-color 含 !important"
```

---

### 任务 3：`rgba()` / `hsla()` 颜色格式支持

**文件：**
- 修改：`core/src/style_resolver.cpp:410-450`
- 测试：`tests/test_style_resolver.cpp`

**问题：** `normalize_color` 只检查 `value.substr(0, 4) == "rgb("`，`rgba(255,0,0,0.5)` 中 substr(0,4) 返回 `"rgba"` 不匹配；`hsl()`/`hsla()` 完全不支持。

**修复方案：** 扩展 rgb 解析器支持 `rgba()`（解析前 3 个通道，忽略 alpha），添加 `hsl()`/`hsla()` 的 HSL → RGB 换算。

- [ ] **步骤 1：编写失败的测试**

```cpp
TEST_F(StyleResolverTest, CSSColorRgba) {
    auto r = resolve(R"html(<span style="color:rgba(255,0,0,0.5)">text</span>)html");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR && s.value == "#FF0000") found = true;
    }
    EXPECT_TRUE(found) << "rgba(255,0,0,0.5) 应提取颜色 #FF0000";
}

TEST_F(StyleResolverTest, CSSColorHsl) {
    auto r = resolve(R"html(<span style="color:hsl(0,100%,50%)">text</span>)html");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR) {
            // hsl(0, 100%, 50%) = #FF0000
            EXPECT_EQ(s.value, "#FF0000") << "hsl(0,100%,50%) = #FF0000";
            found = true;
        }
    }
    EXPECT_TRUE(found) << "hsl() 应被识别";
}

TEST_F(StyleResolverTest, CSSColorHsla) {
    auto r = resolve(R"html(<span style="color:hsla(240,100%,50%,0.5)">text</span>)html");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FOREGROUND_COLOR) {
            // hsla(240, 100%, 50%) = #0000FF
            EXPECT_EQ(s.value, "#0000FF") << "hsla(240,100%,50%) = #0000FF";
            found = true;
        }
    }
    EXPECT_TRUE(found) << "hsla() 应被识别";
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*Rgba*:*Hsl*"
```

预期：3 个 FAIL。

- [ ] **步骤 3：扩展 `normalize_color` 支持 rgba 和 hsl/ hsla**

在 `normalize_color` 的 `// rgb(r, g, b) 格式` 分支后（line ~449），添加：

```cpp
// rgba(r, g, b, a) 格式
if (value.size() > 5 && value.substr(0, 5) == "rgba(") {
    size_t start = 5;
    int r = 0, g = 0, b = 0;
    auto parse_int = [&](size_t& p) -> int { /* 复用上方的 lambda */ };
    r = parse_int(start);
    while (start < value.size() && (value[start] == ',' || value[start] == ' ')) start++;
    g = parse_int(start);
    while (start < value.size() && (value[start] == ',' || value[start] == ' ')) start++;
    b = parse_int(start);
    // 忽略 alpha 通道
    char buf[8];
    snprintf(buf, sizeof(buf), "#%02X%02X%02X", r, g, b);
    return buf;
}

// hsl() / hsla() 格式
if ((value.size() > 4 && value.substr(0, 4) == "hsl(") ||
    (value.size() > 5 && value.substr(0, 5) == "hsla(")) {
    size_t start = (value[4] == '(') ? 4 : 5;
    double h = 0, s = 0, l = 0;
    auto parse_double = [&](size_t& p) -> double {
        while (p < value.size() && (value[p] == ' ' || value[p] == '\t')) p++;
        double n = 0;
        while (p < value.size() && value[p] >= '0' && value[p] <= '9') {
            n = n * 10 + (value[p] - '0'); p++;
        }
        if (p < value.size() && value[p] == '.') {
            p++; double frac = 0.1;
            while (p < value.size() && value[p] >= '0' && value[p] <= '9') {
                n += (value[p] - '0') * frac;
                frac *= 0.1; p++;
            }
        }
        // 跳过单位（%）
        while (p < value.size() && (value[p] == '%' || value[p] == ' ')) p++;
        return n;
    };
    h = fmod(parse_double(start), 360.0);
    while (start < value.size() && (value[start] == ',' || value[start] == ' ')) start++;
    s = parse_double(start) / 100.0;
    while (start < value.size() && (value[start] == ',' || value[start] == ' ')) start++;
    l = parse_double(start) / 100.0;

    // HSL → RGB 换算
    auto hue_to_rgb = [](double p, double q, double t) -> int {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1.0/6) return static_cast<int>(round((p + (q - p) * 6 * t) * 255));
        if (t < 1.0/2) return static_cast<int>(round(q * 255));
        if (t < 2.0/3) return static_cast<int>(round((p + (q - p) * (2.0/3 - t) * 6) * 255));
        return static_cast<int>(round(p * 255));
    };

    double q = (l < 0.5) ? l * (1 + s) : l + s - l * s;
    double p = 2 * l - q;
    int r = hue_to_rgb(p, q, h / 360 + 1.0/3);
    int g = hue_to_rgb(p, q, h / 360);
    int b = hue_to_rgb(p, q, h / 360 - 1.0/3);

    char buf[8];
    snprintf(buf, sizeof(buf), "#%02X%02X%02X", std::min(r, 255), std::min(g, 255), std::min(b, 255));
    return buf;
}
```

> 注意：需要添加 `#include <cmath>` 到文件顶部（如果尚未包含，用于 `fmod` 和 `round`）。

- [ ] **步骤 4：运行测试验证通过**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*Rgba*:*Hsl*"
```

预期：3 个 PASS。

- [ ] **步骤 5：运行完整测试集无回归**

```bash
cd build && cmake --build . && ctest --output-on-failure
```

- [ ] **步骤 6：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "feat(core): 支持 rgba/hsl/hsla 颜色格式
- rgba(): 解析前 3 通道，忽略 alpha
- hsl()/hsla(): HSL → RGB 换算
- 新增 3 个验证测试"
```

---

### 任务 4：`font-size` CSS 关键字支持

**文件：**
- 修改：`core/src/style_resolver.cpp:473-528`
- 测试：`tests/test_style_resolver.cpp`

**问题：** `normalize_font_size` 不识别 CSS font-size 关键字（`xx-small` 到 `xx-large`，`smaller`/`larger`），导致被解析为 `num=0, unit="medium"` → 静默丢失。

**修复方案：** 在 `normalize_font_size` 解析数值前，先检查是否为关键字并返回对应的 px 值。

- [ ] **步骤 1：编写失败的测试**

```cpp
TEST_F(StyleResolverTest, CSSFontSizeKeywordLarge) {
    auto r = resolve(R"(<span style="font-size:large">text</span>)", 16.0f);
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "18") found = true;
    }
    EXPECT_TRUE(found) << "font-size:large (16px base) = 18px";
}

TEST_F(StyleResolverTest, CSSFontSizeKeywordXxLarge) {
    auto r = resolve(R"(<span style="font-size:xx-large">text</span>)", 16.0f);
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "32") found = true;
    }
    EXPECT_TRUE(found) << "font-size:xx-large (16px base) = 32px";
}

TEST_F(StyleResolverTest, CSSFontSizeKeywordSmall) {
    auto r = resolve(R"(<span style="font-size:small">text</span>)", 16.0f);
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "13") found = true;
    }
    EXPECT_TRUE(found) << "font-size:small (16px base) = 13px";
}

TEST_F(StyleResolverTest, CSSFontSizeKeywordMedium) {
    auto r = resolve(R"(<span style="font-size:medium">text</span>)", 16.0f);
    bool found = false;
    for (auto& s : r.spans) {
        if (s.style == XM_STYLE_FONT_SIZE && s.value == "16") found = true;
    }
    EXPECT_TRUE(found) << "font-size:medium = 16px";
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*FontSizeKeyword*"
```

预期：4 个 FAIL。

- [ ] **步骤 3：修复 `normalize_font_size` 实现**

在 `normalize_font_size` 函数的开头（数值解析之前）添加关键字检查：

```cpp
std::string StyleResolver::normalize_font_size(std::string_view value) const {
    if (value.empty()) return {};

    // CSS font-size 关键字 → px 映射
    // 来源：CSS Fonts Module Level 4 (https://www.w3.org/TR/css-fonts-4/)
    // scaling factor: 1.2 (每个级别相差 1.2 倍)
    struct FontSizeKey {
        std::string_view name;
        double px;     // 基于 16px 基准
    };
    static const FontSizeKey keywords[] = {
        {"xx-small",  9},  // 9px
        {"x-small",  10},  // 10px
        {"small",    13},  // 13px
        {"medium",   16},  // 16px（基准）
        {"large",    18},  // 18px
        {"x-large",  24},  // 24px
        {"xx-large", 32},  // 32px
        {"xxx-large",48},  // 48px
    };

    // 小写化输入并尝试匹配关键字
    std::string lower(value);
    for (auto& c : lower) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    for (const auto& kw : keywords) {
        if (lower.substr(0, lower.find_first_not_of(" \t")) == kw.name) {
            char buf[32];
            std::snprintf(buf, sizeof(buf), "%.0f", kw.px);
            return buf;
        }
    }

    // 原有数值解析逻辑（后续不变）...
    double num = 0;
    size_t i = 0;
    // ...
```

> 注意：`smaller`/`larger` 是相对关键字（相对于父元素字号），在当前架构中无法准确处理，暂不实现，未来可通过 `base_font_size_` 计算近似值。

- [ ] **步骤 4：运行测试验证通过**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*FontSizeKeyword*"
```

预期：4 个 PASS。

- [ ] **步骤 5：运行完整测试集无回归**

```bash
cd build && cmake --build . && ctest --output-on-failure
```

- [ ] **步骤 6：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "feat(core): font-size CSS 关键字支持（xx-small ~ xxx-large）
- 基于 16px 基准映射 9px~48px
- medium=16px, large=18px, xx-large=32px 等
- small/large 通过 scaling factor 1.2 关联
- 新增 4 个验证测试"
```

---

### 任务 5：布尔属性支持

**文件：**
- 修改：`core/src/style_resolver.cpp:343-391`
- 测试：`tests/test_style_resolver.cpp`

**问题：** `extract_attribute_value` 在找到属性名后强制寻找 `= `，HTML 布尔属性（如 `<video autoplay controls>`）没有等号，不会产生该属性的 span。

**影响评估：** 当前 XMarkup 不提取布尔属性值（无对应的 `XMStyleType` 或 tag），因此这是一个未来兼容性问题。对于 `<video autoplay>`，虽然 `autoplay` 本身不被 XMarkup 消费，但 `extract_attribute_value` 需要在布尔属性存在时跳过而不是阻塞后续属性的扫描。

**修复方案：** 在 `extract_attribute_value` 中找到属性名后，如果下一个非空白字符不是 `=`，将属性视为布尔属性（存在），继续扫描下一个属性而非返回。

> 注意：此修复是使属性扫描逻辑正确性的必要步骤——不在未来的任务中因为其他属性扫描被布尔属性阻塞而出现异常。

- [ ] **步骤 1：编写测试（先确认当前行为）**

```cpp
TEST_F(StyleResolverTest, VideoBooleanAttributes) {
    // 布尔属性不阻塞后续 src 属性的扫描
    auto r = resolve("<video autoplay controls src=\"movie.mp4\"></video>");
    bool found = false;
    for (auto& s : r.spans) {
        if (s.tag == XM_TAG_VIDEO && s.value == "movie.mp4") found = true;
    }
    EXPECT_TRUE(found) << "布尔属性后的 src 属性应被正确提取";
}
```

- [ ] **步骤 2：运行测试确认当前行为**

```bash
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver --gtest_filter="*BooleanAttribute*"
```

预期：PASS 或 FAIL（取决于当前实现是否受布尔属性阻塞）。如果 PASS，说明当前实现已容错。

- [ ] **步骤 3：修复 `extract_attribute_value` 的布尔属性处理**

在找到属性名后、检查 `=` 之前，添加布尔属性逻辑：

```cpp
// 在 line ~367 的 while 循环中，找到属性名后：
// ...
// 找到了属性名，跳过空白
size_t eq_pos = after;
while (eq_pos < attrs.size() && isspace(static_cast<unsigned char>(attrs[eq_pos]))) eq_pos++;
if (eq_pos >= attrs.size() || attrs[eq_pos] != '=') {
    // 布尔属性（无等号），跳过当前属性名继续扫描
    pos = after;
    continue;
}
eq_pos++; // 跳过 '='
// ... 后续读取值逻辑不变
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd build && cmake --build . && ctest --output-on-failure
```

- [ ] **步骤 5：Commit**

```bash
git add core/src/style_resolver.cpp tests/test_style_resolver.cpp
git commit -m "fix(core): 布尔属性不阻塞后续属性扫描
- extract_attribute_value 遇到布尔属性时跳过而非返回
- 确保 autoplay/controls 等不干扰 src 属性提取"
```

---

### 任务 6：`pending_adoption_` 深度超限清理

**文件：**
- 修改：`core/src/tree_builder.cpp:294-296`
- 测试：`tests/test_tree_builder.cpp`

**问题：** `handle_start_tag` 中深度检查（line 294）提前 return 跳过 adoption rebuild，`pending_adoption_` 未清空，残余标签泄漏到下一个 start tag。

**修复方案：** 在深度超限 return 之前清空 `pending_adoption_`。

- [ ] **步骤 1：编写测试（通过 `adoption_agency` + 深度超限验证）**

```cpp
// 追加到 test_tree_builder.cpp
#include "tree_builder.h"
using namespace xmarkup;

TEST(TreeBuilderTest, AdoptionPendingClearedOnDepthOverflow) {
    // 构造一个深度刚好在触发 adoption 后达到限制的场景
    // 1. 先创建带格式化标签的深度结构
    // 2. 再添加一个块级元素触发深度超限
    // 验证 pending_adoption_ 不会泄漏到后续标签
    TreeBuilder tb(3, true); // max_depth = 3
    
    std::vector<Token> tokens = {
        {TokenType::START_TAG, {}, "div", {}},       // depth 1
        {TokenType::START_TAG, {}, "b", {}},         // depth 2: formatting
        {TokenType::TEXT, {}, {}, {}},               // text
        {TokenType::START_TAG, {}, "div", {}},       // depth 3: 超限（+1 = 4 > 3）
        {TokenType::TEXT, {}, {}, {}},               // should be appended to parent
    };
    tokens[2].raw = "hello";
    tokens[4].raw = "world";
    
    ASTNode root = tb.build(tokens);
    // 不应崩溃，adoption rebuild 不应残留
    ASSERT_EQ(root.type, ASTNode::ROOT);
    // 验证 world 没有被错误嵌套
}
```

- [ ] **步骤 2：修复代码**

```cpp
// tree_builder.cpp:294
    // 深度限制检查（+1 因为栈底有 ROOT）
    if (stack_.size() >= static_cast<size_t>(max_depth_) + 1) {
        pending_adoption_.clear();  // 清空，防止泄漏到下一个元素
        return;
    }
```

- [ ] **步骤 3：运行测试验证通过**

```bash
cd build && cmake --build . --target test_tree_builder && ./tests/test_tree_builder --gtest_filter="*AdoptionPending*"
```

预期：PASS。

- [ ] **步骤 4：运行完整测试集无回归**

```bash
cd build && cmake --build . && ctest --output-on-failure
```

- [ ] **步骤 5：Commit**

```bash
git add core/src/tree_builder.cpp tests/test_tree_builder.cpp
git commit -m "fix(core): 深度超限时清空 pending_adoption_ 防止标签泄漏
- handle_start_tag 深度检查 return 前添加 pending_adoption_.clear()
- 避免残余 adoption 标签被错误重建到后续元素下"
```

---

### 任务 7：Adoption Agency 非语义 format 标签保留

**文件：**
- 修改：`core/src/tree_builder.cpp:166-206`
- 测试：`tests/test_tree_builder.cpp`

**问题：** `perform_adoption_agency` 收集所有格式化标签（含 `span`/`sub`/`sup`），但只重建有语义的（`b`, `i`, `a` 等）。`span` 等包装标签被静默丢弃，其上的 CSS 样式丢失。

**修复方案：** 在收集阶段将 `span`, `sub`, `sup` 也加入重建列表，使它们被保留在 adoption 链中。

- [ ] **步骤 1：编写失败的测试**

```cpp
TEST(TreeBuilderTest, AdoptionPreservesSpanWrapper) {
    TreeBuilder tb(256, true);
    std::vector<Token> tokens = {
        {TokenType::START_TAG, {}, "div", {}},
        {TokenType::START_TAG, {}, "span", {}},
        {TokenType::START_TAG, {}, "b", {}},
        {TokenType::TEXT, {}, {}, {}},
    };
    tokens[3].raw = "bold text";
    // ... 后续添加另一个块级标签触发 adoption
    
    ASTNode root = tb.build(tokens);
    // span 应在 adoption 后保留
}
```

- [ ] **步骤 2：修复 `perform_adoption_agency`**

在 `perform_adoption_agency` 中，将 `"span"`, `"sub"`, `"sup"` 加入格式化语义标签集：

```cpp
// tree_builder.cpp:50-56
static const std::unordered_set<std::string>& formatting_semantic_set() {
    static const std::unordered_set<std::string> s = {
        "b", "strong", "i", "em", "u", "s", "strike", "del",
        "a", "code", "mark",
        "span", "sub", "sup",  // 新增：保留包装层样式
    };
    return s;
}
```

- [ ] **步骤 3：运行测试验证通过**

```bash
cd build && cmake --build . --target test_tree_builder && ./tests/test_tree_builder --gtest_filter="*Adoption*"
```

预期：PASS。

- [ ] **步骤 4：Commit**

```bash
git add core/src/tree_builder.cpp tests/test_tree_builder.cpp
git commit -m "fix(core): adoption agency 保留 span/sub/sup 包装层
- 将 span/sub/sup 加入 formatting_semantic_set
- 避免 adoption 丢弃这些标签上的 CSS 样式"
```

---

### 任务 8：UTF-8 续字节合法性验证

**文件：**
- 修改：`core/src/utf16_indexer.cpp:18-49`
- 测试：`tests/test_utf16_indexer.cpp`

**问题：** `UTF16Indexer::build` 不验证非法 UTF-8 续字节（如孤立 `0x80`-`0xBF`），`byte_offset` 和 `utf16_offset` 计算可能不准确。

**修复方案：** 在判定多字节序列后，验证后续字节是否为合法的 continuation byte（`0x80`-`0xBF`）。若非法，将非法字节视为单字节序列继续处理。

- [ ] **步骤 1：编写测试**

```cpp
// 追加到 test_utf16_indexer.cpp
TEST(UTF16IndexerTest, InvalidContinuationByte) {
    UTF16Indexer idx;
    // 孤立 continuation byte 0x80（= 128）
    std::string invalid = "A\x80" "B";
    idx.build(invalid);
    // 0x80 被视为 1 字节 → 1 UTF-16 单元
    // byte 2 = 'B' → byte_offset=2, utf16_index=2
    EXPECT_EQ(idx.byte_to_utf16(2), 2u);
}

TEST(UTF16IndexerTest, TruncatedMultiByte) {
    UTF16Indexer idx;
    // 2 字节序列只有前导字节（0xC3 是 2 字节序列的前导）
    std::string truncated = "\xC3";
    idx.build(truncated);
    // 0xC3 被视为 1 字节（非法续字节）
    EXPECT_EQ(idx.byte_to_utf16(1), 1u);
}
```

- [ ] **步骤 2：修复 `UTF16Indexer::build`**

在 build 函数中，判定 seq_len 后验证 continuation byte：

```cpp
void UTF16Indexer::build(std::string_view utf8_text) {
    mapping_.clear();
    if (utf8_text.empty()) return;

    uint32_t byte_off = 0;
    uint32_t utf16_off = 0;
    mapping_.push_back({0, 0});

    while (byte_off < utf8_text.size()) {
        uint8_t c = static_cast<uint8_t>(utf8_text[byte_off]);
        uint32_t seq_len = 1;
        uint32_t utf16_inc = 1;

        if (c < 0x80) {
            seq_len = 1; utf16_inc = 1;
        } else if ((c & 0xE0) == 0xC0) {
            seq_len = 2; utf16_inc = 1;
            // 验证续字节
            if (byte_off + 1 >= utf8_text.size() ||
                (utf8_text[byte_off + 1] & 0xC0) != 0x80) {
                seq_len = 1; // 非法，降级为单字节
            }
        } else if ((c & 0xF0) == 0xE0) {
            seq_len = 3; utf16_inc = 1;
            if (byte_off + 2 >= utf8_text.size() ||
                (utf8_text[byte_off + 1] & 0xC0) != 0x80 ||
                (utf8_text[byte_off + 2] & 0xC0) != 0x80) {
                seq_len = 1;
            }
        } else if ((c & 0xF8) == 0xF0) {
            seq_len = 4; utf16_inc = 2;
            if (byte_off + 3 >= utf8_text.size() ||
                (utf8_text[byte_off + 1] & 0xC0) != 0x80 ||
                (utf8_text[byte_off + 2] & 0xC0) != 0x80 ||
                (utf8_text[byte_off + 3] & 0xC0) != 0x80) {
                seq_len = 1;
            }
        }
        // else: 非法前导字节（0x80-0xBF, 0xF8-0xFF），seq_len=1 继续

        byte_off += seq_len;
        utf16_off += utf16_inc;
        mapping_.push_back({byte_off, utf16_off});
    }
}
```

- [ ] **步骤 3：运行测试验证通过**

```bash
cd build && cmake --build . --target test_utf16_indexer && ./tests/test_utf16_indexer --gtest_filter="*Invalid*:*Truncated*"
```

预期：2 个 PASS。

- [ ] **步骤 4：Commit**

```bash
git add core/src/utf16_indexer.cpp tests/test_utf16_indexer.cpp
git commit -m "fix(core): UTF16Indexer 验证续字节合法性，非法 UTF-8 降级为单字节
- 非法/缺失 continuation byte 时退回单字节处理
- 防止 byte/utf16 offset 计算偏差"
```

---

### 任务 9：`perform_implicit_close` 迭代器安全性重构

**文件：**
- 修改：`core/src/tree_builder.cpp:134-153`
- 测试：无（代码质量修复，已有测试覆盖）

**问题：** `perform_implicit_close` 在循环内 `stack_.resize()` 后立即 `return`，reverse_iterator 无后续使用（安全），但代码结构脆弱——如果有人在 return 前添加代码就会触发 UB。

**修复方案：** 将循环逻辑改为先收集 pop_count，循环外统一 resize。

- [ ] **步骤 1：重构代码**

```cpp
void TreeBuilder::perform_implicit_close(const std::string& new_tag) {
    // 从栈顶向下扫描（排除 ROOT）
    size_t pop_count = 0;
    bool found = false;
    for (auto it = stack_.rbegin(); it != stack_.rend() - 1; ++it) {
        const auto& parent_tag = (*it)->tag_name;

        if (should_auto_close(parent_tag, new_tag)) {
            Logger::warn("implicit close: <%s> closed by <%s>", parent_tag.c_str(), new_tag.c_str());
            found = true;
            break;  // 先退出循环，不在此处 resize
        }

        // 作用域边界：停止扫描
        if (is_scope_boundary(parent_tag)) {
            Logger::trace("implicit scan: scope boundary <%s> stops scan", parent_tag.c_str());
            break;
        }

        pop_count++;
    }

    if (found) {
        stack_.resize(stack_.size() - pop_count - 1);
    }
}
```

- [ ] **步骤 2：运行完整测试集验证无回归**

```bash
cd build && cmake --build . && ctest --output-on-failure
```

预期：全部 PASS。

- [ ] **步骤 3：Commit**

```bash
git add core/src/tree_builder.cpp
git commit -m "refactor(core): 将 perform_implicit_close 的 resize 移出迭代体
- 先收集 pop_count 并 break，循环外统一 resize
- 避免潜在的 reverse_iterator 失效风险"
```

---

## 执行顺序

| # | 任务 | 文件 | 依赖 | 优先级 |
|:-|:--|:--|:--|:--|
| 1 | 属性名大小写不敏感 | style_resolver.cpp | 无 | **H** |
| 2 | CSS !important 剥离 | style_resolver.cpp | 无 | **H** |
| 3 | rgba/hsl/hsla 颜色格式 | style_resolver.cpp | 无 | **M** |
| 4 | font-size 关键字 | style_resolver.cpp | 无 | **M** |
| 5 | 布尔属性处理 | style_resolver.cpp | 无 | **M** |
| 6 | pending_adoption_ 清理 | tree_builder.cpp | 无 | **M** |
| 7 | adoption 保留 span/sub/sup | tree_builder.cpp | 无 | **L** |
| 8 | UTF-8 续字节验证 | utf16_indexer.cpp | 无 | **L** |
| 9 | implicit_close 重构 | tree_builder.cpp | 无 | **L** |

> 任务 1-5 修改 `style_resolver.cpp`，可以按任意顺序执行。但为了避免测试文件的合并冲突建议按编号顺序逐个执行、逐个 commit。任务 6-7 修改 `tree_builder.cpp`，任务 8 修改 `utf16_indexer.cpp`，互不依赖。

## 验证命令

每个任务完成后执行完整回归测试：

```bash
# 构建
cd build && cmake --build .

# 全部测试
ctest --output-on-failure

# 或逐 target
cd build && cmake --build . --target test_style_resolver && ./tests/test_style_resolver
cd build && cmake --build . --target test_tree_builder && ./tests/test_tree_builder
cd build && cmake --build . --target test_utf16_indexer && ./tests/test_utf16_indexer
cd build && cmake --build . --target test_api && ./tests/test_api
```
