import Foundation

/// BlockNode 树 → MarkupBlock[] 扁平转换器
///
/// 将树结构的 BlockNode 压平为 text + TextRange 形式的 MarkupBlock[]，
/// 供 NSAttributedString 渲染管线使用。
///
/// Flattener 是纯函数，无平台依赖，可在 Swift/Kotlin/ArkTS 上独立实现。
public enum Flattener {

    // MARK: - Block 扁平化

    /// 将 BlockNode[] 压平为 MarkupBlock[]
    ///
    /// 递归遍历树，嵌套 BlockNode（如 blockquote > paragraph）展开为扁平序列，
    /// 在自定义 key 中记录嵌套层级信息。
    public static func flatten(_ nodes: [BlockNode]) -> [MarkupBlock] {
        var result: [MarkupBlock] = []
        for node in nodes {
            flattenNode(node, indentLevel: 0, into: &result)
        }
        return result
    }

    /// 递归展平 BlockNode，indentLevel 追踪列表嵌套深度
    private static func flattenNode(_ node: BlockNode, indentLevel: Int, into result: inout [MarkupBlock]) {
        switch node {
        case .paragraph(let content):
            let (text, inlines) = flattenText(content)
            result.append(MarkupBlock(kind: .paragraph, text: text, inlines: inlines, attachment: nil))

        case .heading(let level, let content):
            let (text, inlines) = flattenText(content)
            result.append(MarkupBlock(kind: .heading(Level(rawValue: level) ?? .h1),
                                      text: text, inlines: inlines, attachment: nil))

        case .blockquote(let children):
            var childResult: [MarkupBlock] = []
            for child in children {
                flattenNode(child, indentLevel: indentLevel, into: &childResult)
            }
            for block in childResult {
                result.append(MarkupBlock(kind: .blockquote, text: block.text,
                                          inlines: block.inlines, attachment: block.attachment))
            }

        case .preformatted(let content):
            let (text, inlines) = flattenText(content)
            result.append(MarkupBlock(kind: .preformatted, text: text, inlines: inlines, attachment: nil))

        case .definitionTerm(let content):
            let (text, inlines) = flattenText(content)
            result.append(MarkupBlock(kind: .definitionTerm, text: text, inlines: inlines, attachment: nil))

        case .definitionDescription(let content):
            let (text, inlines) = flattenText(content)
            result.append(MarkupBlock(kind: .definitionDescription, text: text, inlines: inlines, attachment: nil))

        case .list(let isOrdered, let items):
            for item in items {
                var itemResult: [MarkupBlock] = []
                for block in item.blocks {
                    if case .list = block {
                        // 嵌套列表：indentLevel + 1
                        flattenNode(block, indentLevel: indentLevel + 1, into: &itemResult)
                    } else {
                        flattenNode(block, indentLevel: indentLevel, into: &itemResult)
                    }
                }
                for block in itemResult {
                    if case .listItem = block.kind {
                        result.append(block)  // 嵌套列表项已携带正确的 indentLevel
                    } else {
                        result.append(MarkupBlock(
                            kind: .listItem(isOrdered: isOrdered, indentLevel: indentLevel),
                            text: block.text, inlines: block.inlines, attachment: block.attachment))
                    }
                }
            }

        case .horizontalRule:
            result.append(MarkupBlock(kind: .horizontalRule, text: "", inlines: [], attachment: nil))

        case .division(_, let children):
            for child in children {
                flattenNode(child, indentLevel: indentLevel, into: &result)
            }

        case .table(let structure):
            result.append(MarkupBlock(kind: .table(structure), text: "", inlines: [], attachment: nil))

        case .media(let attachment):
            result.append(MarkupBlock(kind: .media, text: "\u{FFFC}", inlines: [], attachment: attachment))

        case .custom(_, _, let children):
            for child in children {
                flattenNode(child, indentLevel: indentLevel, into: &result)
            }
        }
    }

    // MARK: - Inline 扁平化

    /// 将 InlineNode[] 压平为 (text: String, inlines: [MarkupInline])
    ///
    /// 递归遍历 InlineNode 树，按深度优先顺序生成连续文本字符串，
    /// 同时记录每个内联样式在文本中的 TextRange 偏移。
    public static func flattenText(_ nodes: [InlineNode]) -> (text: String, inlines: [MarkupInline]) {
        var text = ""
        var inlines: [MarkupInline] = []
        flattenInlineNodes(nodes, into: &text, inlines: &inlines, baseOffset: 0)
        return (text, inlines)
    }

    /// 递归处理 InlineNode，累积文本和 inlines
    @discardableResult
    private static func flattenInlineNodes(
        _ nodes: [InlineNode],
        into text: inout String,
        inlines: inout [MarkupInline],
        baseOffset: Int
    ) -> Int {
        var offset = baseOffset
        for node in nodes {
            switch node {
            case .text(let s):
                text.append(s)
                offset += s.utf16.count

            case .bold(let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .bold))
                }
                offset += childLen

            case .italic(let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .italic))
                }
                offset += childLen

            case .underline(let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .underline))
                }
                offset += childLen

            case .strikethrough(let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .strikethrough))
                }
                offset += childLen

            case .code(let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .code))
                }
                offset += childLen

            case .mark(let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .mark))
                }
                offset += childLen

            case .link(let url, let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .link(url: url)))
                }
                offset += childLen

            case .subscriptText(let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .subscriptText))
                }
                offset += childLen

            case .superscript(let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .superscript))
                }
                offset += childLen

            case .styled(let styles, let children):
                let start = offset
                let childLen = flattenInlineNodes(children, into: &text, inlines: &inlines, baseOffset: offset)
                if childLen > 0 {
                    inlines.append(MarkupInline(range: TextRange(start: start, length: childLen), kind: .span(styles: styles)))
                }
                offset += childLen

            case .lineBreak:
                text.append("\n")
                offset += 1
            }
        }
        return offset - baseOffset
    }
}
