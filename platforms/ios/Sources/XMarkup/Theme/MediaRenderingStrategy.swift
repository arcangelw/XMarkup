import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 媒体渲染策略
///
/// 决定 `<img>` / `<video>` / `<audio>` 标签如何被渲染为视觉内容。
public enum MediaRenderingStrategy: Sendable {
    /// 使用 SF Symbol 占位图（默认）
    ///
    /// 适用于不需要加载真实图片的场景（如预览、占位）。
    case placeholder

    /// 通过闭包加载图片
    ///
    /// 适用于需要异步加载网络图片或从缓存取图片的场景。
    /// 闭包返回 `nil` 时自动回退到占位图。
    ///
    /// ```swift
    /// .imageProvider { src in
    ///     ImageCache.shared.load(src)
    /// }
    /// ```
    case imageProvider(@Sendable (String) -> XMImage?)

    /// 通过闭包创建自定义附件
    ///
    /// 适用于需要完全自定义 NSTextAttachment 的场景（如自定义 View 内嵌）。
    /// 闭包返回 `nil` 时自动回退到占位图。
    case customAttachment(@Sendable (AttachmentContent, CGSize) -> NSTextAttachment?)
}
