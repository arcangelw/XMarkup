import SwiftUI

/// 占位视图（P0 平台无关层构建期间；P1 重建为 NavigationSplitView 三栏）
struct ContentView: View {
    var body: some View {
        NavigationStack {
            Text("Demo 重做中\nP0 平台无关层构建中")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .navigationTitle("XMarkup Demo")
        }
    }
}
