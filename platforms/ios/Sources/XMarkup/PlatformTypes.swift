// 跨平台字体和颜色类型别名
//
// iOS 上 XMFont = UIFont，XMColor = UIColor
// macOS 上 XMFont = NSFont，XMColor = NSColor
#if canImport(UIKit)
    import UIKit

    public typealias XMFont = UIFont
    public typealias XMColor = UIColor
    public typealias XMFontDescriptor = UIFontDescriptor
#elseif canImport(AppKit)
    import AppKit

    public typealias XMFont = NSFont
    public typealias XMColor = NSColor
    public typealias XMFontDescriptor = NSFontDescriptor
#endif
