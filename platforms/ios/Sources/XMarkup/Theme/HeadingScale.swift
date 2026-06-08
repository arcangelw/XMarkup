import Foundation

/// 标题缩放配置
public struct HeadingScale: Sendable, Equatable {
    public var h1: CGFloat
    public var h2: CGFloat
    public var h3: CGFloat
    public var h4: CGFloat
    public var h5: CGFloat
    public var h6: CGFloat

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

    public static let `default` = HeadingScale()
}
