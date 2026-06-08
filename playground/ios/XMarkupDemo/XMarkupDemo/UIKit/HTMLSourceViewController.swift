import UIKit

/// HTML 源码展示视图
///
/// 以等宽字体展示原始 HTML，支持滚动浏览。
final class HTMLSourceViewController: UIViewController {
    private let html: String
    private let textView = UITextView()

    init(html: String) {
        self.html = html
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
    }

    // MARK: - Setup

    private func setupTextView() {
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .secondaryLabel
        textView.text = html
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}
