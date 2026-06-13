import Foundation

/// 用例目录 — 分组索引 + 搜索 + 可见性过滤（详见设计规格 §3.5）
///
/// 纯函数版本（`visible(in:)` / `search(_:in:)` / `groupedByFamily(in:)`）接收数组参数，
/// 便于单元测试注入；无参版本默认作用于 `all`。
public enum DemoCatalog {

    /// 全部用例（含 hidden；由各族 Examples 文件按 ExampleFamily 顺序拼合）
    public static let all: [DemoExample] = {
        InlineTextExamples.all
            + InlineStyleExamples.all
            + HeadingParagraphExamples.all
            + BlockquotePreExamples.all
            + ListExamples.all
            + LinkExamples.all
            + TableExamples.all
            + MediaExamples.all
            + SemanticExamples.all
            + ThemeExamples.all
            + ShowcaseExamples.all
            + RobustnessExamples.all
            + APITestExamples.all
    }()

    /// 可见用例（过滤 hidden）
    public static var visible: [DemoExample] { visible(in: all) }

    /// 按 ExampleFamily 顺序分组（仅可见；族内顺序保持原序）
    public static func groupedByFamily() -> [(family: ExampleFamily, items: [DemoExample])] {
        groupedByFamily(in: all)
    }

    /// 搜索（title / summary / id / html，大小写不敏感；仅可见）
    public static func search(_ query: String) -> [DemoExample] {
        search(query, in: all)
    }

    // MARK: - 纯函数（可测）

    public static func visible(in examples: [DemoExample]) -> [DemoExample] {
        examples.filter { $0.visibility == .visible }
    }

    public static func groupedByFamily(
        in examples: [DemoExample]
    ) -> [(family: ExampleFamily, items: [DemoExample])] {
        let grouped = Dictionary(grouping: visible(in: examples), by: { $0.family })
        return ExampleFamily.allCases.compactMap { family in
            let items = grouped[family] ?? []
            return items.isEmpty ? nil : (family, items)
        }
    }

    public static func search(
        _ query: String, in examples: [DemoExample]
    ) -> [DemoExample] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let candidates = visible(in: examples)
        guard !q.isEmpty else { return candidates }
        return candidates.filter {
            $0.title.lowercased().contains(q)
                || $0.summary.lowercased().contains(q)
                || $0.id.lowercased().contains(q)
                || $0.html.lowercased().contains(q)
        }
    }
}
