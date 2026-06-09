import SwiftUI
import XMarkup

/// Span 原始数据列表视图
struct SpanDataView: View {
    let example: DemoExample
    @State private var result: XMarkupResult?
    @State private var secondResult: XMarkupResult?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            } else if let result {
                plainTextSection(result)
                spansSection(result.spans)
                if let secondResult {
                    Section {
                        Text(secondResult.text)
                            .font(.system(.body, design: .monospaced))
                    } header: {
                        Text("第二段纯文本")
                    }
                    spansSection(secondResult.spans)
                }
            }
        }
        .task {
            parseHTML()
        }
    }

    // MARK: - Sections

    private func plainTextSection(_ result: XMarkupResult) -> some View {
        Section {
            Text(result.text)
                .font(.system(.body, design: .monospaced))
        } header: {
            Text("纯文本")
        }
    }

    private func spansSection(_ spans: [XMarkupSpan]) -> some View {
        Section {
            if spans.isEmpty {
                Text("无 Span 数据")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(spans.enumerated()), id: \.offset) { index, span in
                    spanRow(index: index, span: span)
                }
            }
        } header: {
            Text("Span 列表（\(spans.count) 个）")
        }
    }

    // MARK: - Span Row

    private func spanRow(index: Int, span: XMarkupSpan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("#\(index + 1)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                spanProperty(icon: "tag.fill", label: "Tag", value: tagDescription(span.tag))
                if span.style != .unknown(styleValue: 0) {
                    spanProperty(icon: "paintbrush.fill", label: "Style", value: styleDescription(span.style))
                }
            }

            HStack(spacing: 12) {
                spanProperty(
                    icon: "text.cursor",
                    label: "Range",
                    value: "[\(span.range.location), \(span.range.location + span.range.length))"
                )
                if let value = span.value {
                    spanProperty(icon: "text.quote", label: "Value", value: value)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func spanProperty(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label + ": ")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Description Helpers

    private func tagDescription(_ tag: XMarkupTag) -> String {
        switch tag {
        case .bold: "bold"
        case .italic: "italic"
        case .underline: "underline"
        case .strikethrough: "strikethrough"
        case .subscriptText: "subscript"
        case .superscript: "superscript"
        case .mark: "mark"
        case .code: "code"
        case .paragraph: "paragraph"
        case .heading1: "h1"
        case .heading2: "h2"
        case .heading3: "h3"
        case .heading4: "h4"
        case .heading5: "h5"
        case .heading6: "h6"
        case .blockquote: "blockquote"
        case .preformatted: "pre"
        case .link: "link"
        case .image: "image"
        case .video: "video"
        case .videoSource: "videoSource"
        case .audio: "audio"
        case .audioSource: "audioSource"
        case .listOrdered: "ol"
        case .listUnordered: "ul"
        case .listItem: "li"
        case .table: "table"
        case .tableRow: "tr"
        case .tableCell: "td"
        case .tableHeader: "th"
        case .horizontalRule: "hr"
        case .lineBreak: "br"
        case .division: "div"
        case .span: "span"
        case let .unknown(v): "unknown(\(v))"
        }
    }

    private func styleDescription(_ style: XMarkupStyle) -> String {
        switch style {
        case .foregroundColor: "foregroundColor"
        case .backgroundColor: "backgroundColor"
        case .fontSize: "fontSize"
        case .fontWeight: "fontWeight"
        case .fontStyle: "fontStyle"
        case .textDecoration: "textDecoration"
        case .lineHeight: "lineHeight"
        case .textAlign: "textAlign"
        case .letterSpacing: "letterSpacing"
        case let .unknown(v): "unknown(\(v))"
        }
    }

    // MARK: - Parse

    private func parseHTML() {
        do {
            let parser = try XMarkupParser()
            result = try parser.parse(example.html)
            if let secondHTML = example.secondHTML {
                secondResult = try parser.parse(secondHTML)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            result = nil
        }
    }
}
