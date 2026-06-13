import SwiftUI
import XMarkup

/// 对比详情：原生 vs Web（设计规格 §6.4 / P2-1 工具栏 + 实时联动）
///
/// - 对比模式（工具栏 Segmented）：自动（sizeClass）/ 并排 / 堆叠
/// - 画布配置 popover：滑杆调 padding/字号/行高，实时重渲染原生+Web
/// - 主题切换 popover：覆盖主题（.default/.dark/.article/.chat）
/// - themeVariants 用例：原生区纵向多主题对比
/// - 顶部 note banner；ladybug 调试抽屉
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
            .task(id: example.id) { render() }
            .onChange(of: config) { _ in render() }
            .onChange(of: themeOverride) { _ in render() }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("对比模式", selection: $compareMode) {
                        ForEach(CompareMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                    }
                    .pickerStyle(.segmented)
                    .help("对比模式")

                    Button {
                        showCanvasConfig.toggle()
                    } label: {
                        Label("画布", systemImage: "slider.horizontal.3")
                    }
                    .popover(isPresented: $showCanvasConfig) {
                        CanvasConfigPanel(config: $config)
                    }

                    Button {
                        showTheme.toggle()
                    } label: {
                        Label("主题", systemImage: "paintpalette")
                    }
                    .popover(isPresented: $showTheme) {
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
                    attributedString: nativeAttr ?? nativeVariants?.first
                )
            }
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
        .frame(width: 220)
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
            if let themes = example.themeVariants, !themes.isEmpty {
                // themeVariants 用例：忽略 themeOverride，用 example 自带变体
                variantsThemes = themes
                nativeVariants = try DemoRenderer.renderVariants(example: example, config: config)
                nativeAttr = nil
            } else {
                nativeAttr = try DemoRenderer.render(example: example, config: config, theme: themeOverride)
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
