import Foundation
import XMarkup

#if canImport(UIKit) && !os(macOS)
import UIKit

/// XMarkup 标记文档的文本视图（iOS）
///
/// 自动功能：
/// - 注入 BlockquoteLayoutManager 绘制 blockquote 左侧竖线
/// - 布局时更新 hr 分隔线宽度
/// - 可选运行 AsyncMediaLoader 异步加载附件图片
/// - 使用 RenderPipeline 渲染（含平台增强插件）
///
/// 用法：
/// ```swift
/// let textView = XMarkupTextView()
/// textView.load(document)
/// ```
open class XMarkupTextView: UITextView {

    /// 可替换的媒体加载器（默认新建 AsyncMediaLoader）
    public var mediaLoader: AsyncMediaLoader?

    /// 渲染管线（可通过注入自定义管线替换默认行为）
    public var pipeline: RenderPipeline = {
        RenderPipeline(
            blockRenderers: [
                DefaultTableRenderer(),
                DefaultAttachmentRenderer(),
                DefaultBlockRenderer(),
            ],
            inlineRenderers: [DefaultInlineRenderer()],
            enhancers: [PlatformEnhancementPlugin()]
        )
    }()

    /// 加载 MarkupDocument
    /// - Parameters:
    ///   - document: 标记文档
    ///   - theme: 主题配置
    public func load(_ document: MarkupDocument, theme: MarkupTheme = .default) {
        let nsAttr = pipeline.render(document, theme: theme)
        load(nsAttr: nsAttr)
    }

    /// 加载 NSAttributedString
    /// - Parameter nsAttr: 已渲染的富文本
    public func load(nsAttr: NSAttributedString) {
        guard let mutable = nsAttr.mutableCopy() as? NSMutableAttributedString
        else { return }

        // 替换 layoutManager（必须在设置富文本之前替换）
        replaceLayoutManager()

        // 设置富文本
        textStorage.setAttributedString(mutable)

        // hr 自适应
        updateHRWidths()

        // 异步媒体加载
        loadMedia(mutable)
    }

    // MARK: - Private

    private func replaceLayoutManager() {
        let storage = textStorage
        let container = textContainer

        // 移除旧的 layout manager
        for lm in storage.layoutManagers {
            storage.removeLayoutManager(lm)
        }

        // 创建并添加 BlockquoteLayoutManager
        let lm = BlockquoteLayoutManager()
        lm.markupConfig = XMarkupUI.shared.config
        storage.addLayoutManager(lm)
        container.replaceLayoutManager(lm)
    }

    private func updateHRWidths() {
        let storage = textStorage
        HorizontalRuleUpdater.update(
            in: storage,
            containerWidth: bounds.width,
            minWidth: XMarkupUI.shared.config.hrMinWidth
        )
    }

    private func loadMedia(_ nsAttr: NSMutableAttributedString) {
        guard XMarkupUI.shared.config.enableMediaAutoLoad else { return }

        // 先更新 hr 以适配当前宽度
        updateHRWidths()

        let loader = mediaLoader ?? AsyncMediaLoader()
        loader.loadAttachments(
            in: nsAttr,
            layoutManager: layoutManager,
            hrMinWidth: XMarkupUI.shared.config.hrMinWidth
        )
    }
}

#endif
