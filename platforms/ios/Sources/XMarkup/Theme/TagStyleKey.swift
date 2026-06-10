import Foundation

/// 主题配置 key（用于 MarkupTheme.tagStyles 字典）
///
/// 每个 key 对应一种 HTML 标签或元素类型的样式覆盖。
/// 通过 `Tag()` DSL 函数设置：
///
/// ```swift
/// Tag(.code) { $0.uiKit.font = .monospacedSystemFont(ofSize: 14, weight: .regular) }
/// ```
public enum TagStyleKey: String, Sendable, Equatable, Hashable, CaseIterable {
    // 内联样式
    case bold              // <b> / <strong>
    case italic            // <i> / <em>
    case underline         // <u>
    case strikethrough     // <s> / <del>
    case code              // <code>
    case mark              // <mark>
    case link              // <a>
    case subscriptText     // <sub>
    case superscript       // <sup>
    // 块级结构
    case heading           // <h1>~<h6>（统一覆盖，不区分级别）
    case paragraph         // <p>
    case blockquote        // <blockquote>
    case preformatted      // <pre>
    case listItem          // <li>
    case division          // <div>
    case horizontalRule    // <hr>
    // 表格
    case table             // <table>
    case tableRow          // <tr>
    case tableCell         // <td>
    case tableHeader       // <th>
    // 媒体
    case image             // <img>
    case video             // <video>
    case audio             // <audio>
}
