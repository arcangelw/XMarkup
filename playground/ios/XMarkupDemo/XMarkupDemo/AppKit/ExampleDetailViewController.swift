import AppKit

/// 详情页：HTML 源码 + 分段切换（渲染效果 / Span 数据）
final class ExampleDetailViewController: NSViewController {
    private let containerView = NSView()
    private let htmlTextView = NSTextView()
    private let segmentedControl = NSSegmentedControl(
        labels: ["渲染效果", "Span 数据"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private var renderedVC: RenderedTextViewController?
    private var spanVC: SpanDataViewController?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }

    private func setupLayout() {
        // HTML 源码区域
        htmlTextView.isEditable = false
        htmlTextView.isRichText = false
        htmlTextView.isHorizontallyResizable = false
        htmlTextView.isVerticallyResizable = true
        htmlTextView.textContainer?.widthTracksTextView = true
        htmlTextView.backgroundColor = .textBackgroundColor
        htmlTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        htmlTextView.textColor = .secondaryLabelColor

        let htmlScrollView = NSScrollView()
        htmlScrollView.translatesAutoresizingMaskIntoConstraints = false
        htmlScrollView.hasVerticalScroller = true
        htmlScrollView.hasHorizontalScroller = false
        htmlScrollView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        htmlScrollView.documentView = htmlTextView

        // 分段控制
        segmentedControl.selectedSegment = 0
        segmentedControl.target = self
        segmentedControl.action = #selector(switchTab)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.setContentHuggingPriority(.required, for: .vertical)

        // 内容容器
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.setContentHuggingPriority(.defaultLow, for: .vertical)

        // 用 NSStackView 组织
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        stackView.addArrangedSubview(htmlScrollView)
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

    override func viewDidLayout() {
        super.viewDidLayout()
        // 更新 htmlTextView 的 frame 以填满 htmlScrollView 的可见区域
        if let htmlScrollView = htmlTextView.enclosingScrollView {
            let visibleRect = htmlScrollView.documentVisibleRect
            if visibleRect.width > 0 {
                let contentHeight = htmlTextView.layoutManager?.usedRect(for: htmlTextView.textContainer!).height ?? 0
                htmlTextView.frame = NSRect(
                    x: 0, y: 0,
                    width: visibleRect.width,
                    height: max(visibleRect.height, contentHeight + 10)
                )
            }
        }
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
        htmlTextView.string = example.html

        renderedVC?.view.removeFromSuperview()
        renderedVC?.removeFromParent()
        spanVC?.view.removeFromSuperview()
        spanVC?.removeFromParent()
        containerView.subviews.forEach { $0.removeFromSuperview() }

        renderedVC = RenderedTextViewController(example: example)
        spanVC = SpanDataViewController(example: example)

        showChild(renderedVC)
        segmentedControl.selectedSegment = 0
    }

    // MARK: - Actions

    @objc private func switchTab() {
        showChild(segmentedControl.selectedSegment == 0 ? renderedVC : spanVC)
    }

    private func showChild(_ child: NSViewController?) {
        guard let child else { return }

        renderedVC?.view.isHidden = (child !== renderedVC)
        spanVC?.view.isHidden = (child !== spanVC)

        if child.parent == nil {
            addChild(child)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(child.view)
            NSLayoutConstraint.activate([
                child.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                child.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
        }

        child.view.isHidden = false
    }
}
