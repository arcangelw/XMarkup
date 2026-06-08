import AppKit
import XMarkup

/// NSAttributedString 渲染视图（AppKit）
final class RenderedTextViewController: NSViewController {
    private let example: DemoExample
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    init(example: DemoExample) {
        self.example = example
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
        parseAndRender()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // 每次布局都更新 textView 的 frame 以填满可见区域
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

    private func setupTextView() {
        textView.isEditable = false
        textView.isRichText = true
        textView.backgroundColor = .clear
        textView.typingAttributes = [.font: NSFont.systemFont(ofSize: 16)]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        // 清空 linkTextAttributes 让 NSAttributedString 自身的 .foregroundColor 生效
        textView.linkTextAttributes = [:]

        // scrollView 填满 view（Auto Layout）
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

        // 不设 textView.frame，在 viewDidLayout 中动态设置
        scrollView.documentView = textView
    }

    private func parseAndRender() {
        do {
            let parser = try XMarkupParser()
            let result = try parser.parse(example.html)
            let attributed = result.makeAttributedString()
            textView.textStorage?.setAttributedString(attributed)
        } catch {
            textView.string = "解析错误：\(error.localizedDescription)"
            textView.textColor = .systemRed
        }
    }
}
