import Foundation
import XMarkup

// MARK: - Spacing 示例专用主题

extension MarkupTheme {

    /// 紧凑排版：段前 2pt、段后 2pt
    static let spacingCompact: MarkupTheme = {
        var theme = MarkupTheme.default
        theme.paragraphSpacing = ParagraphSpacing(spacingBefore: 2, spacingAfter: 2)
        return theme
    }()

    /// 宽松排版 + 行距：段前 16pt、段后 16pt、行距 6pt
    static let spacingRelaxed: MarkupTheme = {
        var theme = MarkupTheme.default
        theme.paragraphSpacing = ParagraphSpacing(spacingBefore: 16, spacingAfter: 16, lineSpacing: 6)
        return theme
    }()

    /// 零间距：段前 0pt、段后 0pt
    static let spacingNone: MarkupTheme = {
        var theme = MarkupTheme.default
        theme.paragraphSpacing = ParagraphSpacing(spacingBefore: 0, spacingAfter: 0)
        return theme
    }()
}
