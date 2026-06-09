import UIKit

/// 示例详情：四段 Tab 切换（HTML 源码 / 渲染效果 / WebView / Span 数据）
final class ExampleDetailViewController: UIViewController {
    private let example: DemoExample
    private let segmentedControl = UISegmentedControl(items: ["HTML 源码", "渲染效果", "WebView", "Span 数据"])
    private let containerView = UIView()

    private var htmlVC: HTMLSourceViewController?
    private var renderedVC: RenderedTextViewController?
    private var webViewVC: WebViewViewController?
    private var spanVC: SpanDataViewController?

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
        title = example.title
        view.backgroundColor = .systemBackground

        setupSegmentedControl()
        setupContainer()
        setupChildViewControllers()
    }

    // MARK: - Setup

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addAction(UIAction { [weak self] _ in
            self?.switchTab()
        }, for: .valueChanged)

        view.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    /// 一次性创建并添加所有子控制器，通过 isHidden 切换显示
    private func setupChildViewControllers() {
        htmlVC = HTMLSourceViewController(html: example.html)
        renderedVC = RenderedTextViewController(example: example)
        webViewVC = WebViewViewController(html: example.html)
        spanVC = SpanDataViewController(example: example)

        let children: [UIViewController] = [htmlVC!, renderedVC!, webViewVC!, spanVC!]
        for child in children {
            addChild(child)
            containerView.addSubview(child.view)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                child.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                child.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
            child.didMove(toParent: self)
            child.view.isHidden = true
        }

        // 默认显示第一个 Tab
        htmlVC?.view.isHidden = false
    }

    // MARK: - Tab Switching

    private func switchTab() {
        htmlVC?.view.isHidden = segmentedControl.selectedSegmentIndex != 0
        renderedVC?.view.isHidden = segmentedControl.selectedSegmentIndex != 1
        webViewVC?.view.isHidden = segmentedControl.selectedSegmentIndex != 2
        spanVC?.view.isHidden = segmentedControl.selectedSegmentIndex != 3
    }
}
