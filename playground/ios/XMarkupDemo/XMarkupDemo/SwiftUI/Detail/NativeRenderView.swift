import SwiftUI

/// 原生渲染展示（接 CompareDetailView 预渲染的 NSAttributedString）
struct NativeRenderView: View {
    let attributedString: NSAttributedString
    let config: DemoCanvasConfig

    var body: some View {
        NativeTextRepresentable(attributedString: attributedString, config: config)
    }
}
