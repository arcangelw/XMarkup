import SwiftUI

/// 中栏：选中族的用例列表（设计规格 §6.3）
///
/// - 正常模式：按 tier 分 Section（基础/嵌套/边界）
/// - 搜索模式（query 非空）：跨族扁平显示匹配用例
/// - robustness 族用例标 ⚠️，回归用例标 ⓘ
struct ExampleListView: View {
    let family: ExampleFamily?
    let query: String
    @Binding var selection: String?

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Group {
            if isSearching {
                searchList
            } else {
                familyList
            }
        }
        .navigationTitle(isSearching ? "搜索结果" : (family?.displayName ?? "用例"))
    }

    @ViewBuilder
    private var familyList: some View {
        let groups = DemoCatalog.groupedByFamily()
        let items = family.flatMap { f in
            groups.first(where: { $0.family == f })?.items
        } ?? []
        List(selection: $selection) {
            ForEach(ExampleTier.allCases, id: \.self) { tier in
                let tierItems = items.filter { $0.tier == tier }
                if !tierItems.isEmpty {
                    Section(tier.rawValue) {
                        ForEach(tierItems) { exampleRow($0) }
                    }
                }
            }
            if items.isEmpty {
                Text("该族暂无可见用例").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var searchList: some View {
        let results = DemoCatalog.search(query)
        List(selection: $selection) {
            if results.isEmpty {
                Text("无匹配用例").foregroundStyle(.secondary)
            } else {
                ForEach(results) { exampleRow($0) }
            }
        }
    }

    @ViewBuilder
    private func exampleRow(_ ex: DemoExample) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.title).font(.body)
                if !ex.summary.isEmpty {
                    Text(ex.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if ex.family == .robustness {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if ex.isRegression {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .tag(ex.id)
    }
}
