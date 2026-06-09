import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension MarkupDocument {

    /// 将文档转换为 AttributedString
    ///
    /// 性能策略：按 block 分段构建（init(String, attributes: AttributeContainer)），
    /// 然后一次性 append 拼接。利用 AttributedString 的 COW 优化。
    public func render(theme: MarkupTheme = .default) -> AttributedString {
        guard !blocks.isEmpty else {
            return AttributedString("")
        }

        var result = AttributedString("")

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                result.append(AttributedString("\n"))
            }
            result.append(renderBlock(block, theme: theme))
        }

        return result
    }
}
