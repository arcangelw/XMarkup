import SwiftUI

/// 示例详情页：四段 Tab（HTML 源码 / 渲染效果 / WebView / Span 数据）
struct ExampleDetailView: View {
    let example: DemoExample
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("视图", selection: $selectedTab) {
                Text("HTML 源码").tag(0)
                Text("渲染效果").tag(1)
                Text("WebView").tag(2)
                Text("Span 数据").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            contentView
        }
        .navigationTitle(example.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case 0:
            HTMLSourceView(html: example.html)
        case 1:
            RenderedTextView(example: example)
        case 2:
            WebViewPreviewView(html: example.html)
        case 3:
            SpanDataView(example: example)
        default:
            EmptyView()
        }
    }
}
