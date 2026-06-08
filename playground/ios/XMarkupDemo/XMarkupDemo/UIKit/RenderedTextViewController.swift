import UIKit
import XMarkup

/// NSAttributedString 渲染视图
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
        parseAndRender()
    }

    // MARK: - Setup

    private func setupTextView() {
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Parse

    private func parseAndRender() {
        do {
            let parser = try XMarkupParser()
            let result = try parser.parse(example.html)
            textView.attributedText = result.makeAttributedString()
        } catch {
            textView.text = "解析错误：\(error.localizedDescription)"
            textView.textColor = .systemRed
        }
    }
}
