import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 媒体渲染策略
public enum MediaRenderingStrategy: Sendable {
    /// 使用 SF Symbol 占位图（默认）
    case placeholder
    /// 通过闭包加载图片
    case imageProvider(@Sendable (String) -> XMImage?)
    /// 通过闭包创建自定义附件
    case customAttachment(@Sendable (AttachmentContent, CGSize) -> NSTextAttachment?)
}
