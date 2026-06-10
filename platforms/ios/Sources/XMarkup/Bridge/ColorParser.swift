import Foundation

/// 十六进制颜色解析工具
///
/// 将 C 引擎输出的 `#RRGGBB` 格式字符串解析为 `XMColor`。
///
/// 支持的格式：`#RRGGBB`（7 字符，含 # 前缀）
/// 不支持的格式：`#RGB`（三位缩写）、`rgb(r,g,b)` 函数、CSS 命名颜色（如 `red`）
/// 这些格式由 C++ 核心引擎的 `normalize_color()` 预处理为 `#RRGGBB`。
public enum ColorParser {
    /// 解析 #RRGGBB 格式的颜色字符串
    ///
    /// - Parameter hex: 颜色字符串，格式 "#RRGGBB"
    /// - Returns: XMColor，无效格式返回 nil
    public static func parse(_ hex: String?) -> XMColor? {
        guard let hex, hex.count == 7, hex.first == "#" else { return nil }

        let start = hex.index(hex.startIndex, offsetBy: 1)
        let hexColor = String(hex[start...])

        guard let rgb = UInt64(hexColor, radix: 16) else { return nil }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        return XMColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
