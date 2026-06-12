import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 列表组分析器 — 识别连续同类型 listItem，构建共享 NSTextList + 序号
///
/// 从 RenderPipeline 抽离，职责单一：
/// - 将扁平 MarkupBlock[] 按连续 (isOrdered, indentLevel) 分组
/// - 为每组构建共享 NSTextList 实例（NSTextList 自动编号依赖同一实例）
/// - 为有序列表项分配 1-based 组内序号
enum ListGroupAnalyzer {

    // MARK: - 分析结果

    struct Groups {
        /// block index → 共享的 NSTextList 实例
        var textLists: [Int: [NSTextList]] = [:]
        /// 组首 block index 集合（控制段前间距）
        var first: Set<Int> = []
        /// 组尾 block index 集合（控制段后间距）
        var last: Set<Int> = []
        /// 有序列表项 → 1-based 组内序号
        var orderedIndices: [Int: Int] = [:]
    }

    // MARK: - 入口

    /// 分析 blocks，返回分组信息
    static func analyze(_ blocks: [MarkupBlock], theme: MarkupTheme) -> Groups {
        var groups = Groups()
        var currentIdx: [Int] = []
        var currentOrdered: Bool?
        var currentIndent: Int?

        for (i, block) in blocks.enumerated() {
            guard case .listItem(let isOrdered, let indent) = block.kind else {
                finalize(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent, theme: theme)
                currentIdx = []; currentOrdered = nil; currentIndent = nil
                continue
            }
            if currentIdx.isEmpty {
                currentIdx = [i]; currentOrdered = isOrdered; currentIndent = indent
            } else if isOrdered == currentOrdered && indent == currentIndent {
                currentIdx.append(i)
            } else {
                finalize(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent, theme: theme)
                currentIdx = [i]; currentOrdered = isOrdered; currentIndent = indent
            }
        }
        finalize(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent, theme: theme)
        return groups
    }

    // MARK: - Private helpers

    private static func finalize(
        _ idx: inout [Int], _ groups: inout Groups,
        ordered: Bool?, indent: Int?, theme: MarkupTheme
    ) {
        guard !idx.isEmpty, let ord = ordered, let ind = indent else { return }
        let lists = buildTextLists(isOrdered: ord, indentLevel: ind, theme: theme)
        groups.first.insert(idx.first!)
        groups.last.insert(idx.last!)
        for i in idx { groups.textLists[i] = lists }
        if ord {
            for (itemIndex, blockIndex) in idx.enumerated() {
                groups.orderedIndices[blockIndex] = itemIndex + 1
            }
        }
        idx = []
    }

    private static func buildTextLists(
        isOrdered: Bool, indentLevel: Int, theme: MarkupTheme
    ) -> [NSTextList] {
        let resolvedList = theme.list.resolved(
            for: MarkupBlock(kind: .listItem(isOrdered: isOrdered, indentLevel: 0),
                             text: "", inlines: [], attachment: nil),
            context: RenderingContext(theme: theme)
        )
        var lists: [NSTextList] = []
        for level in 0...indentLevel {
            let markerType: ListTheme.MarkerType
            if level == 0 {
                markerType = isOrdered ? resolvedList.orderedMarker : resolvedList.unorderedMarker
            } else {
                markerType = isOrdered ? resolvedList.nestedOrderedMarker : resolvedList.nestedUnorderedMarker
            }
            let fmt = ListTheme.markerFormat(for: markerType)
            lists.append(NSTextList(markerFormat: fmt, options: 0))
        }
        return lists
    }
}
