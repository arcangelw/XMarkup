import Foundation

extension MarkupDocument {

    /// 从 C++ 桥接结果构建 MarkupDocument
    ///
    /// 算法：
    /// 1. 遍历所有 spans，识别块级 tag（h1-h6/p/blockquote/li/pre/hr/div/table）
    /// 2. 根据每个块级 span 的 NSRange 提取对应文本
    /// 3. 非块级 span（bold/italic/link/code/mark/...）映射为对应块的 MarkupInline
    /// 4. 媒体类 span（img/video/audio）映射为 MarkupAttachment
    public static func from(_ result: XMarkupResult) -> MarkupDocument {
        let text = result.text
        let spans = result.spans

        guard !text.isEmpty else {
            return MarkupDocument(blocks: [])
        }

        // 块级 tag 集合
        // 注：listOrdered/listUnordered 是容器，不产生独立 block
        let blockTags: Set<XMarkupTag> = [
            .paragraph, .heading1, .heading2, .heading3, .heading4, .heading5, .heading6,
            .blockquote, .preformatted, .horizontalRule, .division,
            .listItem,
            .table, .tableRow, .tableCell, .tableHeader,
            .image, .video, .audio,
            .article, .section, .header, .footer, .nav, .aside,
            .figure, .figcaption, .main, .address,
            .definitionList, .definitionTerm, .definitionDescription,
        ]

        // 媒体 tag 集合
        let mediaTags: Set<XMarkupTag> = [.image, .video, .audio]

        // 提取块级 spans 和内联 spans
        var blockSpans = spans.filter { blockTags.contains($0.tag) }
        let inlineSpans = spans.filter { !blockTags.contains($0.tag) }

        // 去重：如果一个 block span 的范围内存在其他更小的 block span 子集，
        // 则该 span 是容器，移除它以避免内容重复渲染。
        // 例如 <div><p>text</p></div> 产出 div(0,4) 和 p(0,4)，只保留 p。
        // 例如 <table><tr><td>text</td></tr></table> 产出 table/tr/td 三层，只保留 td。
        // 但同类标签嵌套不去重（如 <ol><li>...<ul><li>inner</li></ul></li></ol>，两个 li 都保留）。
        blockSpans = blockSpans.filter { outer in
            let outerStart = outer.range.location
            let outerEnd = outerStart + outer.range.length
            let hasChild = blockSpans.contains { inner in
                if inner.tag == outer.tag { return false }
                let innerStart = inner.range.location
                let innerEnd = innerStart + inner.range.length
                return innerStart >= outerStart && innerEnd <= outerEnd
            }
            return !hasChild
        }

        // 如果没有块级 span，整段文本作为一个 paragraph
        if blockSpans.isEmpty {
            let nsRange = NSRange(location: 0, length: (text as NSString).length)
            let inlines = convertToInlines(inlineSpans, in: text, parentRange: nsRange)
            return MarkupDocument(blocks: [
                MarkupBlock(kind: .paragraph, text: text.trimmingTrailingNewlines, inlines: inlines, attachment: nil),
            ])
        }

        // 为每个块级 span 构建块
        var blocks: [MarkupBlock] = []
        blocks.reserveCapacity(blockSpans.count)

        for span in blockSpans {
            let spanRange = span.range
            let kind = blockKind(for: span, allSpans: spans)
            let blockText = extractText(text: text, nsRange: spanRange)

            // 判断是否为媒体块
            let attachment: MarkupAttachment?
            if mediaTags.contains(span.tag) {
                let src = resolveMediaSrc(span, allSpans: spans)
                attachment = MarkupAttachment(
                    content: attachmentContent(for: span.tag, src: src),
                    suggestedSize: CGSize(width: 200, height: 150),
                    alignment: .default
                )
            } else {
                attachment = nil
            }

            // 收集属于这个块的内联 span
            let inlines = convertToInlines(inlineSpans, in: text, parentRange: spanRange)

            blocks.append(MarkupBlock(
                kind: kind,
                text: blockText,
                inlines: inlines,
                attachment: attachment
            ))
        }

        return MarkupDocument(blocks: blocks)
    }
}

// MARK: - Private Helpers

extension MarkupDocument {

    /// 将 XMarkupTag 映射为 BlockKind
    private static func blockKind(for span: XMarkupSpan, allSpans: [XMarkupSpan]) -> BlockKind {
        switch span.tag {
        case .paragraph:
            return .paragraph
        case .heading1:
            return .heading(.h1)
        case .heading2:
            return .heading(.h2)
        case .heading3:
            return .heading(.h3)
        case .heading4:
            return .heading(.h4)
        case .heading5:
            return .heading(.h5)
        case .heading6:
            return .heading(.h6)
        case .blockquote:
            return .blockquote
        case .preformatted:
            return .preformatted
        case .listItem:
            let listContainers = allSpans.filter { parent in
                (parent.tag == .listOrdered || parent.tag == .listUnordered)
                && parent.range.location <= span.range.location
                && parent.range.location + parent.range.length >= span.range.location + span.range.length
            }
            let nearest = listContainers.min(by: { $0.range.length < $1.range.length })
            let isOrdered = nearest?.tag == .listOrdered
            return .listItem(isOrdered: isOrdered, indentLevel: 0)
        case .horizontalRule:
            return .horizontalRule
        case .division:
            return .division
        case .image, .video, .audio:
            return .paragraph
        case .article, .section, .header, .footer, .nav, .aside,
             .figure, .figcaption, .main, .address,
             .definitionList, .definitionTerm, .definitionDescription:
            return .division
        default:
            return .paragraph
        }
    }

