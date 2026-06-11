import Foundation

extension RenderPipeline {

    /// 默认渲染管线 — 包含所有默认渲染器和 key 转移
    ///
    /// 渲染器注册顺序决定了优先级：
    /// 1. DefaultTableRenderer — table 优先匹配（返回 nil 则跳过）
    /// 2. DefaultAttachmentRenderer — media attachment 优先匹配
    /// 3. DefaultBlockRenderer — 其余所有 block 类型
    ///
    /// Key 转移：
    /// - XMarkupKeyTransfer — 转移 XMarkup 内置的自定义 attribute key
    public static let `default` = RenderPipeline(
        blockRenderers: [
            DefaultTableRenderer(),
            DefaultAttachmentRenderer(),
            DefaultBlockRenderer(),
        ],
        inlineRenderers: [
            DefaultInlineRenderer(),
        ],
        postProcessors: [],
        keyTransfers: [XMarkupKeyTransfer()],
        enhancers: []
    )
}
