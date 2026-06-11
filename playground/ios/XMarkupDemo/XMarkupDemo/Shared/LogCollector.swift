import Combine
import Foundation
import XMarkup

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let level: XMarkupLogLevel
    let message: String
    let timestamp: Date
}

/// 日志收集器（@unchecked Sendable）
///
/// 在解析时作为 `logHandler` 传入 `XMarkupParser`，收集引擎内部日志。
/// Demo App 的「日志」Tab 观察此对象来展示日志列表。
///
/// - Note: 所有 `@Published` 属性仅在主线程写入，解析在后台队列执行。
///   `logHandler` 闭包通过 `DispatchQueue.main.async` 回写，保证线程安全。
///   使用 `generation` 计数器忽略过期 parse 结果，防止并发竞态。
final class LogCollector: ObservableObject, @unchecked Sendable {
    @Published private(set) var entries: [LogEntry] = []
    @Published var logLevel: XMarkupLogLevel = .info

    /// 需要解析的 HTML 内容
    var html: String = ""

    /// 第二段 HTML（可选）
    var secondHTML: String?

    /// 是否正在解析
    @Published private(set) var isParsing = false

    /// 解析耗时（毫秒）
    @Published private(set) var parseDurationMs: Double?

    /// 解析代数计数器 — 每次 reparse 递增，用于忽略过期结果
    private var generation: UInt64 = 0

    // MARK: - Log Handler

    /// 用于传入 XMarkupParser 的日志回调
    ///
    /// 闭包捕获当前 generation，回写时检查是否过期。
    var logHandler: XMarkupLogHandler {
        let expectedGen = generation
        return { [weak self] level, message in
            DispatchQueue.main.async {
                guard let self, self.generation == expectedGen else { return }
                self.entries.append(LogEntry(
                    level: level,
                    message: message,
                    timestamp: Date()
                ))
            }
        }
    }

    // MARK: - Parse

    /// 用当前 logLevel 重新解析 HTML
    ///
    /// 递增 generation 计数器使之前的 parse 结果失效，
    /// 防止多个并发 parse 交叉写入 entries 导致数据错乱或 crash。
    func reparse() {
        generation += 1

        guard !html.isEmpty else {
            entries = []
            parseDurationMs = nil
            return
        }

        entries = []
        isParsing = true
        parseDurationMs = nil

        let currentGen = generation
        let logHandler = self.logHandler // 在主线程捕获，避免后台线程访问计算属性

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let parser = try XMarkupParser(
                    logLevel: self.logLevel,
                    logHandler: logHandler
                )

                let start = CFAbsoluteTimeGetCurrent()
                _ = try parser.parse(self.html)
                if let second = self.secondHTML {
                    _ = try parser.parse(second)
                }
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

                DispatchQueue.main.async {
                    guard self.generation == currentGen else { return }
                    self.parseDurationMs = elapsed
                    self.isParsing = false
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.generation == currentGen else { return }
                    self.entries.append(LogEntry(
                        level: .error,
                        message: "解析异常：\(error.localizedDescription)",
                        timestamp: Date()
                    ))
                    self.isParsing = false
                }
            }
        }
    }
}
