import UIKit
import XMarkup

/// 示例列表：按分类分组展示
final class ExamplesListViewController: UITableViewController {
    private let categories = DemoExample.Category.allCases
    private lazy var examplesByCategory: [DemoExample.Category: [DemoExample]] = Dictionary(grouping: DemoExample.allExamples, by: \.category)

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "XMarkup Demo (UIKit)"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        categories.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let category = categories[section]
        return examplesByCategory[category]?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        categories[section].rawValue
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let example = example(at: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = example.title
        config.secondaryText = example.description
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let example = example(at: indexPath)
        let detail = ExampleDetailViewController(example: example)
        navigationController?.pushViewController(detail, animated: true)
    }

    // MARK: - Private

    private func example(at indexPath: IndexPath) -> DemoExample {
        let category = categories[indexPath.section]
        return examplesByCategory[category]![indexPath.row]
    }
}
