import SwiftUI
import UIKit
import XMarkup

/// NSAttributedString 渲染视图
struct RenderedTextView: View {
    let example: DemoExample
    @State private var attributedString: NSAttributedString?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            if let error = errorMessage {
                errorView(error)
            } else if let attrStr = attributedString {
                NSAttributedStringWrapper(attributedString: attrStr)
                    .padding()
            } else {
                ProgressView()
                    .padding()
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

/// 将 NSAttributedString 渲染到 UITextView，嵌入 SwiftUI
struct NSAttributedStringWrapper: UIViewRepresentable {
    let attributedString: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.configureForXMarkup()
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedString
    }
}
