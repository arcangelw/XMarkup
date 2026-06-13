import SwiftUI

/// 侧边栏：12 族导航（设计规格 §6.2）
///
/// 顶部 `.searchable` 跨族搜索用例，query 绑定根视图共享给用例列表。
struct FamilySidebar: View {
    @Binding var selection: ExampleFamily?
    @Binding var query: String

    var body: some View {
        // ExampleFamily 非 Identifiable，用 ForEach(id: \.self) + List(selection:)
        List(selection: $selection) {
            ForEach(ExampleFamily.allCases, id: \.self) { family in
                Label(family.displayName, systemImage: family.symbol)
                    .tag(family)
            }
        }
        .navigationTitle("XMarkup Demo")
        .searchable(text: $query, prompt: "搜索用例")
    }
}
