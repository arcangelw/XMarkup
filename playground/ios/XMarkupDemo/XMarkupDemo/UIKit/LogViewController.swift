import Combine
import UIKit
import XMarkup

/// 日志视图控制器（UIKit）
///
/// 展示 XMarkup 解析引擎的内部日志，支持日志级别切换。
final class LogViewController: UIViewController {
    private let example: DemoExample
    private let collector = LogCollector()
    private var cancellables = Set<AnyCancellable>()

    private let segmentedControl = UISegmentedControl(items: ["Error", "Warn", "Info", "Trace"])
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

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
        setupUI()
        bindCollector()
        startParsing()
    }

    // MARK: - Setup

    private func setupUI() {
        // 日志级别选择器
        segmentedControl.selectedSegmentIndex = 2 // info
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let levels: [XMarkupLogLevel] = [.error, .warn, .info, .trace]
            self.collector.logLevel = levels[self.segmentedControl.selectedSegmentIndex]
            self.collector.reparse()
        }, for: .valueChanged)

        // 状态栏
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        let statusBar = UIView()
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.addSubview(statusLabel)
        statusBar.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
        ])

        // TableView
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LogCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorInsetReference = .fromAutomaticInsets
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        // 布局
        view.addSubview(segmentedControl)
        view.addSubview(statusBar)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            statusBar.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 6),
            statusBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusBar.heightAnchor.constraint(equalToConstant: 20),

            tableView.topAnchor.constraint(equalTo: statusBar.bottomAnchor, constant: 4),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Bind

    private func bindCollector() {
        // 监听 entries 和 parseDurationMs 变化
        Publishers.CombineLatest(collector.$entries, collector.$parseDurationMs)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.tableView.reloadData()
                self.updateStatus()
                let count = self.collector.entries.count
                if count > 0 {
                    self.tableView.scrollToRow(
                        at: IndexPath(row: count - 1, section: 0),
                        at: .bottom,
                        animated: true
                    )
                }
            }
            .store(in: &cancellables)

        collector.$isParsing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] parsing in
                if parsing {
                    self?.activityIndicator.startAnimating()
                } else {
                    self?.activityIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
    }

    private func startParsing() {
        collector.html = example.html
        collector.secondHTML = example.secondHTML
        // 只调用一次 reparse，避免并发 parse 导致 crash
        collector.reparse()
        updateStatus()
    }

    private func updateStatus() {
        let count = collector.entries.count
        var text = "\(count) 条日志"
        if let ms = collector.parseDurationMs {
            text += "  ·  耗时 \(String(format: "%.2f", ms)) ms"
        }
        statusLabel.text = text
    }
}

// MARK: - UITableViewDataSource

extension LogViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        collector.entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath)
        let entry = collector.entries[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.textProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)

        let levelName: String
        let levelIcon: String

        switch entry.level {
        case .error:
            levelName = "ERROR"
            levelIcon = "✕"
        case .warn:
            levelName = "WARN"
            levelIcon = "⚠"
        case .info:
            levelName = "INFO"
            levelIcon = "ℹ"
        case .trace:
            levelName = "TRACE"
            levelIcon = "›"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeStr = formatter.string(from: entry.timestamp)

        config.text = "\(levelIcon) [\(levelName)] \(entry.message)"
        config.secondaryText = timeStr
        config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        config.secondaryTextProperties.color = .tertiaryLabel

        cell.contentConfiguration = config
        cell.backgroundColor = entry.level == .error ? UIColor.systemRed.withAlphaComponent(0.05) : .clear

        return cell
    }
}
