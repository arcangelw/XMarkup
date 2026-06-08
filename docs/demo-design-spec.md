# XMarkup Demo App 设计规范

> 本文档定义 XMarkup Demo App 的 UI 设计规范，确保 SwiftUI、UIKit、AppKit 三端展示效果一致。
> 新增或修改 Demo 页面时，必须严格遵循此规范。

## 1 页面结构

### 1.1 示例列表页

| 属性 | 规范 |
|------|------|
| 标题 | "XMarkup Demo" |
| 列表样式 | 分组列表（Grouped / insetGrouped） |
| 分组方式 | 按 `DemoExample.Category` 分组，每组一个 Section |
| 列表项 | 标题（headline） + 描述（caption, secondary） |

### 1.2 示例详情页

采用**三段 Tab** 布局，每个 Tab 独占全部可用空间：

```
┌──────────────────────────────────┐
│  < 返回       示例标题            │
├──────────────────────────────────┤
│ [HTML 源码] [渲染效果] [Span 数据] │  ← Segmented Control
├──────────────────────────────────┤
│                                  │
│    当前 Tab 的全屏内容            │  ← 占据全部剩余空间
│    （不受其他 Tab 内容长度影响）   │     可独立滚动
│                                  │
└──────────────────────────────────┘
```

**布局参数：**

| 属性 | 规范 |
|------|------|
| Segmented Control 水平边距 | 16pt |
| Segmented Control 垂直边距 | 8pt（上下） |
| Segmented Control 与内容区间距 | 8pt（Divider 后） |
| 内容区 | 四边锚定父容器，独占全部剩余空间 |
| 默认选中 Tab | 0（HTML 源码） |

## 2 Tab 内容规范

### 2.1 HTML 源码 Tab

| 属性 | 规范 |
|------|------|
| 字体 | 等宽 12pt（monospacedSystemFont / .system(size: 12, design: .monospaced)） |
| 文字颜色 | secondaryLabel / .secondary |
| 背景色 | 默认背景（systemBackground） |
| 水平内边距 | 16pt |
| 垂直内边距 | 8pt |
| 滚动 | 支持纵向滚动 |
| 文本选择 | 启用（方便复制） |

### 2.2 渲染效果 Tab

| 属性 | 规范 |
|------|------|
| 渲染引擎 | UITextView，`isScrollEnabled = true` |
| 水平内边距 | `textContainerInset.left/right = 16pt` |
| 垂直内边距 | `textContainerInset.top/bottom = 8pt` |
| 背景色 | 透明（.clear） |
| 调用 | `textView.configureForXMarkup()` 清除默认链接样式 |
| 默认配置 | `XMarkupStyleConfig.default` 主题 |
| 滚动 | UITextView 自管滚动，内容溢出时自动生效 |

### 2.3 Span 数据 Tab

| 属性 | 规范 |
|------|------|
| 列表样式 | insetGrouped |
| Section 1 | "纯文本" — 显示解析后的纯文本 |
| Section 2 | "Span 列表（N 个）" — 逐条展示每个 Span 的 tag/style/range/value |
| 字体 | 等宽字体展示技术数据 |

## 3 颜色规范

### 3.1 系统颜色映射

| 用途 | UIKit | AppKit | SwiftUI |
|------|-------|--------|---------|
| 页面背景 | systemBackground | windowBackgroundColor | 自动 |
| 辅助文字 | secondaryLabel | secondaryLabelColor | .secondary |
| 分隔线 | separator | separatorColor | Divider |
| 代码背景 | systemGray6 | systemGray(0.15 alpha) | Color(.systemGray6) |
| 高亮背景 | systemYellow(0.3) | systemYellow(0.3) | Color(.systemYellow).opacity(0.3) |
| 链接颜色 | link / linkColor | linkColor | Color(.link) / .linkColor |

### 3.2 `<code>` 标签颜色

| 模式 | UIKit | AppKit |
|------|-------|--------|
| 浅色 | systemGray6（#F2F2F7） | systemGray(alpha 0.15) |
| 深色 | systemGray（自适应） | systemGray(alpha 0.3) |

## 4 字体规范

| 场景 | 字体 | 字号 |
|------|------|------|
| 基础正文 | systemFont | 16pt |
| HTML 源码 | monospacedSystemFont | 12pt |
| 代码内容（code 标签） | Menlo / monospacedSystemFont | 继承基础字号 |
| 列表页标题 | headline | 系统 |
| 列表页描述 | caption | 系统 |
| 标题 H1~H6 | systemFont(bold) | 基础字号 × 2.0 / 1.5 / 1.17 / 1.0 / 0.83 / 0.67 |

## 5 间距规范

| 场景 | 值 |
|------|-----|
| 列表页水平边距 | 16pt |
| 详情页 Segmented Control 边距 | 16pt 水平，8pt 垂直 |
| 渲染区水平内边距 | 16pt |
| 渲染区垂直内边距 | 8pt |
| HTML 源码区边距 | 16pt 水平，8pt 垂直 |

## 6 交互规范

| 场景 | 规范 |
|------|------|
| Tab 切换 | Segmented Control，切换时内容区无动画（直接显示/隐藏） |
| 渲染区滚动 | UITextView 自管滚动，弹性滚动 |
| HTML 源码选择 | 启用文本选择 |
| 链接点击 | UITextView 中直接可点击跳转 |
| 列表页导航 | NavigationLink / didSelectRow → push 详情页 |

## 7 文件结构

### 7.1 SwiftUI（`XMarkupDemo/SwiftUI/`）

```
App.swift                  — @main 入口
ContentView.swift          — 示例列表
ExampleDetailView.swift    — 详情页（三段 Tab 容器）
HTMLSourceView.swift       — Tab 0：HTML 源码
RenderedTextView.swift     — Tab 1：渲染效果（UIViewRepresentable）
SpanDataView.swift         — Tab 2：Span 数据列表
```

### 7.2 UIKit（`XMarkupDemo/UIKit/`）

```
AppDelegate.swift              — UIApplicationMain
SceneDelegate.swift            — UISceneSession lifecycle
ExamplesListViewController.swift — 示例列表（UITableView）
ExampleDetailViewController.swift — 详情页（三段 Tab 容器）
HTMLSourceViewController.swift — Tab 0：HTML 源码
RenderedTextViewController.swift — Tab 1：渲染效果
SpanDataViewController.swift   — Tab 2：Span 数据列表
```

### 7.3 AppKit（`XMarkupDemo/AppKit/`）

```
（待实现，遵循相同的页面结构和设计规范）
```

### 7.4 共享数据（`XMarkupDemo/Shared/`）

```
DemoExamples.swift         — 示例数据源（三端共用）
```

## 8 设计决策记录

| 日期 | 决策 | 原因 |
|------|------|------|
| 2026-06-08 | 采用三段 Tab 替代顶部 HTML + 底部内容布局 | 长内容时 HTML 源码挤压渲染区，三段 Tab 每个视图独占全部空间 |
| 2026-06-08 | SwiftUI 渲染区用 UITextView(isScrollEnabled: true) | UIScrollView 内 UIViewRepresentable 宽度约束不可靠，UITextView 自管滚动更可靠 |
| 2026-06-08 | `<code>` 标签添加默认背景色 | HTML 规范中行内代码应有视觉区分，仅等宽字体不够 |
| 2026-06-08 | 链接颜色在 Pass 2 主动设置，linkTextAttributes 清空 | 避免 UITextView 覆盖自定义链接颜色 |
