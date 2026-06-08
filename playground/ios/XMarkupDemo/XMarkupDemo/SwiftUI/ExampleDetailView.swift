import SwiftUI

/// 示例详情页：HTML 源码 + 渲染效果/数据切换
struct ExampleDetailView: View {
    let example: DemoExample
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // HTML 源码区域
            htmlSourceView

            Divider()

            // 渲染 / 数据 切换
            Picker("视图", selection: $selectedTab) {
                Text("渲染效果").tag(0)
                Text("Span 数据").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // 内容区域
            Group {
                if selectedTab == 0 {
                    RenderedTextView(example: example)
                } else {
                    SpanDataView(example: example)
                }
            }
        }
        .navigationTitle(example.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - HTML 源码

    private var htmlSourceView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HTML")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(example.html)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
}
