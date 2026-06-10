import Foundation

#if canImport(UIKit)
import UIKit
typealias PlatformTextList = NSTextList
typealias PlatformMarkerView = NSTextList.MarkerFormat
#elseif canImport(AppKit)
import AppKit
typealias PlatformTextList = NSTextList
typealias PlatformMarkerView = NSTextList.MarkerFormat
#endif

// MARK: - 列表组分析

/// 列表组分析结果：同一组的 listItem 共享 NSTextList 实例
struct BlockGroups {
    /// block 索引 → 共享的 NSTextList 实例数组
    var listTextLists: [Int: [PlatformTextList]] = [:]
}

#if canImport(UIKit) || canImport(AppKit)
typealias MarkerFormat = NSTextList.MarkerFormat
#endif

// MARK: - 两阶段渲染器

/// 两阶段渲染器：先组分析 → 再渲染
struct DocumentRenderer {
    let theme: MarkupTheme

    func render(_ blocks: [MarkupBlock]) -> AttributedString {
        let groups = analyzeBlockGroups(blocks)
        let hasTable = blocks.contains { if case .table = $0.kind { return true }; return false }

        if hasTable {
            return renderWithNSA(blocks, groups: groups)
        }
        return renderWithAS(blocks, groups: groups)
    }
}

// MARK: - 组分析

extension DocumentRenderer {
    func analyzeBlockGroups(_ blocks: [MarkupBlock]) -> BlockGroups {
        var groups = BlockGroups()
        var currentIdx: [Int] = []
        var currentOrdered: Bool?
        var currentIndent: Int?

        for (i, block) in blocks.enumerated() {
            guard case .listItem(let isOrdered, let indent) = block.kind else {
                finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
                currentIdx = []; currentOrdered = nil; currentIndent = nil
                continue
            }
            if currentIdx.isEmpty {
                currentIdx = [i]; currentOrdered = isOrdered; currentIndent = indent
            } else if isOrdered == currentOrdered && indent == currentIndent {
                currentIdx.append(i)
            } else {
                finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
                currentIdx = [i]; currentOrdered = isOrdered; currentIndent = indent
            }
        }
        finalizeGroup(&currentIdx, &groups, ordered: currentOrdered, indent: currentIndent)
        return groups
    }

    private func finalizeGroup(_ idx: inout [Int], _ groups: inout BlockGroups,
                                ordered: Bool?, indent: Int?) {
        guard !idx.isEmpty, let ord = ordered, let ind = indent else { return }
        let lists = buildTextLists(isOrdered: ord, indentLevel: ind)
        for i in idx { groups.listTextLists[i] = lists }
        idx = []
    }

    private func buildTextLists(isOrdered: Bool, indentLevel: Int) -> [PlatformTextList] {
        var lists: [PlatformTextList] = []
        for level in 0...indentLevel {
            let fmt: MarkerFormat = (level == 0)
                ? (isOrdered ? MarkerFormat.decimal : MarkerFormat.disc)
                : (isOrdered ? MarkerFormat.decimal : MarkerFormat.circle)
            lists.append(PlatformTextList(markerFormat: fmt, options: 0))
        }
        return lists
    }
}

// MARK: - AttributedString 路径（无 table）

extension DocumentRenderer {
    func renderWithAS(_ blocks: [MarkupBlock], groups: BlockGroups) -> AttributedString {
        var result = AttributedString("")
        for (i, block) in blocks.enumerated() {
            if i > 0 { result.append(AttributedString("\n")) }
            let attr = renderBlock(block, sharedLists: groups.listTextLists[i], theme: theme)
            result.append(attr)
        }
        return result
    }
}

// MARK: - NSAttributedString 路径（含 table）

extension DocumentRenderer {
    func renderWithNSA(_ blocks: [MarkupBlock], groups: BlockGroups) -> AttributedString {
        let nsResult = NSMutableAttributedString()
        for (i, block) in blocks.enumerated() {
            if i > 0 {
                if case .table = block.kind { continue }
                nsResult.append(NSAttributedString(string: "\n"))
            }
            if case .table(let structure) = block.kind {
                let tableAttr = renderTable(structure, theme: theme)
                nsResult.append(tableAttr)
            } else {
                // TODO(P0-任务2): 传递 sharedLists
                let attr = renderBlock(block, theme: theme)
                nsResult.append(NSAttributedString(attr))
            }
        }
        return AttributedString(nsResult)
    }
}

// MARK: - renderTable 由 TableRenderer.swift 提供（自由函数）
