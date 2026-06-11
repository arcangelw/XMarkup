import SwiftUI
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// AttributedString 渲染视图（SwiftUI）
///
/// 使用原生 UITextView / NSTextView 渲染，通过 XMarkup 核心 render() 产出 NSAttributedString。
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
            NativeTextViewRepresentable(
                attributedString: result.attributedStrings[0]
            )
        }
    }

    /// 多主题对比：每个主题一个标题 + 渲染结果
    @ViewBuilder
    private func multiThemeContent(_ result: RenderResult) -> some View {
        let themeNames = ["默认主题", "深色主题", "文章主题"]
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<result.attributedStrings.count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(themeNames[index])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)
                        NativeTextViewRepresentable(
                            attributedString: result.attributedStrings[index]
                        )
                        .frame(height: estimatedHeight(for: result.attributedStrings[index]))
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    /// 根据内容估算高度（多主题视图需要固定高度）
    private func estimatedHeight(for nsAttr: NSAttributedString) -> CGFloat {
        let width = UIScreen.main.bounds.width - 32
        let size = nsAttr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
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
        let attributedStrings: [NSAttributedString]
        let isMultiTheme: Bool
    }

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()

            if example.id == "api-themes" || example.id == "theme-pipeline" {
                // 多主题对比
                let result = try parser.parse(example.html)
                let document = MarkupDocument.from(result)
                let themes: [MarkupTheme] = [.default, .dark, .article]
                let nsRenderer = NSAttributedStringRenderer()
                let attributedStrings = themes.map { theme in
                    let attr = document.render(theme: theme)
                    return nsRenderer.render(attr)
                }
                renderResult = RenderResult(
                    attributedStrings: attributedStrings,
                    isMultiTheme: true
                )
            } else {
                // 单主题
                let document = try parseDocument(parser: parser)
                let theme: MarkupTheme = example.customTheme ?? .default
                let attr = document.render(theme: theme)
                let nsAttr = NSAttributedStringRenderer().render(attr)
                renderResult = RenderResult(
                    attributedStrings: [nsAttr],
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

// MARK: - Native Text View Representable

#if canImport(UIKit)
/// iOS：UIViewRepresentable 包装原生 UITextView
struct NativeTextViewRepresentable: UIViewRepresentable {
    let attributedString: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        textView.linkTextAttributes = [:]
        textView.attributedText = attributedString
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedString
    }
}
#elseif canImport(AppKit)
/// macOS：NSViewRepresentable 包装原生 NSTextView
struct NativeTextViewRepresentable: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        let textView = NSTextView()
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
        textView.textStorage?.setAttributedString(attributedString)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributedString)
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
