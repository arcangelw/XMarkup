import AppKit

/// 示例列表侧边栏
final class ExamplesListViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()

    var onSelect: ((DemoExample) -> Void)?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // 每次布局都更新 documentView 的 frame 以填满可见区域
        let visibleRect = scrollView.documentVisibleRect
        if visibleRect.width > 0 {
            let contentHeight = CGFloat(DemoExample.allExamples.count) * tableView.rowHeight
            tableView.frame = NSRect(
                x: 0, y: 0,
                width: visibleRect.width,
                height: max(visibleRect.height, contentHeight)
            )
        }
        tableView.sizeLastColumnToFit()
    }

    private func setupTableView() {
        // 列配置
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Col"))
        column.minWidth = 100
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil

        tableView.style = .sourceList
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowSizeStyle = .medium
        tableView.selectionHighlightStyle = .regular
        tableView.usesAlternatingRowBackgroundColors = true

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

        // 关键：不设 tableView.frame = scrollView.bounds（此时 bounds 为零）
        // 而是在 viewDidLayout 中动态设置 documentView frame
        scrollView.documentView = tableView

        // 默认选中第一行
        if !DemoExample.allExamples.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
}

// MARK: - NSTableViewDataSource

extension ExamplesListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        DemoExample.allExamples.count
    }
}

// MARK: - NSTableViewDelegate

extension ExamplesListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView
            ?? NSTableCellView()

        cell.subviews.forEach { $0.removeFromSuperview() }

        let example = DemoExample.allExamples[row]

        let titleLabel = NSTextField(labelWithString: example.title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = NSTextField(labelWithString: example.description)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(titleLabel)
        cell.addSubview(descLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            descLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
        ])

        cell.identifier = NSUserInterfaceItemIdentifier("Cell")
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < DemoExample.allExamples.count else { return }
        onSelect?(DemoExample.allExamples[row])
    }
}
