import SwiftUI
import XMarkup

/// 对比详情：原生 vs Web（设计规格 §6.4 / P2-1 工具栏 + 实时联动）
///
/// - 对比模式（内容区顶部 Segmented）：自动（sizeClass）/ 并排 / 堆叠
/// - 画布配置/主题：iOS 半屏 sheet / macOS popover（PopoverAdapter）
/// - themeVariants 用例：原生区纵向多主题对比
/// - 顶部 note banner；ladybug 调试抽屉；6 组键盘快捷键
struct CompareDetailView: View {
    let example: DemoExample

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var config = DemoCanvasConfig()
    @State private var compareMode: CompareMode = .auto
    @State private var themeOverride: MarkupTheme?
    @State private var nativeAttr: NSAttributedString?
    @State private var nativeVariants: [NSAttributedString]?
    @State private var variantsThemes: [MarkupTheme]?
    @State private var error: String?
    @State private var document: MarkupDocument?
    @State private var showDebug = false
    @State private var showCanvasConfig = false
    @State private var showTheme = false

    private enum CompareMode: String, CaseIterable, Identifiable {
        case auto = "自动"
        case sideBySide = "并排"
        case stacked = "堆叠"
        var id: String { rawValue }
    }

    private let themePresets: [MarkupTheme] = [.default, .dark, .article, .chat]

    var body: some View {
        content
            .navigationTitle(example.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task(id: example.id) { render() }
            .onChange(of: config) { _ in render() }
            .onChange(of: themeOverride) { _ in render() }
            .background(shortcutButtons)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showCanvasConfig.toggle()
                    } label: {
                        Label("画布", systemImage: "slider.horizontal.3")
                    }
                    .popoverAdaptive(isPresented: $showCanvasConfig) {
                        CanvasConfigPanel(config: $config)
                    }

                    Button {
                        showTheme.toggle()
                    } label: {
                        Label("主题", systemImage: "paintpalette")
                    }
                    .popoverAdaptive(isPresented: $showTheme, macOSWidth: 240) {
                        themePopover
                    }
                    .disabled(example.themeVariants != nil)

                    Button {
                        showDebug.toggle()
                    } label: {
                        Label("调试", systemImage: "ladybug")
                    }
                    .accessibilityLabel("调试抽屉")
                }
            }
            .sheet(isPresented: $showDebug) {
                DebugDrawer(
                    example: example,
                    document: document,
                    attributedString: nativeAttr ?? nativeVariants?.first
                )
            }
    }

    /// 隐藏快捷键按钮组（全局键盘快捷键，macOS 生效；iOS 无键盘无害）
    /// cmd+K 画布 / cmd+T 主题 / cmd+D 调试 / cmd+0,1,2 对比模式
    /// 注：plan cmd+, 与 macOS Settings 冲突，改 cmd+K
    @ViewBuilder
    private var shortcutButtons: some View {
        Group {
            Button("画布配置") { showCanvasConfig.toggle() }.keyboardShortcut("k", modifiers: .command)
            Button("主题") { showTheme.toggle() }.keyboardShortcut("t", modifiers: .command)
            Button("调试") { showDebug.toggle() }.keyboardShortcut("d", modifiers: .command)
            Button("自动对比") { compareMode = .auto }.keyboardShortcut("0", modifiers: .command)
            Button("并排对比") { compareMode = .sideBySide }.keyboardShortcut("1", modifiers: .command)
            Button("堆叠对比") { compareMode = .stacked }.keyboardShortcut("2", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    // MARK: - 布局

    private var useSideBySide: Bool {
        switch compareMode {
        case .auto: return sizeClass == .regular
        case .sideBySide: return true
        case .stacked: return false
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error {
            errorView(error)
        } else if nativeVariants != nil || nativeAttr != nil {
            compareLayout
        } else {
            ProgressView("渲染中…")
        }
    }

    @ViewBuilder
    private var compareLayout: some View {
        VStack(spacing: 0) {
            noteBanner
            compareModePicker
            Divider()
            if useSideBySide {
                HStack(spacing: 0) {
                    labeledPanel("原生", systemImage: "text.alignleft", content: nativePanel)
                    Divider()
                    labeledPanel("Web", systemImage: "globe", content: webPanel)
                }
            } else {
                TabView {
                    nativePanel
                        .tabItem { Label("原生", systemImage: "text.alignleft") }
                    webPanel
                        .tabItem { Label("Web", systemImage: "globe") }
                }
            }
        }
    }

    /// 对比模式切换（从 toolbar 移到内容区顶部，避免 iOS toolbar 挤占 title）
    private var compareModePicker: some View {
        Picker("对比模式", selection: $compareMode) {
            ForEach(CompareMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var themePopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("主题").font(.headline).padding(.bottom, 4)
            ForEach(Array(themePresets.enumerated()), id: \.offset) { _, theme in
                Button {
                    themeOverride = theme
                    showTheme = false
                } label: {
                    HStack {
                        Text(themeLabel(theme))
                        Spacer()
                        if themeOverride == theme {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
            Divider()
            Button {
                themeOverride = nil
                showTheme = false
            } label: {
                Text("跟随用例默认").frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var noteBanner: some View {
        if let note = example.note {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: example.isRegression ? "info.circle.fill" : "lightbulb.fill")
                Text(note)
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.yellow.opacity(0.15))
        }
    }

    @ViewBuilder
    private var nativePanel: some View {
        if let variants = nativeVariants, let themes = variantsThemes {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(variants.enumerated()), id: \.offset) { idx, attr in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(themeLabel(themes[idx]))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            NativeRenderView(attributedString: attr, config: config)
                                .frame(minHeight: 80)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if let attr = nativeAttr {
            NativeRenderView(attributedString: attr, config: config)
        }
    }

    @ViewBuilder
    private var webPanel: some View {
        WebRenderView(example: example, config: config)
    }

    private func labeledPanel<C: View>(_ title: String, systemImage: String, content: C) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label(title, systemImage: systemImage).font(.caption.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            Divider()
            content
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "xmark.octagon.fill").font(.title).foregroundStyle(.red)
            Text("渲染失败").font(.headline)
            Text(msg).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - 渲染

    private func render() {
        do {
            let doc = try DemoRenderer.parse(example)
            document = doc
            if let themes = example.themeVariants, !themes.isEmpty {
                variantsThemes = themes
                nativeVariants = DemoRenderer.renderVariants(document: doc, config: config, themes: themes)
                nativeAttr = nil
            } else {
                nativeAttr = DemoRenderer.render(document: doc, config: config, theme: themeOverride ?? example.themeOverride)
                nativeVariants = nil
                variantsThemes = nil
            }
            error = nil
        } catch {
            self.error = String(describing: error)
        }
    }

    private func themeLabel(_ theme: MarkupTheme) -> String {
        if theme == .default { return "默认主题" }
        if theme == .dark { return "暗色主题" }
        if theme == .article { return "文章主题" }
        if theme == .chat { return "聊天气泡主题" }
        return "自定义主题"
    }
}
