import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 单个 HTML 标签的样式覆盖
///
/// 设置非 nil 的属性将覆盖 HTML 解析得出的默认值。
/// 所有属性均为可选，nil 表示不覆盖。
public struct XMarkupTagStyle: @unchecked Sendable {
    public var font: XMFont?
    public var foregroundColor: XMColor?
    public var backgroundColor: XMColor?
    public var underlineStyle: NSUnderlineStyle?
    public var strikethroughStyle: NSUnderlineStyle?

    public init(
        font: XMFont? = nil,
        foregroundColor: XMColor? = nil,
        backgroundColor: XMColor? = nil,
        underlineStyle: NSUnderlineStyle? = nil,
        strikethroughStyle: NSUnderlineStyle? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.underlineStyle = underlineStyle
        self.strikethroughStyle = strikethroughStyle
    }
}

/// 富文本渲染配置
///
/// 控制解析结果到 NSAttributedString 的转换行为。
/// 支持预置主题、声明式微调、闭包精细控制三个层级。
///
/// ```swift
/// // 使用预置主题
/// let attr = result.makeAttributedString(config: .article)
///
/// // 声明式微调
/// var config = XMarkupStyleConfig.default
/// config[.link] = XMarkupTagStyle(foregroundColor: .systemRed)
/// let attr = result.makeAttributedString(config: config)
///
/// // spanTransformer 闭包精细控制
/// config.spanTransformer = { span, attrs in
///     if span.tag == .link { attrs[.underlineStyle] = 0 }
/// }
/// ```
public struct XMarkupStyleConfig: @unchecked Sendable {

    // MARK: - 基础配置

    /// 基础字体，nil 时使用 systemFont(ofSize: 16)
    public var baseFont: XMFont?

    /// 媒体占位图尺寸（默认 200×150）
    public var mediaPlaceholderSize: CGSize

    // MARK: - 闭包钩子

    /// 图片加载器：(src URL) → XMImage?
    /// 非 nil 时优先调用此闭包加载图片，返回 nil 则回退到 SF Symbol 占位图
    public var imageProvider: (@Sendable (String) -> XMImage?)?

    /// 自定义媒体附件工厂：(tag, srcURL?) → NSTextAttachment?
    /// 非 nil 时替代默认占位图逻辑
    public var mediaAttachmentProvider: (@Sendable (XMarkupTag, String?) -> NSTextAttachment?)?

    /// 单次覆盖：per-span 精细控制
    /// 在渲染流水线 Pass 5 调用，可修改任意 attribute
    public var spanTransformer: (@Sendable (XMarkupSpan, inout [NSAttributedString.Key: Any]) -> Void)?

    /// 后处理钩子：对最终结果做全局操作（如加行间距）
    /// 在渲染流水线 Pass 6 调用
    public var postProcessor: (@Sendable (inout NSMutableAttributedString) -> Void)?

    // MARK: - 标签样式映射

    private var tagStyles: [XMarkupTag: XMarkupTagStyle]

    /// 按标签读取/设置样式覆盖
    public subscript(tag: XMarkupTag) -> XMarkupTagStyle? {
        get { tagStyles[tag] }
        set { tagStyles[tag] = newValue }
    }

    // MARK: - 初始化

    public init(
        baseFont: XMFont? = nil,
        mediaPlaceholderSize: CGSize = CGSize(width: 200, height: 150),
        imageProvider: (@Sendable (String) -> XMImage?)? = nil,
        mediaAttachmentProvider: (@Sendable (XMarkupTag, String?) -> NSTextAttachment?)? = nil,
        spanTransformer: (@Sendable (XMarkupSpan, inout [NSAttributedString.Key: Any]) -> Void)? = nil,
        postProcessor: (@Sendable (inout NSMutableAttributedString) -> Void)? = nil
    ) {
        self.baseFont = baseFont
        self.mediaPlaceholderSize = mediaPlaceholderSize
        self.imageProvider = imageProvider
        self.mediaAttachmentProvider = mediaAttachmentProvider
        self.spanTransformer = spanTransformer
        self.postProcessor = postProcessor
        self.tagStyles = [:]
    }

    // MARK: - 预置主题

    /// 通用主题
    public static let `default`: XMarkupStyleConfig = {
        var config = XMarkupStyleConfig()
        config[.mark] = XMarkupTagStyle(
            backgroundColor: XMColor.systemYellow.withAlphaComponent(0.3)
        )
        #if canImport(UIKit)
        config[.code] = XMarkupTagStyle(backgroundColor: .systemGray6)
        #elseif canImport(AppKit)
        config[.code] = XMarkupTagStyle(
            backgroundColor: .systemGray.withAlphaComponent(0.15)
        )
        #endif
        return config
    }()

    /// 暗色模式主题
    public static let dark: XMarkupStyleConfig = {
        var config = XMarkupStyleConfig()
        config[.mark] = XMarkupTagStyle(
            backgroundColor: XMColor.systemOrange.withAlphaComponent(0.3)
        )
        #if canImport(UIKit)
        config[.code] = XMarkupTagStyle(backgroundColor: .systemGray)
        #elseif canImport(AppKit)
        config[.code] = XMarkupTagStyle(
            backgroundColor: .systemGray.withAlphaComponent(0.3)
        )
        #endif
        return config
    }()

    /// 聊天气泡主题
    public static let chat: XMarkupStyleConfig = {
        var config = XMarkupStyleConfig(
            baseFont: XMFont.systemFont(ofSize: 14),
            mediaPlaceholderSize: CGSize(width: 150, height: 100)
        )
        config[.link] = XMarkupTagStyle(foregroundColor: XMColor.systemBlue)
        config[.mark] = XMarkupTagStyle(
            backgroundColor: XMColor.systemYellow.withAlphaComponent(0.2)
        )
        return config
    }()

    /// 文章阅读主题
    public static let article: XMarkupStyleConfig = {
        var config = XMarkupStyleConfig(
            baseFont: XMFont.systemFont(ofSize: 17),
            mediaPlaceholderSize: CGSize(width: 300, height: 200)
        )
        config[.heading1] = XMarkupTagStyle(
            font: XMFont.systemFont(ofSize: 28, weight: .bold)
        )
        config[.heading2] = XMarkupTagStyle(
            font: XMFont.systemFont(ofSize: 22, weight: .bold)
        )
        config[.heading3] = XMarkupTagStyle(
            font: XMFont.systemFont(ofSize: 19, weight: .semibold)
        )
        #if canImport(UIKit)
        config[.blockquote] = XMarkupTagStyle(foregroundColor: .secondaryLabel)
        config[.code] = XMarkupTagStyle(backgroundColor: .systemGray6)
        #elseif canImport(AppKit)
        config[.blockquote] = XMarkupTagStyle(foregroundColor: .secondaryLabelColor)
        config[.code] = XMarkupTagStyle(backgroundColor: .textBackgroundColor)
        #endif
        return config
    }()
}
