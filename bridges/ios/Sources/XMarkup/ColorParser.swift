import Foundation

/// 十六进制颜色解析工具
///
/// 将 C 引擎输出的 `#RRGGBB` 格式字符串解析为 `XMColor`。
enum ColorParser {

    /// 解析 #RRGGBB 格式的颜色字符串
    ///
    /// - Parameter hex: 颜色字符串，格式 "#RRGGBB"
    /// - Returns: XMColor，无效格式返回 nil
    static func parse(_ hex: String?) -> XMColor? {
        guard let hex, hex.count == 7, hex.first == "#" else { return nil }

        let start = hex.index(hex.startIndex, offsetBy: 1)
        let hexColor = String(hex[start...])

        guard let rgb = UInt64(hexColor, radix: 16) else { return nil }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        #if canImport(UIKit)
        return XMColor(red: r, green: g, blue: b, alpha: 1.0)
        #elseif canImport(AppKit)
        return XMColor(red: r, green: g, blue: b, alpha: 1.0)
        #endif
    }
}
