import SwiftUI
import XMarkup

/// 日志视图（SwiftUI）
///
/// 展示 XMarkup 解析引擎的内部日志，支持日志级别切换。
struct LogView: View {
    let example: DemoExample
    @StateObject private var collector = LogCollector()

    var body: some View {
        VStack(spacing: 0) {
            logLevelPicker
            Divider()
            logContent
        }
        .onAppear {
            collector.html = example.html
            collector.secondHTML = example.secondHTML
        }
    }

    // MARK: - Log Level Picker

    private var logLevelPicker: some View {
        VStack(spacing: 8) {
            Picker("日志级别", selection: $collector.logLevel) {
                Text("Error").tag(XMarkupLogLevel.error)
                Text("Warn").tag(XMarkupLogLevel.warn)
                Text("Info").tag(XMarkupLogLevel.info)
                Text("Trace").tag(XMarkupLogLevel.trace)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("共 \(collector.entries.count) 条日志")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let ms = collector.parseDurationMs {
                    Text("耗时 \(String(format: "%.2f", ms)) ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if collector.isParsing {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Log Content

    @ViewBuilder
    private var logContent: some View {
        if collector.entries.isEmpty && !collector.isParsing {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("无日志输出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                List {
                    ForEach(collector.entries) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
                .listStyle(.plain)
                .onChange(of: collector.entries.count) { _, newCount in
                    if newCount > 0 {
                        withAnimation {
                            proxy.scrollTo(collector.entries[newCount - 1].id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Log Row

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            levelIcon(entry.level)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(levelName(entry.level))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(levelColor(entry.level))
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Helpers

    private func levelIcon(_ level: XMarkupLogLevel) -> some View {
        Group {
            switch level {
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .warn:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .info:
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
            case .trace:
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func levelName(_ level: XMarkupLogLevel) -> String {
        switch level {
        case .error: "ERROR"
        case .warn: "WARN"
        case .info: "INFO"
        case .trace: "TRACE"
        }
    }

    private func levelColor(_ level: XMarkupLogLevel) -> Color {
        switch level {
        case .error: .red
        case .warn: .orange
        case .info: .blue
        case .trace: .secondary
        }
    }
}
