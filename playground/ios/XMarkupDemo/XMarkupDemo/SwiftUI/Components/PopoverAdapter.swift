import SwiftUI

/// 跨平台弹出适配（设计规格 §6.6）
///
/// - iOS：`.sheet` + `.presentationDetents([.medium, .large])`（半屏，避免 iPhone popover 降级全屏）
/// - macOS：`.popover`（小浮层，arrowEdge .top）
struct PopoverAdapter<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    var macOSWidth: CGFloat = 300
    let arrowEdge: Edge
    @ViewBuilder let panel: () -> Panel

    func body(content: Content) -> some View {
        #if os(iOS)
        content.sheet(isPresented: $isPresented) {
            panel()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        #else
        content.popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
            panel().frame(width: macOSWidth)
        }
        #endif
    }
}

extension View {
    /// 自适应弹出：iOS 半屏 sheet / macOS popover
    func popoverAdaptive<Panel: View>(
        isPresented: Binding<Bool>,
        macOSWidth: CGFloat = 300,
        arrowEdge: Edge = .top,
        @ViewBuilder panel: @escaping () -> Panel
    ) -> some View {
        modifier(PopoverAdapter(
            isPresented: isPresented,
            macOSWidth: macOSWidth,
            arrowEdge: arrowEdge,
            panel: panel
        ))
    }
}
