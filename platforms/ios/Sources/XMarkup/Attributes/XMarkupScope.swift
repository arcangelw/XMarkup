import Foundation

// MARK: - 自定义 AttributedStringKey
// 通过 raw key name 保留在 AttributedString 中，桥接到 NSAttributedString 后可读回
// 全部 public 以供 XMarkupUI 层读取

/// 标签名称（如 "bold", "heading1", "link"）
public struct XMarkupTagKey: AttributedStringKey {
    public typealias Value = String
    public static let name = "XMarkup.Tag"
}

/// 块类型名称（如 "paragraph", "heading", "blockquote"）
public struct XMarkupBlockKindKey: AttributedStringKey {
    public typealias Value = String
    public static let name = "XMarkup.BlockKind"
}

/// 链接 URL
public struct XMarkupLinkURLKey: AttributedStringKey {
    public typealias Value = String
    public static let name = "XMarkup.LinkURL"
}

/// 标题级别（1-6）
public struct XMarkupHeadingLevelKey: AttributedStringKey {
    public typealias Value = Int
    public static let name = "XMarkup.HeadingLevel"
}

/// 列表项信息（如 "ordered:0", "unordered:1"）
public struct XMarkupListItemInfoKey: AttributedStringKey {
    public typealias Value = String
    public static let name = "XMarkup.ListItemInfo"
}

/// 附件引用标识符
public struct XMarkupAttachmentRefKey: AttributedStringKey {
    public typealias Value = String
    public static let name = "XMarkup.AttachmentRef"
}

// MARK: - AttributeScope 注册
// 注册到 AttributeScopes 使自定义 key 参与 AttributedString ↔ NSAttributedString 桥接

extension AttributeScopes {
    var xmarkup: XMarkupScope.Type { XMarkupScope.self }

    enum XMarkupScope: AttributeScope {
        var xmarkupTag: XMarkupTagKey.Type { XMarkupTagKey.self }
        var xmarkupBlockKind: XMarkupBlockKindKey.Type { XMarkupBlockKindKey.self }
        var xmarkupLinkURL: XMarkupLinkURLKey.Type { XMarkupLinkURLKey.self }
        var xmarkupHeadingLevel: XMarkupHeadingLevelKey.Type { XMarkupHeadingLevelKey.self }
        var xmarkupListItemInfo: XMarkupListItemInfoKey.Type { XMarkupListItemInfoKey.self }
        var xmarkupAttachmentRef: XMarkupAttachmentRefKey.Type { XMarkupAttachmentRefKey.self }
    }
}

extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.XMarkupScope, T>) -> T {
        self[T.self]
    }
}
