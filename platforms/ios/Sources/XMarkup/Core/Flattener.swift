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
            flattenNode(node, into: &result)
        }
        return result
    }

    private static func flattenNode(_ node: BlockNode, into result: inout [MarkupBlock]) {
        switch node {
        case .paragraph(let content):
            let (text, inlines) = flattenText(content)
            result.append(MarkupBlock(kind: .paragraph, text: text, inlines: inlines, attachment: nil))

        case .heading(let level, let content):
            let (text, inlines) = flattenText(content)
            result.append(MarkupBlock(kind: .heading(Level(rawValue: level) ?? .h1),
                                      text: text, inlines: inlines, attachment: nil))

        case .blockquote(let children):
            // 展开嵌套块，保留嵌套关系
            for child in children {
                flattenNode(child, into: &result)
            }

        case .preformatted(let content):
            let (text, inlines) = flattenText(content)
            result.append(MarkupBlock(kind: .preformatted, text: text, inlines: inlines, attachment: nil))

        case .list(let isOrdered, let items):
            for (idx, itemBlocks) in items.enumerated() {
                for itemBlock in itemBlocks {
                    flattenNode(itemBlock, into: &result)
                }
            }

        case .horizontalRule:
            result.append(MarkupBlock(kind: .horizontalRule, text: "", inlines: [], attachment: nil))

        case .division(_, let children):
            for child in children {
                flattenNode(child, into: &result)
            }

        case .table(let structure):
            result.append(MarkupBlock(kind: .table(structure), text: "", inlines: [], attachment: nil))

        case .media(let attachment):
            result.append(MarkupBlock(kind: .paragraph, text: "\u{FFFC}", inlines: [], attachment: attachment))

        case .custom(_, _, let children):
            for child in children {
                flattenNode(child, into: &result)
            }

        case .flatBlock(let kind, let text, let inlines, let attachment):
            result.append(MarkupBlock(kind: kind, text: text, inlines: inlines, attachment: attachment))
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

            case .code(let s):
                let start = offset
                text.append(s)
                let len = s.utf16.count
                inlines.append(MarkupInline(range: TextRange(start: start, length: len), kind: .code))
                offset += len

            case .mark(let s):
                let start = offset
                text.append(s)
                let len = s.utf16.count
                inlines.append(MarkupInline(range: TextRange(start: start, length: len), kind: .mark))
                offset += len

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
