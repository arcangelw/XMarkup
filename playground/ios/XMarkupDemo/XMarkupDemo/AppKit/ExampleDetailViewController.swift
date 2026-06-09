import AppKit

/// 详情页：四段 Tab 切换（HTML 源码 / 渲染效果 / WebView / Span 数据）
final class ExampleDetailViewController: NSViewController {
    private let containerView = NSView()
    private let segmentedControl = NSSegmentedControl(
        labels: ["HTML 源码", "渲染效果", "WebView", "Span 数据"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private var htmlVC: HTMLSourceViewController?
    private var renderedVC: RenderedTextViewController?
    private var webViewVC: WebViewViewController?
    private var spanVC: SpanDataViewController?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }

    private func setupLayout() {
        segmentedControl.selectedSegment = 0
        segmentedControl.target = self
        segmentedControl.action = #selector(switchTab)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.setContentHuggingPriority(.required, for: .vertical)

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.setContentHuggingPriority(.defaultLow, for: .vertical)

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stackView.addArrangedSubview(segmentedControl)
        stackView.addArrangedSubview(containerView)

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        showPlaceholder()
    }

    private func showPlaceholder() {
        let label = NSTextField(labelWithString: "请从左侧选择一个示例")
        label.font = .systemFont(ofSize: 16)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])
    }

    // MARK: - Public

    func update(example: DemoExample) {
        // 清理旧的子控制器
        htmlVC?.view.removeFromSuperview()
        htmlVC?.removeFromParent()
        renderedVC?.view.removeFromSuperview()
        renderedVC?.removeFromParent()
        webViewVC?.view.removeFromSuperview()
        webViewVC?.removeFromParent()
        spanVC?.view.removeFromSuperview()
        spanVC?.removeFromParent()
        containerView.subviews.forEach { $0.removeFromSuperview() }

        // 创建新的子控制器
        htmlVC = HTMLSourceViewController(html: example.html)
        renderedVC = RenderedTextViewController(example: example)
        webViewVC = WebViewViewController(html: example.html)
        spanVC = SpanDataViewController(example: example)

        let children: [NSViewController] = [htmlVC!, renderedVC!, webViewVC!, spanVC!]
        for child in children {
            addChild(child)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(child.view)
            NSLayoutConstraint.activate([
                child.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                child.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
            child.view.isHidden = true
        }

        htmlVC?.view.isHidden = false
        segmentedControl.selectedSegment = 0
    }

    // MARK: - Actions

    @objc private func switchTab() {
        htmlVC?.view.isHidden = segmentedControl.selectedSegment != 0
        renderedVC?.view.isHidden = segmentedControl.selectedSegment != 1
        webViewVC?.view.isHidden = segmentedControl.selectedSegment != 2
        spanVC?.view.isHidden = segmentedControl.selectedSegment != 3
        containerView.layoutSubtreeIfNeeded()
    }
}
