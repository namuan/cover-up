import Foundation
import os.log

// MARK: - AppLogger

/// Rolling file logger. Writes to ~/Library/Logs/CoverUp/.
/// Each app launch creates a new timestamped file; old files beyond `maxFiles` are pruned.
/// Also mirrors every message to the unified logging system (visible in Console.app).
final class AppLogger {

    static let shared = AppLogger()

    // MARK: - Types

    enum Level: String {
        case debug   = "DEBUG"
        case info    = "INFO "
        case warning = "WARN "
        case error   = "ERROR"
    }

    // MARK: - Private state

    private let fileHandle: FileHandle?
    private let logURL: URL
    private let queue = DispatchQueue(label: "com.namuan.coverup.logger", qos: .utility)
    private let tsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
    private let osLog = OSLog(subsystem: "com.namuan.coverup", category: "app")

    // MARK: - Init

    private init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/CoverUp")

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        // One file per launch, named by timestamp
        let nameFormatter = DateFormatter()
        nameFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "coverup-\(nameFormatter.string(from: Date())).log"
        let url = logsDir.appendingPathComponent(fileName)
        FileManager.default.createFile(atPath: url.path, contents: nil)

        self.logURL = url
        self.fileHandle = try? FileHandle(forWritingTo: url)

        AppLogger.pruneOldLogs(in: logsDir, keeping: 10)

        write(format("INFO ", "AppLogger", "AppLogger.swift", 0,
                     "=== CoverUp launching — log: \(url.path) ==="))
        write(format("INFO ", "AppLogger", "AppLogger.swift", 0,
                     "PID: \(ProcessInfo.processInfo.processIdentifier), args: \(ProcessInfo.processInfo.arguments)"))
    }

    // MARK: - Public API

    func log(_ message: String, level: Level = .info,
             context: String = "",
             file: String = #file, function: String = #function, line: Int = #line) {
        let src = URL(fileURLWithPath: file).lastPathComponent
        let entry = format(level.rawValue, context.isEmpty ? src : context, src, line, message)
        write(entry)
        mirror(message, level: level)
    }

    // MARK: - Helpers

    private func format(_ level: String, _ context: String, _ file: String, _ line: Int, _ msg: String) -> String {
        let ts = tsFormatter.string(from: Date())
        return "[\(ts)] [\(level)] [\(file):\(line)] \(msg)"
    }

    private func write(_ line: String) {
        queue.async { [weak self] in
            guard let self, let data = (line + "\n").data(using: .utf8) else { return }
            self.fileHandle?.write(data)
        }
    }

    private func mirror(_ message: String, level: Level) {
        switch level {
        case .debug:   os_log(.debug,  log: osLog, "%{public}@", message)
        case .info:    os_log(.info,   log: osLog, "%{public}@", message)
        case .warning: os_log(.error,  log: osLog, "%{public}@", message)
        case .error:   os_log(.fault,  log: osLog, "%{public}@", message)
        }
    }

    private static func pruneOldLogs(in dir: URL, keeping maxFiles: Int) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let logs = files
            .filter { $0.pathExtension == "log" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a > b          // newest first
            }

        for stale in logs.dropFirst(maxFiles) {
            try? FileManager.default.removeItem(at: stale)
        }
    }
}

// MARK: - Convenience free functions

func logDebug(_ msg: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.log(msg, level: .debug, file: file, function: function, line: line)
}
func logInfo(_ msg: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.log(msg, level: .info, file: file, function: function, line: line)
}
func logWarning(_ msg: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.log(msg, level: .warning, file: file, function: function, line: line)
}
func logError(_ msg: String, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.log(msg, level: .error, file: file, function: function, line: line)
}
