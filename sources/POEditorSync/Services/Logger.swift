import Foundation

// MARK: - Log Level

enum LogLevel {
    case info       // Always shown (main events)
    case verbose    // Shown when verbose mode is enabled
    case debug      // Debug information
}

// MARK: - Logger

struct Logger {
    private let isVerbose: Bool

    init(isVerbose: Bool = false) {
        self.isVerbose = isVerbose
    }

    // MARK: - Public Methods

    /// Log informational message (always shown)
    func info(_ message: String) {
        print(message)
    }

    /// Log verbose message (shown only in verbose mode)
    func verbose(_ message: String) {
        guard isVerbose else { return }
        print(message)
    }

    /// Log debug message (shown only in verbose mode)
    func debug(_ message: String) {
        guard isVerbose else { return }
        print("  🐛 Debug: \(message)")
    }

    // MARK: - Structured Logging

    /// Log section header
    func section(_ title: String, separator: String = "=") {
        let line = String(repeating: separator, count: Constants.sectionSeparatorLength)
        print("\n\(line)")
        print(title)
        print(line)
    }

    /// Log success
    func success(_ message: String) {
        print("✅ \(message)")
    }

    /// Log warning
    func warning(_ message: String) {
        print("⚠️  \(message)")
    }

    /// Log error
    func error(_ message: String) {
        print("❌ \(message)")
    }

    /// Log progress/waiting
    func progress(_ message: String) {
        print("⏳ \(message)")
    }
}
