import SwiftUI
import XMarkup

/// 对比详情：原生 vs Web（设计规格 §6.4）
///
/// - regular（iPad/macOS/横屏）：HStack 左右并排（HSplitView 仅 macOS，跨平台统一用 HStack）
/// - compact（iPhone 竖屏）：TabView 切换原生/Web（比 plan 的 VStack 堆叠 UX 更佳）
/// - themeVariants 用例：原生区纵向多主题对比
/// - 顶部 note banner（回归/注意事项）
struct CompareDetailView: View {
    let example: DemoExample

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var nativeAttr: NSAttributedString?
    @State private var nativeVariants: [NSAttributedString]?
    @State private var variantsThemes: [MarkupTheme]?
    @State private var error: String?

    private let config = DemoCanvasConfig()

    var body: some View {
        content
            .navigationTitle(example.title)
            .task(id: example.id) { render() }
    }

    // MARK: - 布局

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
            if sizeClass == .regular {
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
                variantsThemes = themes
                nativeVariants = try DemoRenderer.renderVariants(example: example, config: config)
                nativeAttr = nil
            } else {
                nativeAttr = try DemoRenderer.render(example: example, config: config)
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
