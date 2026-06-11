import SwiftUI
import XMarkup
import XMarkupUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// AttributedString 渲染视图（SwiftUI）
///
/// 使用 UIViewRepresentable（iOS）/ NSViewRepresentable（macOS）包装 XMarkupTextView，
/// 自动支持 hr 自适应、blockquote 左侧竖线和异步媒体加载。
/// 支持 customTheme、secondHTML 拼接、多主题对比。
struct RenderedTextView: View {
    let example: DemoExample
    @State private var renderResult: RenderResult?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let error = errorMessage {
                errorView(error)
            } else if let result = renderResult {
                renderContent(result)
            } else {
                ProgressView()
            }
        }
        .task { parseHTML() }
    }

    // MARK: - Render Content

    @ViewBuilder
    private func renderContent(_ result: RenderResult) -> some View {
        if result.isMultiTheme {
            multiThemeContent(result)
        } else {
            XMarkupTextViewRepresentable(theme: example.customTheme ?? .default,
                                         document: result.documents[0])
        }
    }

    /// 多主题对比：每个主题一个标题 + 渲染结果
    @ViewBuilder
    private func multiThemeContent(_ result: RenderResult) -> some View {
        let themeNames = ["默认主题", "深色主题", "文章主题"]
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<result.documents.count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(themeNames[index])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)
                        XMarkupTextViewRepresentable(
                            theme: result.themes[index],
                            document: result.documents[index]
                        )
                        .frame(height: estimatedHeight(for: result.documents[index], theme: result.themes[index]))
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    /// 根据内容估算高度（多主题视图需要固定高度）
    private func estimatedHeight(for doc: MarkupDocument, theme: MarkupTheme) -> CGFloat {
        let width = UIScreen.main.bounds.width - 32
        let nsRenderer = NSAttributedStringRenderer()
        let nsAttr = nsRenderer.render(doc.render(theme: theme))
        #if canImport(UIKit)
        let size = nsAttr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        #elseif canImport(AppKit)
        let size = nsAttr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        #endif
        return max(100, ceil(size.height) + 32)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("解析错误", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Parse

    /// 渲染结果
    private struct RenderResult {
        let documents: [MarkupDocument]
        let themes: [MarkupTheme]
        let isMultiTheme: Bool
    }

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()

            if example.id == "api-themes" {
                // 多主题对比
                let result = try parser.parse(example.html)
                let document = MarkupDocument.from(result)
                let themes: [MarkupTheme] = [.default, .dark, .article]
                renderResult = RenderResult(
                    documents: [document, document, document],
                    themes: themes,
                    isMultiTheme: true
                )
            } else {
                // 单主题（含 customTheme 和 secondHTML 拼接）
                let document = try parseDocument(parser: parser)
                let theme: MarkupTheme = example.customTheme ?? .default
                renderResult = RenderResult(
                    documents: [document],
                    themes: [theme],
                    isMultiTheme: false
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            renderResult = nil
        }
    }

    /// 解析文档，支持 secondHTML 拼接
    private func parseDocument(parser: XMarkupParser) throws -> MarkupDocument {
        let result1 = try parser.parse(example.html)
        let doc1 = MarkupDocument.from(result1)

        if let secondHTML = example.secondHTML {
            let result2 = try parser.parse(secondHTML)
            let doc2 = MarkupDocument.from(result2)
            return doc1.appending(doc2)
        }

        return doc1
    }
}

// MARK: - XMarkupTextView Representable

#if canImport(UIKit)
/// iOS：UIViewRepresentable 包装 XMarkupTextView
struct XMarkupTextViewRepresentable: UIViewRepresentable {
    let theme: MarkupTheme
    let document: MarkupDocument

    func makeUIView(context: Context) -> XMarkupTextView {
        let textView = XMarkupTextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        textView.linkTextAttributes = [:]
        textView.load(document, theme: theme)
        return textView
    }

    func updateUIView(_ textView: XMarkupTextView, context: Context) {
        // XMarkupTextView 在 make 时已加载，无需重复
    }
}
#elseif canImport(AppKit)
/// macOS：NSViewRepresentable 包装 XMarkupTextView
struct XMarkupTextViewRepresentable: NSViewRepresentable {
    let theme: MarkupTheme
    let document: MarkupDocument

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        let textView = XMarkupTextView()
        textView.isEditable = false
        textView.isRichText = true
        textView.backgroundColor = .clear
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.linkTextAttributes = [:]
        textView.textContainerInset = NSSize(width: 16, height: 8)
        textView.load(document, theme: theme)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? XMarkupTextView else { return }
        // 更新 frame 以适应内容
        if let container = textView.textContainer,
           let layoutManager = textView.layoutManager {
            let visibleRect = scrollView.documentVisibleRect
            if visibleRect.width > 0 {
                let contentHeight = layoutManager.usedRect(for: container).height
                textView.frame = NSRect(
                    x: 0, y: 0,
                    width: visibleRect.width,
                    height: max(visibleRect.height, contentHeight + 20)
                )
            }
        }
    }
}
#endif
