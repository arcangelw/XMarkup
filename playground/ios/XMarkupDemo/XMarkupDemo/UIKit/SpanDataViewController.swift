import UIKit
import XMarkup

/// Span 原始数据列表
final class SpanDataViewController: UIViewController {
    private let example: DemoExample
    private var result: XMarkupResult?
    private var secondResult: XMarkupResult?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

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
        setupTableView()
        parseHTML()
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SpanCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Parse

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

// MARK: - UITableViewDataSource

extension SpanDataViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        let baseSections = 2 // 纯文本 + Span 列表
        return secondResult != nil ? baseSections + 2 : baseSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let result else { return 0 }

        switch section {
        case 0: return 1  // 纯文本
        case 1: return result.spans.count
        case 2: return 1  // 第二段纯文本
        case 3: return secondResult?.spans.count ?? 0
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard result != nil else { return nil }
        switch section {
        case 0: return "纯文本"
        case 1: return "Span 列表（\(result?.spans.count ?? 0) 个）"
        case 2: return "第二段纯文本"
        case 3: return "第二段 Span 列表（\(secondResult?.spans.count ?? 0) 个）"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpanCell", for: indexPath)

        guard let result else {
            var config = cell.defaultContentConfiguration()
            config.text = "解析错误"
            cell.contentConfiguration = config
            return cell
        }

        var config = cell.defaultContentConfiguration()

        switch indexPath.section {
        case 0:
            config.text = result.text
            config.textProperties.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        case 1:
            let span = result.spans[indexPath.row]
            configureSpanCell(&config, span: span, index: indexPath.row)
        case 2:
            config.text = secondResult?.text ?? ""
            config.textProperties.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        case 3:
            if let secondResult, indexPath.row < secondResult.spans.count {
                let span = secondResult.spans[indexPath.row]
                configureSpanCell(&config, span: span, index: indexPath.row)
            }
        default:
            break
        }

        cell.contentConfiguration = config
        return cell
    }

    // MARK: - Cell Configuration

    private func configureSpanCell(_ config: inout UIListContentConfiguration, span: XMarkupSpan, index: Int) {
        config.text = "#\(index + 1)  \(tagDescription(span.tag))"
        config.secondaryText = """
        tag: \(tagDescription(span.tag))
        style: \(styleDescription(span.style))
        range: [\(span.range.location), \(span.range.location + span.range.length))
        \(span.value.map { "value: \($0)" } ?? "")
        """
        config.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        config.secondaryTextProperties.color = .secondaryLabel
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
