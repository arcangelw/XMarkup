import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// NSAttributedString 便利层：6 阶渲染流水线
///
/// 渲染阶段顺序：
/// 1. HTML 字体属性（bold/italic/heading/code/fontSize）
/// 2. HTML 非字体属性（underline/strikethrough/link/mark/color）
/// 3. StyleConfig 标签覆盖
/// 4. 媒体附件替换（image/video/audio → NSTextAttachment）
/// 5. spanTransformer（单次精细控制）
/// 6. postProcessor（全局后处理）
extension XMarkupResult {

    /// 将解析结果转换为 NSAttributedString
    ///
    /// 使用方式：
    /// ```swift
    /// let result = try parser.parse("<b>Hello</b> <i>World</i>")
    /// let attributed = result.makeAttributedString()
    /// // 或使用预置主题
    /// let article = result.makeAttributedString(config: .article)
    /// ```
    ///
    /// - Parameter config: 渲染配置，默认 `.default`
    /// - Returns: 带样式的 NSAttributedString
    public func makeAttributedString(config: XMarkupStyleConfig = .default) -> NSAttributedString {
        let base = config.baseFont ?? XMFont.systemFont(ofSize: 16)

        guard !text.isEmpty else {
            return NSAttributedString(string: "")
        }

        var str = NSMutableAttributedString(string: text, attributes: [.font: base])

        // Pass 1: HTML 字体属性（bold/italic/heading/code/fontSize）
        for span in spans {
            applyFontAttributes(span, baseFontSize: base.pointSize, to: str)
        }

        // Pass 2: HTML 非字体属性（underline/strikethrough/link/mark/color）
        for span in spans {
            applyNonFontAttributes(span, to: str)
        }

        // Pass 3: StyleConfig 标签覆盖
        applyConfigOverrides(config, to: str)

        // Pass 4: 媒体附件替换（image/video/audio → NSTextAttachment）
        applyMediaAttachments(config: config, to: str)

        // Pass 5: spanTransformer（单次精细控制）
        if let transformer = config.spanTransformer {
            for span in spans {
                var attrs: [NSAttributedString.Key: Any] = [:]
                transformer(span, &attrs)
                if !attrs.isEmpty {
                    str.addAttributes(attrs, range: span.range)
                }
            }
        }

        // Pass 6: postProcessor（全局后处理）
        if let processor = config.postProcessor {
            processor(&str)
        }

        return NSAttributedString(attributedString: str)
    }

    // MARK: - Pass 1: HTML 字体属性

    /// 第一趟：处理字体相关属性（合并 trait 而非覆盖）
    ///
    /// - Parameters:
    ///   - span: 样式区间
    ///   - baseFontSize: 基础字号，用于 heading 缩放计算
    ///   - string: 目标可变富文本
    private func applyFontAttributes(
        _ span: XMarkupSpan,
        baseFontSize: CGFloat,
        to string: NSMutableAttributedString
    ) {
        let range = span.range

        switch span.tag {
        case .bold:
            addFontTrait(boldTrait, to: range, in: string)
        case .italic:
            addFontTrait(italicTrait, to: range, in: string)
        case .heading1:
            applyHeadingFont(scale: 2.0, to: range, in: string)
        case .heading2:
            applyHeadingFont(scale: 1.5, to: range, in: string)
        case .heading3:
            applyHeadingFont(scale: 1.17, to: range, in: string)
        case .heading4:
            applyHeadingFont(scale: 1.0, to: range, in: string)
        case .heading5:
            applyHeadingFont(scale: 0.83, to: range, in: string)
        case .heading6:
            applyHeadingFont(scale: 0.67, to: range, in: string)
        case .code:
            applyCodeFont(to: range, in: string)
        default:
            break
        }

        // CSS fontSize
        if span.style == .fontSize, let value = span.value, let size = Float(value) {
            applyFontSize(CGFloat(size), to: range, in: string)
        }
    }

    // MARK: - Pass 2: HTML 非字体属性

