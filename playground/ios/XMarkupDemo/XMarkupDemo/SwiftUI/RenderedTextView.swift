import SwiftUI
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// AttributedString 渲染视图（SwiftUI）
///
/// 使用 UIViewRepresentable（iOS）/ NSViewRepresentable（macOS）包装原生文本视图，
/// 以支持完整的富文本特性（段落间距、行间距、图片附件等）。
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
            NativeRichTextView(attributedString: result.nsAttributedStrings[0])
        }
    }

    /// 多主题对比：每个主题一个标题 + 渲染结果
    @ViewBuilder
    private func multiThemeContent(_ result: RenderResult) -> some View {
        let themeNames = ["默认主题", "聊天主题", "文章主题"]
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<result.nsAttributedStrings.count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(themeNames[index])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)
                        NativeRichTextView(attributedString: result.nsAttributedStrings[index])
                            .frame(height: estimatedHeight(for: result.nsAttributedStrings[index]))
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    /// 根据内容估算高度（多主题视图需要固定高度）
    private func estimatedHeight(for attrStr: NSAttributedString) -> CGFloat {
        let width = UIScreen.main.bounds.width - 32 // 减去左右 padding
        #if canImport(UIKit)
        let size = attrStr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        #elseif canImport(AppKit)
        let size = attrStr.boundingRect(
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
        let nsAttributedStrings: [NSAttributedString]
        let isMultiTheme: Bool
    }

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()
            let nsRenderer = NSAttributedStringRenderer()

            if example.id == "api-themes" {
                // 多主题对比
                let result = try parser.parse(example.html)
                let document = MarkupDocument.from(result)
                let themes: [MarkupTheme] = [.default, .chat, .article]
                let strings = themes.map { nsRenderer.render(document.render(theme: $0)) }
                renderResult = RenderResult(nsAttributedStrings: strings, isMultiTheme: true)
            } else {
                // 单主题（含 customTheme 和 secondHTML 拼接）
                let document = try parseDocument(parser: parser)
                let theme: MarkupTheme = example.customTheme ?? .default
                let nsAttr = nsRenderer.render(document.render(theme: theme))
                renderResult = RenderResult(nsAttributedStrings: [nsAttr], isMultiTheme: false)
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

// MARK: - Native Rich Text View

#if canImport(UIKit)
/// iOS：UIViewRepresentable 包装 UITextView
struct NativeRichTextView: UIViewRepresentable {
    let attributedString: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        // 清空 linkTextAttributes 让 NSAttributedString 自身的 .foregroundColor 生效
        textView.linkTextAttributes = [:]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedString
    }
}
#elseif canImport(AppKit)
/// macOS：NSViewRepresentable 包装 NSTextView
struct NativeRichTextView: NSViewRepresentable {
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
