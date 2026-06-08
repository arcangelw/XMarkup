import UIKit

/// 示例详情：顶部 HTML 源码 + 分段切换（渲染效果 / Span 数据）
final class ExampleDetailViewController: UIViewController {
    private let example: DemoExample
    private let segmentedControl = UISegmentedControl(items: ["渲染效果", "Span 数据"])
    private let htmlLabel = UILabel()
    private let containerView = UIView()

    private var renderedVC: RenderedTextViewController?
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

        setupHTMLLabel()
        setupSegmentedControl()
        setupContainer()

        // 创建子控制器
        renderedVC = RenderedTextViewController(example: example)
        spanVC = SpanDataViewController(example: example)

        if let rendered = renderedVC {
            addChild(rendered)
            containerView.addSubview(rendered.view)
            rendered.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                rendered.view.topAnchor.constraint(equalTo: containerView.topAnchor),
                rendered.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                rendered.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                rendered.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
            rendered.didMove(toParent: self)
        }
    }

    // MARK: - Setup

    private func setupHTMLLabel() {
        htmlLabel.text = example.html
        htmlLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        htmlLabel.textColor = .secondaryLabel
        htmlLabel.numberOfLines = 0
        htmlLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(htmlLabel)
        NSLayoutConstraint.activate([
            htmlLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            htmlLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            htmlLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addAction(UIAction { [weak self] _ in
            self?.switchTab()
        }, for: .valueChanged)

        view.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: htmlLabel.bottomAnchor, constant: 8),
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

    // MARK: - Tab Switching

    private func switchTab() {
        guard segmentedControl.selectedSegmentIndex == 1 else {
            showChild(renderedVC)
            return
        }
        showChild(spanVC)
    }

    private func showChild(_ child: UIViewController?) {
        guard let child else { return }

        // 隐藏当前显示的
        renderedVC?.view.isHidden = (child !== renderedVC)
        spanVC?.view.isHidden = (child !== spanVC)

        if child.parent == nil {
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
        }

        child.view.isHidden = false
    }
}