    /// 第二趟：处理非字体属性（下划线、删除线、链接、高亮、颜色）
    ///
    /// - Parameters:
    ///   - span: 样式区间
    ///   - string: 目标可变富文本
    private func applyNonFontAttributes(_ span: XMarkupSpan, to string: NSMutableAttributedString) {
        let range = span.range

        switch span.tag {
        case .underline:
            string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .strikethrough:
            string.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .link:
            if let url = span.value {
                string.addAttribute(.link, value: url, range: range)
                // 设置默认链接颜色，带自定义颜色的链接会在后续 CSS 颜色 span 中被覆盖
                #if canImport(UIKit)
                string.addAttribute(.foregroundColor, value: XMColor.link, range: range)
                #elseif canImport(AppKit)
                string.addAttribute(.foregroundColor, value: XMColor.linkColor, range: range)
                #endif
            }
        case .code:
            // HTML <code> 默认应有背景色以区分普通文本
            #if canImport(UIKit)
            string.addAttribute(.backgroundColor, value: XMColor.systemGray6, range: range)
            #elseif canImport(AppKit)
            string.addAttribute(
                .backgroundColor,
                value: XMColor.systemGray.withAlphaComponent(0.15),
                range: range
            )
            #endif
        case .mark:
            string.addAttribute(
                .backgroundColor,
                value: XMColor.systemYellow.withAlphaComponent(0.3),
                range: range
            )
        default:
            break
        }

        switch span.style {
        case .foregroundColor:
            if let color = ColorParser.parse(span.value) {
                string.addAttribute(.foregroundColor, value: color, range: range)
            }
        case .backgroundColor:
            if let color = ColorParser.parse(span.value) {
                string.addAttribute(.backgroundColor, value: color, range: range)
            }
        default:
            break
        }
    }

    // MARK: - Pass 3: StyleConfig 标签覆盖

    /// 第三趟：将 StyleConfig 中配置的标签样式覆盖到富文本
    ///
    /// 对每个 span，检查 config 中是否有对应标签的样式配置，
    /// 有则覆盖对应的 attribute（font/foregroundColor/backgroundColor 等）。
    ///
    /// - Parameters:
    ///   - config: 样式配置
    ///   - string: 目标可变富文本
    private func applyConfigOverrides(
        _ config: XMarkupStyleConfig,
        to string: NSMutableAttributedString
    ) {
        for span in spans {
            guard let style = config[span.tag] else { continue }
            let range = span.range

            if let font = style.font {
                string.enumerateAttribute(.font, in: range) { _, attrRange, _ in
                    #if canImport(UIKit)
                    string.addAttribute(.font, value: font, range: attrRange)
                    #elseif canImport(AppKit)
                    string.addAttribute(.font, value: font, range: attrRange)
                    #endif
                }
            }
            if let fg = style.foregroundColor {
                string.addAttribute(.foregroundColor, value: fg, range: range)
            }
            if let bg = style.backgroundColor {
                string.addAttribute(.backgroundColor, value: bg, range: range)
            }
            if let underline = style.underlineStyle {
                string.addAttribute(.underlineStyle, value: underline.rawValue, range: range)
            }
            if let strike = style.strikethroughStyle {
                string.addAttribute(.strikethroughStyle, value: strike.rawValue, range: range)
            }
        }
    }

    // MARK: - Pass 4: 媒体附件

    /// 第四趟：扫描媒体 span，用 NSTextAttachment 替换 U+FFFC 占位符
    ///
    /// 从后向前遍历，避免替换导致的 range 偏移问题。
    /// 对于 `<video><source>` 结构，优先取 video/audio 自身 src，
    /// 无则查找嵌套的 source 子 span 的 value 作为 src。
    ///
    /// - Parameters:
    ///   - config: 样式配置（含 imageProvider、mediaPlaceholderSize 等）
    ///   - string: 目标可变富文本
    private func applyMediaAttachments(
        config: XMarkupStyleConfig,
        to string: NSMutableAttributedString
    ) {
        let mediaTags: Set<XMarkupTag> = [.image, .video, .audio]
        let mediaSpans = spans.filter { mediaTags.contains($0.tag) }

        // 从后向前遍历，避免 range 偏移
        let sortedSpans = mediaSpans.sorted { $0.range.location > $1.range.location }

        let nsString = string.string as NSString

        for span in sortedSpans {
            let spanRange = span.range

            // 在 span 范围内搜索 U+FFFC
            let searchResult = nsString.range(of: "\u{FFFC}", options: [], range: spanRange)
            guard searchResult.location != NSNotFound else { continue }

            // 确定媒体 src
            let src = resolveMediaSrc(span, allSpans: spans)

            // 创建附件
            let attachment: NSTextAttachment
            if let customProvider = config.mediaAttachmentProvider {
                guard let custom = customProvider(span.tag, src) else { continue }
                attachment = custom
            } else {
                attachment = createDefaultAttachment(
                    tag: span.tag,
                    src: src,
                    config: config
                )
            }

            let attrStr = NSAttributedString(attachment: attachment)
            string.replaceCharacters(in: searchResult, with: attrStr)
        }
    }