    /// 从 NSRange 提取子字符串，修剪尾部换行
    private static func extractText(text: String, nsRange: NSRange) -> String {
        let nsString = text as NSString
        guard nsRange.location >= 0,
              nsRange.length >= 0,
              nsRange.location + nsRange.length <= nsString.length else {
            return ""
        }
        let raw = nsString.substring(with: nsRange)
        return raw.trimmingTrailingNewlines
    }

    /// 将内联 span 转换为 MarkupInline
    /// 生成的 NSRange 是相对于 parentRange.location 的偏移（即相对于块文本起始位置）
    private static func convertToInlines(
        _ spans: [XMarkupSpan],
        in text: String,
        parentRange: NSRange
    ) -> [MarkupInline] {
        var inlines: [MarkupInline] = []
        inlines.reserveCapacity(spans.count)

        // 计算当前块的尾部换行修剪位置（仅针对 parentRange 范围）
        let nsString = text as NSString
        let parentText = nsString.substring(with: parentRange)
        let trimmedParentLength = parentText.trimmingTrailingNewlines.utf16.count

        let parentEnd = parentRange.location + parentRange.length
        let trimmedBlockEnd = parentRange.location + trimmedParentLength

        for span in spans {
            // inline span 的起始必须在 parentRange 内
            guard span.range.location >= parentRange.location,
                  span.range.location < parentEnd else {
                continue
            }

            // 跳过无样式的 span 容器（tag=span, style=unknown, value=nil）
            // 实际 CSS 属性由独立的 CSS span 携带
            if span.tag == .span, case .unknown = span.style, span.value == nil {
                continue
            }

            let kind = inlineKind(for: span)
            // 跳过空样式 span（无实际 CSS 属性的内联）
            if case .span(let styles) = kind, styles.isEmpty {
                continue
            }

            // 计算相对于块起始位置的 NSRange
            let relativeLocation = span.range.location - parentRange.location

            // 截断超出 parentRange 的尾部，同时考虑尾部换行修剪
            let spanEnd = span.range.location + span.range.length
            let adjustedEnd = min(spanEnd, trimmedBlockEnd)
            let adjustedLength = max(adjustedEnd - span.range.location, 0)

            guard adjustedLength > 0 else { continue }

            let relativeRange = NSRange(location: relativeLocation, length: adjustedLength)
            inlines.append(MarkupInline(range: relativeRange, kind: kind))
        }

        return inlines
    }

    /// 将 XMarkupSpan 映射为 InlineKind
    private static func inlineKind(for span: XMarkupSpan) -> InlineKind {
        // 处理 CSS 样式 span：tag 为 unknown 但 style 为已知 CSS 属性
        if case .unknown = span.tag, span.style != .unknown(styleValue: 0) {
            return .span(styles: inlineStyles(for: span))
        }

        switch span.tag {
        case .bold:
            return .bold
        case .italic:
            return .italic
        case .underline:
            return .underline
        case .strikethrough:
            return .strikethrough
        case .code:
            return .code
        case .mark:
            return .mark
        case .link:
            return .link(url: span.value ?? "")
        case .subscriptText:
            return .subscriptText
        case .superscript:
            return .superscript
        case .span:
            return .span(styles: inlineStyles(for: span))
        default:
            return .span(styles: [])
        }
    }

    /// 从 XMarkupSpan 提取 CSS 行内样式列表
    private static func inlineStyles(for span: XMarkupSpan) -> [InlineStyle] {
        switch span.style {
        case .foregroundColor:
            if let value = span.value {
                return [.foregroundColor(value)]
            }
        case .backgroundColor:
            if let value = span.value {
                return [.backgroundColor(value)]
            }
        case .fontSize:
            if let value = span.value, let f = Float(value) {
                return [.fontSize(f)]
            }
        case .fontWeight:
            if let value = span.value {
                return [.fontWeight(value)]
            }
        case .fontStyle:
            if let value = span.value {
                return [.fontStyle(value)]
            }
        case .textDecoration:
            if let value = span.value {
                return [.textDecoration(value)]
            }
        case .lineHeight:
            if let value = span.value, let f = Float(value) {
                return [.lineHeight(f)]
            }
        case .letterSpacing:
            if let value = span.value, let f = Float(value) {
                return [.letterSpacing(f)]
            }
        case .textAlign:
            if let value = span.value {
                return [.textAlign(value)]
            }
        case .mediaType, .mediaQuery:
            break
        default:
            break
        }
        return []
    }

    /// 解析媒体 src：优先取 span 自身 value，否则查找嵌套的 source 子 span
    private static func resolveMediaSrc(_ span: XMarkupSpan, allSpans: [XMarkupSpan]) -> String? {
        if let src = span.value, !src.isEmpty { return src }

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

    /// 将 tag + src 映射为 AttachmentContent
    private static func attachmentContent(for tag: XMarkupTag, src: String?) -> AttachmentContent {
        switch tag {
        case .image:
            return .image(src: src ?? "")
        case .video:
            return .video(src: src ?? "")
        case .audio:
            return .audio(src: src ?? "")
        default:
            return .image(src: src ?? "")
        }
    }
}

// MARK: - String Helpers

extension String {
    /// 修剪尾部换行符
    var trimmingTrailingNewlines: String {
        var s = self[...]
        while s.last?.isNewline == true { s = s.dropLast() }
        return String(s)
    }
}
