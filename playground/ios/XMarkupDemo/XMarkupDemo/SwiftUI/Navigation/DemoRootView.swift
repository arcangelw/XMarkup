import SwiftUI

/// 三栏导航根视图（设计规格 §6.1）
///
/// NavigationSplitView 自适应布局：
/// - iOS compact：折叠为 push 导航（Sidebar → List → Detail）
/// - iPad regular / macOS：三栏并列
///
/// selection 用 example.id（String）规避 DemoExample 含 MarkupTheme? 非 Hashable。
struct DemoRootView: View {
    @State private var selectedFamily: ExampleFamily? = .inlineText
    @State private var selectedExampleID: String?
    @State private var searchQuery: String = ""

    var body: some View {
        NavigationSplitView {
            FamilySidebar(selection: $selectedFamily, query: $searchQuery)
        } content: {
            ExampleListView(
                family: selectedFamily,
                query: searchQuery,
                selection: $selectedExampleID
            )
        } detail: {
            detailView
        }
        // 切换族后重置用例选中，避免 detail 残留旧选中（onChange 单参兼容 iOS 16）
        .onChange(of: selectedFamily) { _ in
            selectedExampleID = nil
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let id = selectedExampleID,
           let example = DemoCatalog.all.first(where: { $0.id == id }) {
            // P1-3 将替换为 CompareDetailView（原生 vs Web 并排/堆叠）
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(example.title)
                        .font(.title2.bold())
                    if !example.summary.isEmpty {
                        Text(example.summary).foregroundStyle(.secondary)
                    }
                    if let note = example.note {
                        Text(note)
                            .font(.callout)
                            .padding(8)
                            .background(.yellow.opacity(0.15), in: .rect(cornerRadius: 6))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(example.title)
        } else {
            // iOS 16 无 ContentUnavailableView，自定义空态
            VStack(spacing: 12) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("选择一个用例").font(.title3.weight(.medium))
                Text("从列表中选择用例，查看原生与 Web 渲染对比")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("XMarkup Demo")
        }
    }
}
