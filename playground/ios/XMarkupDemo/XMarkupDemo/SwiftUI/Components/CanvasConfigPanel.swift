import SwiftUI

/// 画布配置面板（P2-1）— 滑杆调 padding/字号/行高，@Binding 实时联动 CompareDetailView 重渲染
struct CanvasConfigPanel: View {
    @Binding var config: DemoCanvasConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("画布配置").font(.headline)
            row("上边距", value: $config.paddingTop, range: 0...48, step: 1)
            row("左边距", value: $config.paddingLeading, range: 0...48, step: 1)
            row("下边距", value: $config.paddingBottom, range: 0...48, step: 1)
            row("右边距", value: $config.paddingTrailing, range: 0...48, step: 1)
            row("字号", value: $config.baseFontSize, range: 10...28, step: 1)
            row("行高", value: $config.lineHeight, range: 1.0...2.4, step: 0.1)
            Divider()
            Button("恢复默认") { config = DemoCanvasConfig() }
                .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: 360)
    }

    private func row(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, step: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text(String(format: step < 1 ? "%.1f" : "%.0f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
