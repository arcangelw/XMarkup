import AppKit

/// HTML 源码展示视图（AppKit）
///
/// 以等宽字体展示原始 HTML，支持滚动浏览。
final class HTMLSourceViewController: NSViewController {
    private let html: String
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    init(html: String) {
        self.html = html
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextView()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let visibleRect = scrollView.documentVisibleRect
        if visibleRect.width > 0 {
            let contentHeight = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
            textView.frame = NSRect(
                x: 0, y: 0,
                width: visibleRect.width,
                height: max(visibleRect.height, contentHeight + 20)
            )
        }
    }

    // MARK: - Setup

    private func setupTextView() {
        textView.isEditable = false
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.backgroundColor = .textBackgroundColor
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .secondaryLabelColor
        textView.string = html

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        scrollView.documentView = textView
    }
}
