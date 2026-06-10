import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import XMarkup

/// Sendable 包装器，持有 NSLayoutManager 的弱引用
private final class LayoutManagerRef: @unchecked Sendable {
    weak var lm: NSLayoutManager?
    init(_ lm: NSLayoutManager?) { self.lm = lm }
}

extension AsyncMediaLoader {

    /// 加载附件并自动刷新 layoutManager
    ///
    /// - Parameters:
    ///   - nsAttr: 可变的富文本（将被修改 attachment images）
    ///   - layoutManager: 需要刷新的 layoutManager
    ///   - hrMinWidth: hr 最小宽度
    ///   - completion: 所有加载完成后的回调
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString,
        layoutManager: NSLayoutManager?,
        hrMinWidth: CGFloat = 100,
        completion: (@Sendable () -> Void)? = nil
    ) {
        let lmRef = LayoutManagerRef(layoutManager)
        let hrWidth = hrMinWidth
        let fullLength = nsAttr.length

        let originalUpdate: @Sendable (Update) -> Void = { event in
            guard case .updated(let range) = event else { return }
            lmRef.lm?.invalidateDisplay(forCharacterRange: range)
        }

        let originalCompletion: @Sendable () -> Void = {
            guard let lm = lmRef.lm else { return }
            // hr 自适应由视图的布局周期处理，不在 Sendable 闭包中操作 NSAttributedString
            lm.invalidateLayout(
                forCharacterRange: NSRange(location: 0, length: fullLength),
                actualCharacterRange: nil
            )
            completion?()
        }

        loadAttachments(
            in: nsAttr,
            update: originalUpdate,
            completion: originalCompletion
        )
    }
}
