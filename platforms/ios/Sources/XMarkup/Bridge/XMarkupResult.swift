import CXMarkup
import Foundation

/// XMarkup 解析结果
///
/// 值类型，不可变，`Sendable` 安全。
/// 包含原始解析数据（text + spans），通过 `MarkupDocument.from()` 转换为结构化文档。
///
/// 使用方式：
/// ```swift
/// let result = try parser.parse("<b>Hello</b>")
/// print(result.text)       // "Hello"
/// print(result.spans)      // [XMarkupSpan(tag: .bold, range: (0,5))]
/// let document = MarkupDocument.from(result)
/// let attributed = document.render()
/// ```
public struct XMarkupResult: Sendable {
    /// 纯文本（HTML 标签已移除，实体已解码）
    public let text: String
    /// 样式区间数组
    public let spans: [XMarkupSpan]

    /// 从 C API XMResult 指针转换
    static func fromC(_ cResult: UnsafeMutablePointer<XMResult>) -> XMarkupResult {
        let text = if let t = cResult.pointee.text {
            String(cString: t)
        } else {
            ""
        }

        let count = Int(cResult.pointee.span_count)
        var spans: [XMarkupSpan] = []
        spans.reserveCapacity(count)

        if let cSpans = cResult.pointee.spans {
            for i in 0 ..< count {
                let s = cSpans[i]
                let value: String? = s.value.map { String(cString: $0) }
                spans.append(XMarkupSpan(
                    range: NSRange(location: Int(s.range.start), length: Int(s.range.end - s.range.start)),
                    tag: XMarkupTag(cValue: s.tag),
                    style: XMarkupStyle(cValue: s.style),
                    value: value
                ))
            }
        }

        return XMarkupResult(text: text, spans: spans)
    }
}
