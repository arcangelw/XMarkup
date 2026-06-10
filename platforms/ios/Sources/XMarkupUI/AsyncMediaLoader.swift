import Foundation
import XMarkup

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 异步媒体加载器

/// 渲染后异步加载媒体附件的 UI 层组件。
///
/// Core 层（DocumentRenderer）保持同步，只产出带占位图的 AttributedString
/// 和 `XMarkupAttachmentRefKey` 元数据。AsyncMediaLoader 在 UI 层扫描
/// NSAttributedString 中的 NSTextAttachment，异步下载图片并更新视图。
///
/// 所有 UI 刷新回调保证在主线程执行。
///
/// 用法：
/// ```swift
/// let loader = AsyncMediaLoader()
/// loader.loadAttachments(in: nsAttr, layoutManager: textView.layoutManager)
/// ```
public final class AsyncMediaLoader: @unchecked Sendable {
    private let session: URLSession
    private let imageCache: NSCache<NSString, XMImage>

    public init(session: URLSession = .shared) {
        self.session = session
        self.imageCache = NSCache<NSString, XMImage>()
    }

    public enum Update {
        case updated(range: NSRange)
        case failed(range: NSRange, error: Error)
        case completed
    }

    // MARK: - 高级 API（带 layoutManager 自动刷新）

    /// 加载附件并自动刷新 NSLayoutManager（主线程安全）
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString,
        layoutManager: NSLayoutManager?,
        hrMinWidth: CGFloat = 100,
        completion: (@Sendable () -> Void)? = nil
    ) {
        let lmRef = LayoutManagerRef(layoutManager)
        let fullLength = nsAttr.length

        loadAttachments(
            in: nsAttr,
            update: { event in
                guard case .updated(let range) = event else { return }
                DispatchQueue.main.async {
                    lmRef.lm?.invalidateDisplay(forCharacterRange: range)
                }
            },
            completion: {
                guard let lm = lmRef.lm else { return }
                DispatchQueue.main.async {
                    lm.invalidateLayout(
                        forCharacterRange: NSRange(location: 0, length: fullLength),
                        actualCharacterRange: nil
                    )
                    completion?()
                }
            }
        )
    }

    // MARK: - 底层 API（自定义回调）

    /// 扫描并异步加载所有附件
    /// - Note: update/ completion 回调不保证在主线程，如需 UI 操作请自行 DispatchQueue.main.async
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString,
        update: @escaping @Sendable (Update) -> Void,
        completion: @escaping @Sendable () -> Void
    ) {
        let group = DispatchGroup()
        let fullRange = NSRange(location: 0, length: nsAttr.length)

        let callbackActor = CallbackActor(update: update, completion: completion)

        nsAttr.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let _ = value as? NSTextAttachment else { return }
            group.enter()

            let src = self.srcForRange(nsAttr, range: range)
            guard !src.isEmpty, let url = URL(string: src) else {
                Task {
                    await callbackActor.dispatch(.failed(range: range, error: URLError(.badURL)))
                    group.leave()
                }
                return
            }

            if let cached = self.imageCache.object(forKey: src as NSString) {
                self.updateAttachmentImage(nsAttr: nsAttr, range: range, image: cached)
                Task {
                    await callbackActor.dispatch(.updated(range: range))
                    group.leave()
                }
                return
            }

            self.session.dataTask(with: url) { [weak self] data, _, error in
                guard let self = self else { group.leave(); return }

                if let error = error {
                    Task {
                        await callbackActor.dispatch(.failed(range: range, error: error))
                        group.leave()
                    }
                    return
                }
                guard let imageData = data,
                      let decodedImage = Self.decodeImageData(imageData) else {
                    Task {
                        await callbackActor.dispatch(.failed(range: range, error: URLError(.cannotDecodeContentData)))
                        group.leave()
                    }
                    return
                }
                self.imageCache.setObject(decodedImage, forKey: src as NSString)
                self.updateAttachmentImage(nsAttr: nsAttr, range: range, image: decodedImage)
                Task {
                    await callbackActor.dispatch(.updated(range: range))
                    group.leave()
                }
            }.resume()
        }

        group.notify(queue: .main) { [update, completion] in
            update(.completed)
            completion()
        }
    }

    // MARK: - 私有辅助

    private func srcForRange(_ nsAttr: NSMutableAttributedString, range: NSRange) -> String {
        nsAttr.attribute(
            NSAttributedString.Key(XMarkupAttachmentRefKey.name),
            at: range.location,
            effectiveRange: nil
        ) as? String ?? ""
    }

    private static func decodeImageData(_ data: Data) -> XMImage? {
        return XMImage(data: data)
    }

    private func updateAttachmentImage(
        nsAttr: NSMutableAttributedString, range: NSRange, image: XMImage
    ) {
        guard range.location != NSNotFound else { return }
        guard let attachment = nsAttr.attribute(.attachment, at: range.location,
                                                 effectiveRange: nil) as? NSTextAttachment else { return }
        attachment.image = image
        let maxWidth: CGFloat = 300
        let origSize = image.size
        if origSize.width > maxWidth {
            let ratio = maxWidth / origSize.width
            attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: origSize.height * ratio)
        } else {
            attachment.bounds = CGRect(origin: .zero, size: origSize)
        }
    }
}

// MARK: - 辅助类型

/// Sendable 包装器，持有 NSLayoutManager 的弱引用
private final class LayoutManagerRef: @unchecked Sendable {
    weak var lm: NSLayoutManager?
    init(_ lm: NSLayoutManager?) { self.lm = lm }
}

/// 使用 actor 隔离回调调用
private actor CallbackActor {
    private let update: (AsyncMediaLoader.Update) -> Void
    private let completion: (() -> Void)?

    init(update: @escaping @Sendable (AsyncMediaLoader.Update) -> Void,
         completion: @escaping @Sendable () -> Void) {
        self.update = update
        self.completion = completion
    }

    func dispatch(_ event: AsyncMediaLoader.Update) {
        if case .completed = event {
            completion?()
        } else {
            update(event)
        }
    }
}
