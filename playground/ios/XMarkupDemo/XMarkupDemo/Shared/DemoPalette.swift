import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Demo 调色板 — 对齐 Web CSS（设计规格决策 6：Web 为基准，原生对齐 Web）
///
/// 原生渲染器 Link.textColor 默认 nil → fallback systemBlue（≈#007AFF），
/// 与 Web `a { color: #0066CC }` 存在色差。Demo 强制对齐 Web 基准色。
enum DemoPalette {
    /// 链接色（对齐 Web `a { color: #0066CC }`）
    static var linkColor: XMColor {
        #if canImport(UIKit)
        return UIColor(red: 0x00 / 255, green: 0x66 / 255, blue: 0xCC / 255, alpha: 1)
        #elseif canImport(AppKit)
        return NSColor(red: 0x00 / 255, green: 0x66 / 255, blue: 0xCC / 255, alpha: 1)
        #endif
    }
}
