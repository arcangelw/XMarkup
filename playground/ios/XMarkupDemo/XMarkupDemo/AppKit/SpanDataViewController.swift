import AppKit
import XMarkup

/// Span 原始数据列表（AppKit）
final class SpanDataViewController: NSViewController {
    private let example: DemoExample
    private var result: XMarkupResult?
    private var secondResult: XMarkupResult?
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

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
        setupTableView()
        parseHTML()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let visibleRect = scrollView.documentVisibleRect
        if visibleRect.width > 0 {
            let totalCount: Int
            if let result, let secondResult {
                totalCount = result.spans.count + secondResult.spans.count + 2
            } else if let result {
                totalCount = max(result.spans.count, 1)
            } else {
                totalCount = 1
            }
            let contentHeight = CGFloat(totalCount) * 48
            tableView.frame = NSRect(
                x: 0, y: 0,
                width: visibleRect.width,
                height: max(visibleRect.height, contentHeight)
            )
        }
        tableView.sizeLastColumnToFit()
    }

    private func setupTableView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DataColumn"))
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

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        scrollView.documentView = tableView
    }

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()
            result = try parser.parse(example.html)
            if let secondHTML = example.secondHTML {
                secondResult = try parser.parse(secondHTML)
            }
        } catch {
            result = nil
        }
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDataSource

extension SpanDataViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let result else { return 1 }
        if let secondResult {
            return result.spans.count + secondResult.spans.count + 2 // 两段纯文本 + 所有 span
        }
        return result.spans.isEmpty ? 1 : result.spans.count
    }
}

// MARK: - NSTableViewDelegate

extension SpanDataViewController {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        48
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("Cell"), owner: self) as? NSTableCellView
            ?? NSTableCellView()

        cell.subviews.forEach { $0.removeFromSuperview() }

        guard let result else {
            let label = NSTextField(labelWithString: "解析错误")
            label.textColor = .systemRed
            cell.addSubview(label)
            cell.identifier = NSUserInterfaceItemIdentifier("Cell")
            return cell
        }

        if let secondResult {
            // 有第二段结果：行 0 = 第一段纯文本，行 1~count = 第一段 span，
            // 行 count+1 = 第二段纯文本，行 count+2~ = 第二段 span
            if row == 0 {
                buildPlainTextCell(cell, text: result.text)
            } else if row <= result.spans.count {
                let span = result.spans[row - 1]
                buildSpanCell(cell, index: row - 1, span: span)
            } else if row == result.spans.count + 1 {
                buildPlainTextCell(cell, text: secondResult.text)
            } else {
                let secondIndex = row - result.spans.count - 2
                if secondIndex < secondResult.spans.count {
                    let span = secondResult.spans[secondIndex]
                    buildSpanCell(cell, index: secondIndex, span: span)
                }
            }
        } else {
            if result.spans.isEmpty {
                let label = NSTextField(labelWithString: "无 Span 数据")
                label.textColor = .tertiaryLabelColor
                cell.addSubview(label)
            } else {
                let span = result.spans[row]
                buildSpanCell(cell, index: row, span: span)
            }
        }

        cell.identifier = NSUserInterfaceItemIdentifier("Cell")
        return cell
    }

    // MARK: - Cell Builders

    private func buildPlainTextCell(_ cell: NSTableCellView, text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
    }

    private func buildSpanCell(_ cell: NSTableCellView, index: Int, span: XMarkupSpan) {
        let titleLabel = NSTextField(labelWithString: "#\(index + 1)  \(tagDescription(span.tag))")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let rangeEnd = span.range.location + span.range.length
        var detailText = "tag: \(tagDescription(span.tag)) | style: \(styleDescription(span.style)) | range: [\(span.range.location), \(rangeEnd))"
        if let value = span.value {
            detailText += " | value: \(value)"
        }
        let detailLabel = NSTextField(labelWithString: detailText)
        detailLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(titleLabel)
        cell.addSubview(detailLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            titleLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            detailLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
        ])
    }

    // MARK: - Description Helpers

    private func tagDescription(_ tag: XMarkupTag) -> String {
        switch tag {
        case .bold: "bold"
        case .italic: "italic"
        case .underline: "underline"
        case .strikethrough: "strikethrough"
        case .subscriptText: "subscript"
        case .superscript: "superscript"
        case .mark: "mark"
        case .code: "code"
        case .paragraph: "paragraph"
        case .heading1: "h1"
        case .heading2: "h2"
        case .heading3: "h3"
        case .heading4: "h4"
        case .heading5: "h5"
        case .heading6: "h6"
        case .blockquote: "blockquote"
        case .preformatted: "pre"
        case .link: "link"
        case .image: "image"
        case .video: "video"
        case .videoSource: "videoSource"
        case .audio: "audio"
        case .audioSource: "audioSource"
        case .listOrdered: "ol"
        case .listUnordered: "ul"
        case .listItem: "li"
        case .table: "table"
        case .tableRow: "tr"
        case .tableCell: "td"
        case .tableHeader: "th"
        case .horizontalRule: "hr"
        case .lineBreak: "br"
        case .division: "div"
        case .span: "span"
        case .article: "article"
        case .section: "section"
        case .header: "header"
        case .footer: "footer"
        case .nav: "nav"
        case .aside: "aside"
        case .figure: "figure"
        case .figcaption: "figcaption"
        case .main: "main"
        case .address: "address"
        case .definitionList: "dl"
        case .definitionTerm: "dt"
        case .definitionDescription: "dd"
        case let .unknown(v): "unknown(\(v))"
        }
    }

    private func styleDescription(_ style: XMarkupStyle) -> String {
        switch style {
        case .foregroundColor: "foregroundColor"
        case .backgroundColor: "backgroundColor"
        case .fontSize: "fontSize"
        case .fontWeight: "fontWeight"
        case .fontStyle: "fontStyle"
        case .textDecoration: "textDecoration"
        case .lineHeight: "lineHeight"
        case .textAlign: "textAlign"
        case .letterSpacing: "letterSpacing"
        case .mediaType: "mediaType"
        case .mediaQuery: "mediaQuery"
        case let .unknown(v): "unknown(\(v))"
        }
    }
}
