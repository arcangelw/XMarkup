import Foundation

/// InlineTreeBuilder — 将扁平的 text + [MarkupInline] 重建为 [InlineNode] 树
///
/// 这是 `Flattener.flattenText()` 的逆操作：
/// - Flattener: [InlineNode] → (text, [MarkupInline])
/// - InlineTreeBuilder: (text, [MarkupInline]) → [InlineNode]
///
/// 算法：按范围包含关系构建嵌套树。对于重叠的范围（如 bold[0,6] 内含 italic[2,4]），
/// 外层范围成为父节点，内层范围成为子节点，间隙部分产出 .text 叶子。
public enum InlineTreeBuilder {

    /// 从扁平表示重建 InlineNode 树
    ///
    /// - Parameters:
    ///   - text: 块文本（UTF-16 语义）
    ///   - inlines: 排序后的内联样式数组（按 range.start ASC, range.length DESC）
    /// - Returns: 结构化的 InlineNode 数组
    public static func build(from text: String, inlines: [MarkupInline]) -> [InlineNode] {
        guard !text.isEmpty else { return [] }

        let nsString = text as NSString
        let totalLength = nsString.length

        // 按 start ASC, length DESC 排序（外层先出现）
        let sorted = inlines.sorted { a, b in
            if a.range.start != b.range.start {
                return a.range.start < b.range.start
            }
            return a.range.length > b.range.length
        }

        return buildNodes(text: nsString, inlines: sorted, rangeStart: 0, rangeEnd: totalLength)
    }

    // MARK: - Private

    /// 在指定范围内递归构建 InlineNode
    ///
    /// - Parameters:
    ///   - text: NSString 引用
    ///   - inlines: 所有可能落在此范围内的 inline（已排序）
    ///   - rangeStart: 当前处理范围起始（UTF-16 偏移）
    ///   - rangeEnd: 当前处理范围结束（UTF-16 偏移）
    private static func buildNodes(
        text: NSString,
        inlines: [MarkupInline],
        rangeStart: Int,
        rangeEnd: Int
    ) -> [InlineNode] {
        guard rangeStart < rangeEnd else { return [] }

        // 筛选完全落在 [rangeStart, rangeEnd) 内的顶层 inline
        // "顶层" = 不被同范围内其他 inline 严格包含
        let contained = inlines.filter { inline in
            let s = inline.range.start
            let e = inline.range.start + inline.range.length
            return s >= rangeStart && e <= rangeEnd && inline.range.length > 0
        }

        // 找出顶层节点（不被其他节点严格包含的）
        let topLevel = findTopLevel(contained)

        if topLevel.isEmpty {
            // 无内联样式，纯文本
            let substr = text.substring(with: NSRange(location: rangeStart, length: rangeEnd - rangeStart))
            if substr.isEmpty { return [] }
            return [.text(substr)]
        }

        var result: [InlineNode] = []
        var cursor = rangeStart
        var i = 0

        while i < topLevel.count {
            let first = topLevel[i]
            let inlineStart = first.range.start
            let inlineEnd = inlineStart + first.range.length

            // 间隙文本
            if cursor < inlineStart {
                let gap = text.substring(with: NSRange(location: cursor, length: inlineStart - cursor))
                if !gap.isEmpty {
                    result.append(.text(gap))
                }
            }

            // 收集同范围 inline 链（如 bold+italic+code 覆盖同一段文本）
            // topLevel 已按 start ASC 排序；同范围 inline 按原始排序（Flattener 产出
            // 最内层优先 → 最外层在后），链内顺序即为嵌套顺序
            var chainEnd = i + 1
            while chainEnd < topLevel.count {
                let next = topLevel[chainEnd]
                let ns = next.range.start
                let ne = ns + next.range.length
                if ns == inlineStart && ne == inlineEnd {
                    chainEnd += 1
                } else {
                    break
                }
            }
            let chain = Array(topLevel[i..<chainEnd])
            i = chainEnd

            // 构建子节点 — 只传递严格内部嵌套的 inline（长度小于当前范围），
            // 排除同范围 inline，避免无限递归和重复产出
            let subInlines = contained.filter { sub in
                let s = sub.range.start
                let e = sub.range.start + sub.range.length
                return s >= inlineStart && e <= inlineEnd && (e - s) < (inlineEnd - inlineStart)
            }
            let children = buildNodes(text: text, inlines: subInlines, rangeStart: inlineStart, rangeEnd: inlineEnd)

            // 链式包裹：children → 最内层 inline 包裹 → ... → 最外层
            // chain 顺序 = 最内层在前（Flattener 产出顺序），直接迭代即可
            var wrapped = children
            for chainInline in chain {
                wrapped = [wrapInlineNode(kind: chainInline.kind, children: wrapped)]
            }
            result.append(contentsOf: wrapped)

            cursor = inlineEnd
        }

        // 尾部间隙
        if cursor < rangeEnd {
            let tail = text.substring(with: NSRange(location: cursor, length: rangeEnd - cursor))
            if !tail.isEmpty {
                result.append(.text(tail))
            }
        }

        return result
    }

    /// 从 contained 集合中找出顶层节点（不被其他节点严格包含）
    private static func findTopLevel(_ inlines: [MarkupInline]) -> [MarkupInline] {
        guard !inlines.isEmpty else { return [] }

        var topLevel: [MarkupInline] = []

        for (i, candidate) in inlines.enumerated() {
            let cStart = candidate.range.start
            let cEnd = cStart + candidate.range.length

            var isContained = false
            for (j, other) in inlines.enumerated() where i != j {
                let oStart = other.range.start
                let oEnd = oStart + other.range.length
                // candidate 被 other 严格包含（other 更大或等大但不是同一个）
                if oStart <= cStart && oEnd >= cEnd && other.range.length > candidate.range.length {
                    isContained = true
                    break
                }
            }

            if !isContained {
                topLevel.append(candidate)
            }
        }

        // 按 start 排序确保顺序
        return topLevel.sorted { $0.range.start < $1.range.start }
    }

    /// 将 InlineKind + children 包装为对应的 InlineNode
    private static func wrapInlineNode(kind: InlineKind, children: [InlineNode]) -> InlineNode {
        switch kind {
        case .bold:
            return .bold(children)
        case .italic:
            return .italic(children)
        case .underline:
            return .underline(children)
        case .strikethrough:
            return .strikethrough(children)
        case .code:
            return .code(children)
        case .mark:
            return .mark(children)
        case .link(let url):
            return .link(url: url, children)
        case .subscriptText:
            return .subscriptText(children)
        case .superscript:
            return .superscript(children)
        case .span(let styles):
            return .styled(styles: styles, children)
        case .lineBreak:
            return .lineBreak
        }
    }
}
