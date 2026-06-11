import Foundation

// MARK: - Span 树节点

/// 块级 span 的树节点，按范围包含关系组织父子层级
private struct SpanNode {
    let span: XMarkupSpan
    var children: [SpanNode] = []
    let resolvedKind: BlockKind  // 此 span 映射的 block kind（不含继承）
}

extension MarkupDocument {

    /// 从 C++ 桥接结果构建 MarkupDocument
    ///
    /// 算法：
    /// 1. 提取所有块级 span
    /// 2. 按范围包含关系构建 Span 树（父 span 范围包含子 span）
    /// 3. 递归平铺树：父 span 的孤立文本（不被子 span 覆盖的部分）→ 父类型块，
    ///    子 span → 递归产块。子范围=父范围时子继承父类型。
    /// 4. 非块级 span 映射为对应块的内联样式
    public static func from(_ result: XMarkupResult) -> MarkupDocument {
        let text = result.text
        let spans = result.spans

        guard !text.isEmpty else {
            return MarkupDocument(blocks: [])
        }

        // 块级 tag 集合
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

        let mediaTags: Set<XMarkupTag> = [.image, .video, .audio]

        let blockSpans = spans.filter { blockTags.contains($0.tag) }
        let inlineSpans = spans.filter { !blockTags.contains($0.tag) }

        // 构建 Span 树 + 平铺为 MarkupBlock[]
        let roots = buildSpanTree(blockSpans, allSpans: spans)
        let blocks = flattenTree(roots, text: text, allSpans: spans, inlineSpans: inlineSpans, mediaTags: mediaTags)

        // 无块级 span 时（如纯内联标签），整段文本作为单个段落
        if blocks.isEmpty {
            let nsRange = NSRange(location: 0, length: (text as NSString).length)
            let inlines = convertToInlines(inlineSpans, in: text, parentRange: nsRange)
            return MarkupDocument(blocks: [
                MarkupBlock(kind: .paragraph, text: text.trimmingTrailingNewlines, inlines: inlines, attachment: nil),
            ])
        }

        return MarkupDocument(blocks: blocks)
    }
}

// MARK: - Span 树构建

extension MarkupDocument {

    /// 从扁平 blockSpans 构建 SpanNode 树
    /// 按 (start ASC, length DESC) 排序后逐节点插入
    private static func buildSpanTree(_ spans: [XMarkupSpan], allSpans: [XMarkupSpan]) -> [SpanNode] {
        let sorted = spans.sorted { a, b in
            if a.range.location != b.range.location {
                return a.range.location < b.range.location
            }
            return a.range.length > b.range.length
        }
        var roots: [SpanNode] = []
        for span in sorted {
            let kind = blockKind(for: span, allSpans: allSpans)
            let node = SpanNode(span: span, children: [], resolvedKind: kind)
            insertNode(&roots, node: node)
        }
        return roots
    }

    /// 递归插入节点到树中（找到最近父节点或作为根）
    private static func insertNode(_ nodes: inout [SpanNode], node: SpanNode) {
        for i in (0..<nodes.count).reversed() {
            if rangeContains(nodes[i].span.range, node.span.range) {
                var child = nodes[i]
                insertNode(&child.children, node: node)
                nodes[i] = child
                return
            }
        }
        nodes.append(node)
    }

    private static func rangeContains(_ outer: NSRange, _ inner: NSRange) -> Bool {
        let outerEnd = outer.location + outer.length
        let innerEnd = inner.location + inner.length
        return inner.location >= outer.location && innerEnd <= outerEnd
    }
}

// MARK: - 树平铺

extension MarkupDocument {

    /// 将 SpanNode 树平铺为 MarkupBlock 列表
    private static func flattenTree(
        _ nodes: [SpanNode], text: String, allSpans: [XMarkupSpan],
        inlineSpans: [XMarkupSpan], mediaTags: Set<XMarkupTag>
    ) -> [MarkupBlock] {
        var blocks: [MarkupBlock] = []
        for node in nodes {
            flattenNode(node, text: text, allSpans: allSpans, inlineSpans: inlineSpans,
                        mediaTags: mediaTags, inheritedKind: nil, blocks: &blocks)
        }
        return blocks
    }

