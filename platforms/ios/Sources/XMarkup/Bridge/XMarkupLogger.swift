import CXMarkup
import Foundation

// MARK: - 日志级别

/// 日志级别，与 C++ 引擎 XMLogLevel 一一对应
///
/// 控制日志输出的详细程度，通过 `XMarkupParser.init(logLevel:)` 设置。
public enum XMarkupLogLevel: UInt8, Sendable, Equatable, Comparable {
    /// 解析异常（内存分配失败等）
    case error = 0
    /// 容错决策（隐式关闭、标签纠错等）
    case warn = 1
    /// 关键决策节点（解析开始/结束等）
    case info = 2
    /// 详细步骤（状态转换、CSS 标准化等）
    case trace = 3

    public static func < (lhs: XMarkupLogLevel, rhs: XMarkupLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 日志回调类型

/// 日志回调闭包类型
///
/// 在 `XMarkupParser` 初始化时传入，接收引擎内部的日志消息。
///
/// ```swift
/// let parser = try XMarkupParser(
///     logLevel: .trace,
///     logHandler: { level, message in
///         print("[XMarkup.\(level)] \(message)")
///     }
/// )
/// ```
public typealias XMarkupLogHandler = @Sendable (XMarkupLogLevel, String) -> Void

// MARK: - 内部桥接

/// C 日志回调到 Swift 闭包的桥接器
///
/// 使用 `Unmanaged` 将 Swift 闭包持有在堆上，通过 `context` 指针在 C 回调中取回。
/// 生命周期由 `XMarkupParser` 管理（创建时 retain，销毁时 release）。
enum LogBridge {

    /// 将 Swift 闭包包装为 C 回调 + context 指针
    static func wrap(_ handler: @escaping XMarkupLogHandler)
        -> (callback: XMLogCallback, context: UnsafeMutableRawPointer?)
    {
        let box = Unmanaged.passRetained(HandlerBox(handler)).toOpaque()
        return (
            callback: { level, message, ctx in
                guard let ctx else { return }
                let box = Unmanaged<HandlerBox>.fromOpaque(ctx).takeUnretainedValue()
                let msg = message.map { String(cString: $0) } ?? ""
                let swiftLevel = XMarkupLogLevel(rawValue: UInt8(truncatingIfNeeded: level.rawValue)) ?? .error
                box.handler(swiftLevel, msg)
            },
            context: box
        )
    }

    /// 释放闭包持有的内存
    static func release(_ context: UnsafeMutableRawPointer?) {
        guard let context else { return }
        Unmanaged<HandlerBox>.fromOpaque(context).release()
    }

    /// 持有关闭包的 boxing 容器。回调线程取决于 XMarkupParser.parse() 被调用的线程。
    private final class HandlerBox: @unchecked Sendable {
        let handler: XMarkupLogHandler
        init(_ handler: @escaping XMarkupLogHandler) { self.handler = handler }
    }
}
