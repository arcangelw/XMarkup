import SwiftUI
import XMarkup

/// AttributedString 渲染视图（SwiftUI）
///
/// 使用原生 `Text(AttributedString)` 渲染（不使用 UIViewRepresentable）。
/// 支持 customTheme、secondHTML 拼接、多主题对比。
struct RenderedTextView: View {
    let example: DemoExample
    @State private var renderResult: RenderResult?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            Group {
                if let error = errorMessage {
                    errorView(error)
                } else if let result = renderResult {
                    renderContent(result)
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .task { parseHTML() }
    }

    // MARK: - Render Content

    /// 根据示例类型选择渲染模式
    @ViewBuilder
    private func renderContent(_ result: RenderResult) -> some View {
        if result.isMultiTheme {
            multiThemeContent(result)
        } else {
            Text(result.attributedStrings[0])
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 多主题对比：每个主题一行标题 + 渲染结果
    private func multiThemeContent(_ result: RenderResult) -> some View {
        let themeNames = ["默认主题", "聊天主题", "文章主题"]
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(result.attributedStrings.enumerated()), id: \.offset) { index, attrStr in
                VStack(alignment: .leading, spacing: 4) {
                    Text(themeNames[index])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    Text(attrStr)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
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
    }

    // MARK: - Parse

    /// 渲染结果：多主题时包含多个 AttributedString
    private struct RenderResult {
        let attributedStrings: [AttributedString]
        let isMultiTheme: Bool
    }

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()

            if example.id == "api-themes" {
                // 多主题对比
                let result = try parser.parse(example.html)
                let document = MarkupDocument.from(result)
                let themes: [MarkupTheme] = [.default, .chat, .article]
                let strings = themes.map { document.render(theme: $0) }
                renderResult = RenderResult(attributedStrings: strings, isMultiTheme: true)
            } else {
                // 单主题（含 customTheme 和 secondHTML 拼接）
                let document = try parseDocument(parser: parser)
                let theme: MarkupTheme = example.customTheme ?? .default
                let attrStr = document.render(theme: theme)
                renderResult = RenderResult(attributedStrings: [attrStr], isMultiTheme: false)
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
