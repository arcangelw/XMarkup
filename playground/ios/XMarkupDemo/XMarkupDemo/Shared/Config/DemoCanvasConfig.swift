import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 对比画布基线 — Web 端 CSS 与原生端 textContainerInset 同源读取（设计规格 §3.6）
///
/// 默认值取 Web 当前合理值（Web 为基准，原生对齐 Web，设计规格 §2 决策 6）。
/// 两端读同一份配置 → padding/行高/字体必然对齐，对比时差异 = 渲染器真实行为差异。
public struct DemoCanvasConfig: Equatable, Sendable {

    public var paddingTop: CGFloat
    public var paddingLeading: CGFloat
    public var paddingBottom: CGFloat
    public var paddingTrailing: CGFloat
    /// 行距（Web `line-height` 倍数语义；原生由 DemoRenderer 换算为 NSParagraphStyle 行距）
    public var lineHeight: CGFloat
    public var baseFontSize: CGFloat
    public var baseFontFamily: String

    public init(
        paddingTop: CGFloat = 16,
        paddingLeading: CGFloat = 16,
        paddingBottom: CGFloat = 16,
        paddingTrailing: CGFloat = 16,
        lineHeight: CGFloat = 1.6,
        baseFontSize: CGFloat = 16,
        baseFontFamily: String = "-apple-system"
    ) {
        self.paddingTop = paddingTop
        self.paddingLeading = paddingLeading
        self.paddingBottom = paddingBottom
        self.paddingTrailing = paddingTrailing
        self.lineHeight = lineHeight
        self.baseFontSize = baseFontSize
        self.baseFontFamily = baseFontFamily
    }

    #if canImport(UIKit)
    /// iOS UITextView 内边距
    public var uiTextContainerInset: UIEdgeInsets {
        UIEdgeInsets(top: paddingTop, left: paddingLeading,
                     bottom: paddingBottom, right: paddingTrailing)
    }
    #endif

    #if canImport(AppKit)
    /// macOS NSTextView 内边距（NSTextView 仅横纵两值，纵向由段落间距补）
    public var nsTextContainerInset: NSSize {
        NSSize(width: paddingLeading, height: paddingTop)
    }
    #endif

    /// 生成 Web 端 body CSS 片段（注入 WebViewRenderer）
    public func cssString() -> String {
        """
        body { font-family: \(baseFontFamily), sans-serif;
            padding: \(fmt(paddingTop))px \(fmt(paddingTrailing))px \(fmt(paddingBottom))px \(fmt(paddingLeading))px;
            margin: 0; line-height: \(fmt(lineHeight));
            font-size: \(fmt(baseFontSize))px;
            -webkit-text-size-adjust: 100%; }
        """
    }

    /// 对齐到 MarkupTheme.baseFont（原生端用同一字号）
    public var baseFont: XMFont {
        XMFont.systemFont(ofSize: baseFontSize)
    }

    /// CGFloat → CSS 友好字符串（%g 自动去尾零：8.0→"8"，1.6→"1.6"）
    private func fmt(_ value: CGFloat) -> String {
        String(format: "%g", value as CVarArg)
    }
}
