import AppKit
import XMarkup

/// 原生 NSTextView 渲染视图（AppKit）
///
/// 使用核心 render() + NSAttributedStringRenderer 产出 NSAttributedString，
/// 直接赋值给原生 NSTextView。
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
        parseAndLoad()
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
        textView.linkTextAttributes = [:]
        textView.textContainerInset = NSSize(width: 16, height: 8)

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

    private func parseAndLoad() {
        do {
            let document = try parseDocument()
            let theme: MarkupTheme = example.customTheme ?? .default
            let attr = document.renderAttributed(theme: theme)
            let nsAttr = NSAttributedStringRenderer().render(attr)
            textView.textStorage?.setAttributedString(nsAttr)
        } catch {
            textView.string = "解析错误：\(error.localizedDescription)"
            textView.textColor = NSColor.systemRed
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
