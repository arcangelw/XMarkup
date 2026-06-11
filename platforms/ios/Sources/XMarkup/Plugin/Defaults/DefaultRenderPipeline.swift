import Foundation

extension RenderPipeline {

    /// 默认渲染管线 — 包含所有默认渲染器
    ///
    /// 渲染器注册顺序决定了优先级：
    /// 1. DefaultTableRenderer — table 优先匹配（返回 nil 则跳过）
    /// 2. DefaultAttachmentRenderer — media attachment 优先匹配
    /// 3. DefaultBlockRenderer — 其余所有 block 类型
    ///
    /// 增强器：默认无（可由 XMarkupUI 等上层模块通过 `addingEnhancers` 追加）
    public static let `default` = RenderPipeline(
        blockRenderers: [
            DefaultTableRenderer(),
            DefaultAttachmentRenderer(),
            DefaultBlockRenderer(),
        ],
        inlineRenderers: [
            DefaultInlineRenderer(),
        ],
        enhancers: []
    )
}
