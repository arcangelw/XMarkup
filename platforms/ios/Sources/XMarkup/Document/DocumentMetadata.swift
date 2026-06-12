import Foundation

/// 文档级元数据（跨平台）
///
/// 仅包含所有语言共有的基本字段（String?），
/// 不影响渲染管线，仅供查询。
public struct DocumentMetadata: Sendable, Equatable {
    /// 文档标题（<title>）
    public var title: String?
    /// 语言（<html lang>）
    public var language: String?

    public init(title: String? = nil, language: String? = nil) {
        self.title = title
        self.language = language
    }
}
