import SwiftUI
import UIKit
import XMarkup

/// NSAttributedString 渲染视图
struct RenderedTextView: View {
    let example: DemoExample
    @State private var attributedString: NSAttributedString?
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let error = errorMessage {
                    errorView(error)
                } else if let attrStr = attributedString {
                    ScrollingTextView(
                        attributedString: attrStr,
                        containerSize: geometry.size
                    )
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            parseHTML()
        }
    }

    // MARK: - Private

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()
            let result = try parser.parse(example.html)
            attributedString = result.makeAttributedString()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            attributedString = nil
        }
    }

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
}

// MARK: - UITextView Wrapper

/// 可滚动的 UITextView，嵌入 SwiftUI
///
/// 与 UIKit Demo 完全一致的实现策略：
/// - UITextView(isScrollEnabled = true) 自管滚动
/// - textContainerInset 控制边距（16pt 水平，8pt 垂直）
/// - sizeThatFits 返回 GeometryReader 提供的精确尺寸
struct ScrollingTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    let containerSize: CGSize

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

    /// 返回 GeometryReader 提供的精确尺寸，确保 UITextView 获得正确的 frame
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard containerSize.width > 0, containerSize.height > 0 else { return nil }
        return containerSize
    }
}
