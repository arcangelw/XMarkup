import Foundation

// MARK: - 自定义 NSAttributedString.Key 常量
// 由管线中所有渲染器在 NSMutableAttributedString 上直接设置，
// XMarkupUI 层（NSLayoutManager / AsyncMediaLoader 等）通过相同 key 读取。

extension NSAttributedString.Key {
    /// 标签名称（如 "bold", "heading1", "link"）
    public static let xmarkupTag = NSAttributedString.Key("XMarkup.Tag")

    /// 块类型名称（如 "paragraph", "heading", "blockquote"）
    public static let xmarkupBlockKind = NSAttributedString.Key("XMarkup.BlockKind")

    /// 链接 URL
    public static let xmarkupLinkURL = NSAttributedString.Key("XMarkup.LinkURL")

    /// 标题级别（1-6）
    public static let xmarkupHeadingLevel = NSAttributedString.Key("XMarkup.HeadingLevel")

    /// 列表项信息（如 "ordered:0", "unordered:1"）
    public static let xmarkupListItemInfo = NSAttributedString.Key("XMarkup.ListItemInfo")

    /// 附件引用标识符
    public static let xmarkupAttachmentRef = NSAttributedString.Key("XMarkup.AttachmentRef")
}
