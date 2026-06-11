import UIKit
import XMarkup

/// 原生 UITextView 渲染视图（UIKit）
///
/// 使用核心 render() + NSAttributedStringRenderer 产出 NSAttributedString，
/// 直接赋值给原生 UITextView。
final class RenderedTextViewController: UIViewController {
    private let example: DemoExample
    private let textView = UITextView()

    init(example: DemoExample) {
        self.example = example
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
        parseAndLoad()
    }

    // MARK: - Setup

    private func setupTextView() {
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.linkTextAttributes = [:]
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Parse & Load

    private func parseAndLoad() {
        do {
            let document = try parseDocument()
            let theme: MarkupTheme = example.customTheme ?? .default
            let attr = document.render(theme: theme)
            let nsAttr = NSAttributedStringRenderer().render(attr)
            textView.attributedText = nsAttr
        } catch {
            textView.text = "解析错误：\(error.localizedDescription)"
            textView.textColor = .systemRed
        }
    }

    /// 解析文档，支持 secondHTML 拼接
    private func parseDocument() throws -> MarkupDocument {
        let parser = try XMarkupParser()
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