    /// 解析媒体 src：优先取 span 自身 value，否则查找嵌套的 source 子 span
    ///
    /// 处理两种场景：
    /// - `<video src="movie.mp4">` → 直接从 video span 取 value
    /// - `<video><source src="movie.mp4">` → 从 videoSource 子 span 取 value
    ///
    /// - Parameters:
    ///   - span: 媒体 span（image/video/audio）
    ///   - allSpans: 全部 span 数组，用于查找子 span
    /// - Returns: src URL 字符串，未找到则返回 nil
    private func resolveMediaSrc(_ span: XMarkupSpan, allSpans: [XMarkupSpan]) -> String? {
        if let src = span.value, !src.isEmpty { return src }

        // video/audio 无直接 src 时，查找嵌套的 source span
        let childTag: XMarkupTag
        switch span.tag {
        case .video: childTag = .videoSource
        case .audio: childTag = .audioSource
        default: return nil
        }

        for child in allSpans {
            if child.tag == childTag,
               child.range.location >= span.range.location,
               child.range.location + child.range.length <= span.range.location + span.range.length,
               let src = child.value {
                return src
            }
        }
        return nil
    }

    /// 创建默认媒体附件（SF Symbol 占位图）
    ///
    /// 优先尝试通过 imageProvider 加载自定义图片（保持宽高比），
    /// 失败则生成对应标签的 SF Symbol 占位图：
    /// - image → `photo`
    /// - video → `play.rectangle`
    /// - audio → `waveform`
    ///
    /// - Parameters:
    ///   - tag: 媒体标签类型
    ///   - src: 媒体 src URL，可能为 nil
    ///   - config: 样式配置（含 imageProvider、mediaPlaceholderSize）
    /// - Returns: 配置好 bounds 的 NSTextAttachment
    private func createDefaultAttachment(
        tag: XMarkupTag,
        src: String?,
        config: XMarkupStyleConfig
    ) -> NSTextAttachment {
        // 尝试自定义图片加载
        if let src = src, let provider = config.imageProvider, let image = provider(src) {
            let attachment = NSTextAttachment()
            attachment.image = image
            let aspectRatio = image.size.height / max(image.size.width, 1)
            let displayWidth = config.mediaPlaceholderSize.width
            let displaySize = CGSize(width: displayWidth, height: displayWidth * aspectRatio)
            attachment.bounds = CGRect(origin: .zero, size: displaySize)
            return attachment
        }

        // SF Symbol 占位图
        let symbolName: String
        switch tag {
        case .image: symbolName = "photo"
        case .video: symbolName = "play.rectangle"
        case .audio: symbolName = "waveform"
        default: symbolName = "square"
        }

        let size = config.mediaPlaceholderSize
        let image = createPlaceholderImage(systemName: symbolName, size: size)

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)
        return attachment
    }

    /// 生成 SF Symbol 占位图（浅灰背景 + 居中图标）
    ///
    /// - Parameters:
    ///   - systemName: SF Symbol 名称
    ///   - size: 图片尺寸
    /// - Returns: 渲染后的图片
    #if canImport(UIKit)
    private func createPlaceholderImage(systemName: String, size: CGSize) -> XMImage {
        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: min(size.width, size.height) * 0.3
        )
        let symbol = UIImage(systemName: systemName, withConfiguration: symbolConfig)
            ?? UIImage()
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemGray.withAlphaComponent(0.1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let symbolSize = symbol.size
            symbol.draw(at: CGPoint(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2
            ))
        }
    }
    #elseif canImport(AppKit)
    private func createPlaceholderImage(systemName: String, size: CGSize) -> XMImage {
        let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
            ?? NSImage(size: size)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemGray.withAlphaComponent(0.1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let symbolSize = symbol.size
        let x = (size.width - symbolSize.width) / 2
        let y = (size.height - symbolSize.height) / 2
        symbol.draw(
            at: NSPoint(x: x, y: y),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        image.unlockFocus()
        return image
    }
    #endif

    // MARK: - 字体辅助方法

    /// 向指定范围追加字体 trait（合并而非覆盖）
    ///
    /// 处理 `<b><i>text</i></b>` 场景：先应用 BOLD trait，
    /// 再在同一范围应用 ITALIC trait，最终得到 Bold-Italic 字体。
    ///
    /// - Parameters:
    ///   - trait: 要追加的字体特征（bold/italic）
    ///   - range: 目标文本范围
    ///   - string: 目标可变富文本
    private func addFontTrait(
        _ trait: XMFontDescriptor.SymbolicTraits,
        to range: NSRange,
        in string: NSMutableAttributedString
    ) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(trait)
            #if canImport(UIKit)
                guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return }
                let newFont = XMFont(descriptor: descriptor, size: font.pointSize)
            #elseif canImport(AppKit)
                let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
                guard let newFont = XMFont(descriptor: descriptor, size: font.pointSize) else { return }
            #endif
            string.addAttribute(.font, value: newFont, range: attrRange)
        }
    }

    /// 应用 heading 字体（放大 + 加粗）
    ///
    /// - Parameters:
    ///   - scale: 字号缩放倍数（H1=2.0, H2=1.5, H3=1.17, ...）
    ///   - range: 目标文本范围
    ///   - string: 目标可变富文本
    private func applyHeadingFont(
        scale: CGFloat,
        to range: NSRange,
        in string: NSMutableAttributedString
    ) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            let newSize = font.pointSize * scale
            #if canImport(UIKit)
                guard let desc = font.fontDescriptor.withSymbolicTraits(boldTrait) else { return }
                let newFont = XMFont(descriptor: desc, size: newSize)
            #elseif canImport(AppKit)
                let desc = font.fontDescriptor.withSymbolicTraits(boldTrait)
                guard let newFont = XMFont(descriptor: desc, size: newSize) else { return }
            #endif
            string.addAttribute(.font, value: newFont, range: attrRange)
        }
    }

    /// 应用等宽字体（用于 `<code>`）
    ///
    /// - Parameters:
    ///   - range: 目标文本范围
    ///   - string: 目标可变富文本
    private func applyCodeFont(to range: NSRange, in string: NSMutableAttributedString) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            #if canImport(UIKit)
                let monoFont = UIFont(name: "Menlo", size: font.pointSize)
                    ?? UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            #elseif canImport(AppKit)
                let monoFont = NSFont(name: "Menlo", size: font.pointSize)
                    ?? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
            #endif
            string.addAttribute(.font, value: monoFont, range: attrRange)
        }
    }

    /// 应用 CSS 指定字号
    ///
    /// - Parameters:
    ///   - size: 目标字号（px）
    ///   - range: 目标文本范围
    ///   - string: 目标可变富文本
    private func applyFontSize(
        _ size: CGFloat,
        to range: NSRange,
        in string: NSMutableAttributedString
    ) {
        string.enumerateAttribute(.font, in: range) { currentFont, attrRange, _ in
            guard let font = currentFont as? XMFont else { return }
            let descriptor = font.fontDescriptor
            #if canImport(UIKit)
                let newFont = XMFont(descriptor: descriptor, size: size)
                string.addAttribute(.font, value: newFont, range: attrRange)
            #elseif canImport(AppKit)
                if let newFont = XMFont(descriptor: descriptor, size: size) {
                    string.addAttribute(.font, value: newFont, range: attrRange)
                }
            #endif
        }
    }
}

// MARK: - 跨平台字体 Trait 常量

#if canImport(UIKit)
    private let boldTrait: UIFontDescriptor.SymbolicTraits = .traitBold
    private let italicTrait: UIFontDescriptor.SymbolicTraits = .traitItalic
#elseif canImport(AppKit)
    private let boldTrait: NSFontDescriptor.SymbolicTraits = .bold
    private let italicTrait: NSFontDescriptor.SymbolicTraits = .italic
#endif
