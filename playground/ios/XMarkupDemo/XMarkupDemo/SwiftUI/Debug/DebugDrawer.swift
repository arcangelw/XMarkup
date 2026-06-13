import SwiftUI
import XMarkup

/// 调试抽屉（设计规格 §6.5）— 源码 / 解析(Span) / 属性区间 / 日志 四 Tab
///
/// - 源码：example.html（+ appendHTML）原文
/// - 解析：MarkupDocument.source（XMarkupResult.text + spans）— 原始解析数据
/// - 属性：渲染后 NSAttributedString 的属性区间
/// - 日志：LogCollector 接 XMarkupParser 收集引擎内部日志（trace 级）
struct DebugDrawer: View {
    let example: DemoExample
    let document: MarkupDocument?
    let attributedString: NSAttributedString?

    @StateObject private var logger = LogCollector()
    @State private var selectedTab: DebugTab = .source

    private enum DebugTab: String, CaseIterable, Identifiable {
        case source = "源码"
        case parsed = "解析"
        case attributes = "属性"
        case logs = "日志"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("调试").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)

            Picker("", selection: $selectedTab) {
                ForEach(DebugTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.bottom, 10)

            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.medium, .large])
        .onAppear { setupLogger() }
        .onChange(of: example.id) { _ in setupLogger() }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .source:
            SourcePanel(example: example)
        case .parsed:
            ParsedPanel(source: document?.source)
        case .attributes:
            AttributesPanel(attributedString: attributedString)
        case .logs:
            LogsPanel(logger: logger)
        }
    }

    private func setupLogger() {
        logger.logLevel = .trace
        logger.html = example.html
        logger.secondHTML = example.appendHTML
        logger.reparse()
    }
}

// MARK: - 源码

private struct SourcePanel: View {
    let example: DemoExample
    var body: some View {
        ScrollView {
            (
                Text(example.html)
                + (example.appendHTML.map { Text("\n\n<!-- appendHTML -->\n\($0)") } ?? Text(""))
            )
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .textSelection(.enabled)
        }
    }
}

// MARK: - 解析（XMarkupResult: text + spans）

private struct ParsedPanel: View {
    let source: XMarkupResult?

    var body: some View {
        if let source {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("纯文本（\(source.text.count) 字符）")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(source.text.isEmpty ? "（空）" : source.text)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 6))
                            .textSelection(.enabled)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Span 区间（\(source.spans.count) 个，UTF-16 索引）")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if source.spans.isEmpty {
                            Text("（无 span）").font(.caption2).foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(source.spans.enumerated()), id: \.offset) { _, span in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("[\(span.range.location)–\(span.range.location + span.range.length)]")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Text(String(describing: span.tag))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.tint)
                                    if let value = span.value {
                                        Text("→ \(value)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            EmptyHint(text: "无解析结果")
        }
    }
}

// MARK: - 属性区间

private struct AttributesPanel: View {
    let attributedString: NSAttributedString?

    var body: some View {
        if let attr = attributedString, attr.length > 0 {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(segments(attr).enumerated()), id: \.offset) { _, seg in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("[\(seg.range.location)–\(seg.range.location + seg.range.length)]")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text("「\(seg.text)」").font(.caption2)
                            }
                            Text(seg.keys)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 6))
                    }
                }
                .padding(16)
            }
        } else {
            EmptyHint(text: "无渲染结果")
        }
    }

    private struct Segment { let range: NSRange; let text: String; let keys: String }

    private func segments(_ attr: NSAttributedString) -> [Segment] {
        var out: [Segment] = []
        attr.enumerateAttributes(in: NSRange(location: 0, length: attr.length)) { attrs, range, _ in
            let raw = attr.attributedSubstring(from: range).string
            let text = raw.replacingOccurrences(of: "\n", with: " ↵ ")
            let keys = attrs.isEmpty ? "（默认）" : attrs.keys.map(keyName).sorted().joined(separator: " · ")
            out.append(Segment(range: range, text: text, keys: keys))
        }
        return out
    }

    private func keyName(_ key: NSAttributedString.Key) -> String {
        switch key {
        case .font: return "font"
        case .foregroundColor: return "color"
        case .backgroundColor: return "bg"
        case .underlineStyle: return "underline"
        case .strikethroughStyle: return "strikethrough"
        case .link: return "link"
        case .paragraphStyle: return "paragraph"
        case .baselineOffset: return "baseline"
        case .obliqueness: return "oblique"
        case .expansion: return "expand"
        default: return key.rawValue
        }
    }
}

// MARK: - 日志

private struct LogsPanel: View {
    @ObservedObject var logger: LogCollector

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if logger.isParsing { ProgressView().scaleEffect(0.6) }
                if let ms = logger.parseDurationMs {
                    Text("耗时 \(String(format: "%.1f", ms)) ms")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(logger.entries.count) 条").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            Divider()
            ScrollView {
                if logger.entries.isEmpty {
                    EmptyHint(text: "无日志（解析未产生 trace 记录）").padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(logger.entries) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(label(entry.level))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(color(entry.level))
                                    .frame(width: 44, alignment: .leading)
                                Text(entry.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func label(_ level: XMarkupLogLevel) -> String {
        switch level { case .error: return "ERROR"; case .warn: return "WARN"; case .info: return "INFO"; case .trace: return "TRACE" }
    }
    private func color(_ level: XMarkupLogLevel) -> Color {
        switch level { case .error: return .red; case .warn: return .orange; case .info: return .blue; case .trace: return .secondary }
    }
}

// MARK: - 空态

private struct EmptyHint: View {
    let text: String
    var body: some View {
        VStack { Spacer(); Text(text).foregroundStyle(.secondary); Spacer() }.frame(maxWidth: .infinity)
    }
}
