import SwiftUI

/// 示例列表主页面
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(DemoExample.Category.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        let examples = DemoExample.allExamples.filter { $0.category == category }
                        ForEach(examples) { example in
                            NavigationLink(destination: ExampleDetailView(example: example)) {
                                VStack(alignment: .leading) {
                                    Text(example.title)
                                        .font(.headline)
                                    Text(example.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("XMarkup Demo")
        }
    }
}
