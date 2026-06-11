import Foundation

/// 标题缩放配置
///
/// 默认值来源于 Chrome/Firefox/Safari 浏览器默认样式表中 h1-h6 的 font-size 缩放比例：
/// h1=2em, h2=1.5em, h3=1.17em, h4=1em, h5=0.83em, h6=0.67em
/// 参考：https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Heading_Elements
public struct HeadingScale: Sendable, Equatable {
    public var h1: CGFloat
    public var h2: CGFloat
    public var h3: CGFloat
    public var h4: CGFloat
    public var h5: CGFloat
    public var h6: CGFloat

    /// 创建标题缩放配置
    ///
    /// 默认值对应浏览器默认样式表（MDN 参考）。
    ///
    /// - Note: 不校验传入值有效性。设 0 或负值会产生 0pt 标题——调用方应确保正值。
    public init(
        h1: CGFloat = 2.0,
        h2: CGFloat = 1.5,
        h3: CGFloat = 1.17,
        h4: CGFloat = 1.0,
        h5: CGFloat = 0.83,
        h6: CGFloat = 0.67
    ) {
        self.h1 = h1
        self.h2 = h2
        self.h3 = h3
        self.h4 = h4
        self.h5 = h5
        self.h6 = h6
    }

    /// 浏览器默认缩放比例
    public static let `default` = HeadingScale()
}
