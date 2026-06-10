import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 异步媒体加载器

/// 渲染后异步加载媒体附件的独立组件。
///
/// 渲染器（DocumentRenderer）保持同步，只产出带占位图的 AttributedString。
/// AsyncMediaLoader 在渲染后扫描 NSAttributedString 中的 NSTextAttachment，
/// 异步下载图片并更新。所有回调在主线程执行。
///
/// 用法：
/// ```swift
/// let attr = document.render(theme: theme)
/// let nsAttr = NSAttributedStringRenderer().render(attr)
/// textView.attributedText = nsAttr
///
/// let loader = AsyncMediaLoader()
/// loader.loadAttachments(in: nsAttr) { update in
///     switch update {
///     case .updated(let range):
///         textView.layoutManager.invalidateDisplay(for: range)
///     case .completed: break
///     case .failed(_, _): break
///     }
/// }
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

    /// 扫描并异步加载所有附件（回调在主线程执行）
    public func loadAttachments(
        in nsAttr: NSMutableAttributedString,
        update: @escaping @Sendable (Update) -> Void,
        completion: @escaping @Sendable () -> Void
    ) {
        let group = DispatchGroup()
        let fullRange = NSRange(location: 0, length: nsAttr.length)

        // 使用 actor 隔离确保线程安全
        let actor = CallbackActor(update: update, completion: completion)

        nsAttr.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            group.enter()

            let src = self.srcForRange(nsAttr, range: range)
            guard !src.isEmpty, let url = URL(string: src) else {
                Task {
                    await actor.dispatch(.failed(range: range, error: URLError(.badURL)))
                    group.leave()
                }
                return
            }

            if let cached = self.imageCache.object(forKey: src as NSString) {
                self.updateAttachmentImage(nsAttr: nsAttr, range: range, image: cached)
                Task {
                    await actor.dispatch(.updated(range: range))
                    group.leave()
                }
                return
            }

            self.session.dataTask(with: url) { [weak self] data, _, error in
                guard let self = self else { group.leave(); return }

                if let error = error {
                    Task {
                        await actor.dispatch(.failed(range: range, error: error))
                        group.leave()
                    }
                    return
                }
                guard let imageData = data,
                      let decodedImage = Self.decodeImageData(imageData) else {
                    Task {
                        await actor.dispatch(.failed(range: range, error: URLError(.cannotDecodeContentData)))
                        group.leave()
                    }
                    return
                }
                self.imageCache.setObject(decodedImage, forKey: src as NSString)
                self.updateAttachmentImage(nsAttr: nsAttr, range: range, image: decodedImage)
                Task {
                    await actor.dispatch(.updated(range: range))
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

/// 使用 MainActor 隔离回调调用
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