    /// 递归平铺单个节点
    private static func flattenNode(
        _ node: SpanNode, text: String, allSpans: [XMarkupSpan],
        inlineSpans: [XMarkupSpan], mediaTags: Set<XMarkupTag>,
        inheritedKind: BlockKind?, blocks: inout [MarkupBlock]
    ) {
        // 确定最终 blockKind：继承规则
        let effectiveKind: BlockKind
        if let inherited = inheritedKind {
            switch node.resolvedKind {
            case .paragraph, .division:
                effectiveKind = inherited
            default:
                effectiveKind = node.resolvedKind
            }
        } else {
            effectiveKind = node.resolvedKind
        }

        // 对 listItem 注入实际缩进深度：从原始 allSpans 计算
        // 统计包含此 span 的 ul/ol 容器数量，自身范围不计
        let resolvedKind: BlockKind
        if case .listItem(let isOrdered, _) = effectiveKind {
            let indent = computeListItemIndent(for: node.span, in: allSpans)
            resolvedKind = .listItem(isOrdered: isOrdered, indentLevel: indent)
        } else {
            resolvedKind = effectiveKind
        }

        // 表格节点特殊处理：组装 TableStructure
        if case .table = resolvedKind {
            let structure = buildTableStructure(node: node, text: text,
                                                 inlineSpans: inlineSpans, mediaTags: mediaTags)
            blocks.append(MarkupBlock(kind: .table(structure), text: "", inlines: [], attachment: nil))
            return
        }

        let nodeRange = node.span.range

        if node.children.isEmpty {
            // 叶子节点：产出一个块
            let isPre = node.span.tag == .preformatted
            let blockText = extractText(text: text, nsRange: nodeRange, preserveTrailingNewlines: isPre)

            // 附件在文本之前创建（即使文本为空也要生成附件块，如无 alt 的 <img>）
            let attachment: MarkupAttachment?
            if mediaTags.contains(node.span.tag) {
                let src = resolveMediaSrc(node.span, allSpans: allSpans)
                attachment = MarkupAttachment(
                    content: attachmentContent(for: node.span.tag, src: src),
                    suggestedSize: CGSize(width: 200, height: 150),
                    alignment: .default
                )
            } else {
                attachment = nil
            }

            // 无文本且无附件时跳过
            guard !blockText.isEmpty || attachment != nil else { return }

            let inlines = convertToInlines(inlineSpans, in: text, parentRange: nodeRange,
                                            preserveTrailingNewlines: isPre)
            blocks.append(MarkupBlock(kind: resolvedKind, text: blockText, inlines: inlines, attachment: attachment))
            return
        }

        // 有子节点：计算父节点的孤立文本范围
        let nodeEnd = nodeRange.location + nodeRange.length
        var occupied: [(start: Int, end: Int)] = []
        for child in node.children {
            let r = child.span.range
            occupied.append((r.location, r.location + r.length))
        }
        occupied.sort { $0.start < $1.start }

        var cursor = nodeRange.location
        for occ in occupied {
            if occ.start > cursor {
                let len = occ.start - cursor
                guard len > 0 else { continue }  // 防御性：跳过零/负长度 gap
                let gap = NSRange(location: cursor, length: len)
                emitBlock(text: text, range: gap, kind: resolvedKind, inlineSpans: inlineSpans, blocks: &blocks)
            }
            cursor = max(cursor, occ.end)
        }
        if cursor < nodeEnd {
            let gap = NSRange(location: cursor, length: nodeEnd - cursor)
            emitBlock(text: text, range: gap, kind: resolvedKind, inlineSpans: inlineSpans, blocks: &blocks)
        }

        // 递归子节点
        for child in node.children {
            let childInherited: BlockKind?
            if child.span.range.location == nodeRange.location && child.span.range.length == nodeRange.length {
                switch resolvedKind {
                case .division:
                    childInherited = nil
                default:
                    childInherited = resolvedKind
                }
            } else {
                childInherited = nil
            }
            flattenNode(child, text: text, allSpans: allSpans, inlineSpans: inlineSpans,
                        mediaTags: mediaTags, inheritedKind: childInherited, blocks: &blocks)
        }
    }

    /// 计算 listItem 的嵌套深度：统计包含此 span 的 ul/ol 容器数量
    private static func computeListItemIndent(for span: XMarkupSpan, in allSpans: [XMarkupSpan]) -> Int {
        var depth = 0
        for parent in allSpans {
            guard parent.tag == .listOrdered || parent.tag == .listUnordered else { continue }
            if parent.range != span.range && rangeContains(parent.range, span.range) {
                depth += 1
            }
        }
        return depth
    }

