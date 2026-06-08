import SwiftUI

/// HTML 源码展示视图
///
/// 以等宽字体展示原始 HTML，支持滚动浏览。
struct HTMLSourceView: View {
    let html: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(html)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .textSelection(.enabled)
        }
    }
}
