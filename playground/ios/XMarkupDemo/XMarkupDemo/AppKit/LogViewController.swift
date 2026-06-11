import AppKit
import Combine
import XMarkup

/// 日志视图控制器（AppKit）
///
/// 展示 XMarkup 解析引擎的内部日志，支持日志级别切换。
final class LogViewController: NSViewController {
    private let example: DemoExample
    private let collector = LogCollector()
    private var cancellables = Set<AnyCancellable>()

    private let segmentedControl = NSSegmentedControl(
        labels: ["Error", "Warn", "Info", "Trace"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let activityIndicator = NSProgressIndicator()

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
        setupUI()
        bindCollector()
        startParsing()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let visibleRect = scrollView.documentVisibleRect
        if visibleRect.width > 0 {
            let contentHeight = CGFloat(collector.entries.count) * 40
            tableView.frame = NSRect(
                x: 0, y: 0,
                width: visibleRect.width,
                height: max(visibleRect.height, contentHeight)
            )
        }
        tableView.sizeLastColumnToFit()
    }

    // MARK: - Setup

    private func setupUI() {
        // 日志级别选择器
        segmentedControl.selectedSegment = 2 // info
        segmentedControl.target = self
        segmentedControl.action = #selector(logLevelChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.setContentHuggingPriority(.required, for: .vertical)

        // 状态栏
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.style = .spinning
        activityIndicator.controlSize = .small
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        // TableView
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("LogColumn"))
        column.minWidth = 100
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.dataSource = self
        tableView.rowSizeStyle = .medium
        tableView.usesAlternatingRowBackgroundColors = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = tableView

        // 布局
        let statusStack = NSStackView()
        statusStack.orientation = .horizontal
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.addView(statusLabel, in: .leading)
        statusStack.addView(activityIndicator, in: .trailing)

        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        mainStack.addView(segmentedControl, in: .leading)
        mainStack.addView(statusStack, in: .leading)
        mainStack.addView(scrollView, in: .leading)

        // 让 scrollView 占满剩余空间
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)

        view.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Bind

    private func bindCollector() {
        Publishers.CombineLatest(collector.$entries, collector.$parseDurationMs)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.tableView.reloadData()
                self.updateStatus()
                self.view.layoutSubtreeIfNeeded()
                // 滚动到底部
                let count = self.collector.entries.count
                if count > 0 {
                    self.tableView.scrollRowToVisible(count - 1)
                }
            }
            .store(in: &cancellables)

        collector.$isParsing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] parsing in
                if parsing {
                    self?.activityIndicator.startAnimation(nil)
                } else {
                    self?.activityIndicator.stopAnimation(nil)
                }
            }
            .store(in: &cancellables)
    }

    private func startParsing() {
        collector.html = example.html
        collector.secondHTML = example.secondHTML
        collector.reparse()
        updateStatus()
    }

    private func updateStatus() {
        let count = collector.entries.count
        var text = "\(count) 条日志"
        if let ms = collector.parseDurationMs {
            text += "  ·  耗时 \(String(format: "%.2f", ms)) ms"
        }
        statusLabel.stringValue = text
    }

    // MARK: - Actions

    @objc private func logLevelChanged() {
        let levels: [XMarkupLogLevel] = [.error, .warn, .info, .trace]
        let index = segmentedControl.selectedSegment
        guard index >= 0, index < levels.count else { return }
        collector.logLevel = levels[index]
    }
}

// MARK: - NSTableViewDataSource

extension LogViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        collector.entries.count
    }
}

// MARK: - NSTableViewDelegate

extension LogViewController {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        40
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("LogCell"), owner: self) as? NSTableCellView
            ?? NSTableCellView()
        cell.subviews.forEach { $0.removeFromSuperview() }

        guard row < collector.entries.count else { return cell }
        let entry = collector.entries[row]

        let levelName: String
        let levelIcon: String
        let levelColor: NSColor

        switch entry.level {
        case .error:
            levelName = "ERROR"
            levelIcon = "✕"
            levelColor = .systemRed
        case .warn:
            levelName = "WARN"
            levelIcon = "⚠"
            levelColor = .systemOrange
        case .info:
            levelName = "INFO"
            levelIcon = "ℹ"
            levelColor = .systemBlue
        case .trace:
            levelName = "TRACE"
            levelIcon = "›"
            levelColor = .tertiaryLabelColor
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeStr = formatter.string(from: entry.timestamp)

        let headerLabel = NSTextField(labelWithString: "\(levelIcon) [\(levelName)] \(timeStr)")
        headerLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        headerLabel.textColor = levelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = NSTextField(labelWithString: entry.message)
        messageLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        messageLabel.lineBreakMode = .byTruncatingTail
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(headerLabel)
        cell.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            headerLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            headerLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            messageLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            messageLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 2),
        ])

        cell.identifier = NSUserInterfaceItemIdentifier("LogCell")
        return cell
    }
}