    /// 快速产出一个孤立文本块（无列表符号拼接）
    private static func emitBlock(text: String, range: NSRange, kind: BlockKind,
                                  inlineSpans: [XMarkupSpan], blocks: inout [MarkupBlock]) {
        let blockText = extractText(text: text, nsRange: range)
        guard !blockText.isEmpty else { return }
        let inlines = convertToInlines(inlineSpans, in: text, parentRange: range)
        blocks.append(MarkupBlock(kind: kind, text: blockText, inlines: inlines, attachment: nil))
    }

    // MARK: - 表格结构构建

    /// 从 table 节点构建 TableStructure
    private static func buildTableStructure(
        node: SpanNode, text: String,
        inlineSpans: [XMarkupSpan], mediaTags: Set<XMarkupTag>
    ) -> TableStructure {
        var rows: [[MarkupBlock]] = []
        var maxColumns = 0

        for child in node.children {
            guard child.resolvedKind == .tableRow else { continue }

            var rowCells: [MarkupBlock] = []
            for cell in child.children {
                guard cell.resolvedKind == .tableCell || cell.resolvedKind == .tableHeader else { continue }

                let cellRange = cell.span.range
                let cellText = extractText(text: text, nsRange: cellRange)
                let inlines = convertToInlines(inlineSpans, in: text, parentRange: cellRange)

                rowCells.append(MarkupBlock(
                    kind: cell.resolvedKind,
                    text: cellText,
                    inlines: inlines,
                    attachment: nil
                ))
            }
            if !rowCells.isEmpty {
                maxColumns = max(maxColumns, rowCells.count)
                rows.append(rowCells)
            }
        }

        // 补齐空单元格使每行列数一致
        for i in 0..<rows.count {
            while rows[i].count < maxColumns {
                rows[i].append(MarkupBlock(kind: .tableCell, text: "", inlines: [], attachment: nil))
            }
        }

        // 统计表头行数
        let headerCount = rows.prefix(while: { row in
            row.contains { $0.kind == .tableHeader }
        }).count

        return TableStructure(rows: rows, headerRowCount: headerCount, columnCount: maxColumns)
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
        case .table:
            return .table(TableStructure(rows: [], headerRowCount: 0, columnCount: 0))
        case .tableRow:
            return .tableRow
        case .tableCell:
            return .tableCell
        case .tableHeader:
            return .tableHeader
        case .article, .section, .header, .footer, .nav, .aside,
             .figure, .figcaption, .main, .address,
             .definitionList, .definitionTerm, .definitionDescription:
            return .division
        default:
            return .paragraph
        }
    }

    /// 从 NSRange 提取子字符串，默认修剪尾部换行；pre 块保留尾部换行
    private static func extractText(text: String, nsRange: NSRange, preserveTrailingNewlines: Bool = false) -> String {
        let nsString = text as NSString
        guard nsRange.location >= 0,
              nsRange.length >= 0,
              nsRange.location + nsRange.length <= nsString.length else {
            return ""
        }
        let raw = nsString.substring(with: nsRange)
        if preserveTrailingNewlines { return raw }
        return raw.trimmingTrailingNewlines
    }

    /// 将内联 span 转换为 MarkupInline
    /// 生成的 NSRange 是相对于 parentRange.location 的偏移（即相对于块文本起始位置）
    private static func convertToInlines(
        _ spans: [XMarkupSpan],
        in text: String,
        parentRange: NSRange,
        preserveTrailingNewlines: Bool = false
    ) -> [MarkupInline] {
        var inlines: [MarkupInline] = []
        inlines.reserveCapacity(spans.count)

        // 计算当前块的尾部换行修剪位置（仅针对 parentRange 范围）
        // pre 块保留尾部换行，inline span 范围不截断
        let nsString = text as NSString
        let parentEnd = parentRange.location + parentRange.length
        let trimmedBlockEnd: Int
        if preserveTrailingNewlines {
            trimmedBlockEnd = parentEnd
        } else {
            let parentText = nsString.substring(with: parentRange)
            let trimmedParentLength = parentText.trimmingTrailingNewlines.utf16.count
            trimmedBlockEnd = parentRange.location + trimmedParentLength
        }

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
        case .lineBreak:
            return .lineBreak
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
            return .custom(type: "unknown", metadata: ["src": src ?? ""])
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
