//
//  Logger.swift
//  MindFlow
//
//  Created on 2025-10-13.
//

import Foundation
import os.log

/// Centralized logging utility for MindFlow
///
/// Provides structured logging with different levels and categories.
/// Logs are only active in DEBUG builds by default.
final class Logger {

    // MARK: - Log Levels

    enum Level {
        case debug
        case info
        case warning
        case error

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }

        var prefix: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }

    // MARK: - Categories

    enum Category: String {
        case recording = "Recording"
        case transcription = "Transcription"
        case optimization = "Optimization"
        case storage = "Storage"
        case api = "API"
        case auth = "Auth"
        case ui = "UI"
        case general = "General"

        var osLog: OSLog {
            return OSLog(subsystem: "com.mindflow.app", category: self.rawValue)
        }
    }

    // MARK: - Configuration

    /// Enable/disable logging (automatically disabled in release builds)
    static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Logging Methods

    /// Log a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: Source file (auto-filled)
    ///   - function: Source function (auto-filled)
    ///   - line: Source line (auto-filled)
    static func debug(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// Log an informational message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: Source file (auto-filled)
    ///   - function: Source function (auto-filled)
    ///   - line: Source line (auto-filled)
    static func info(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// Log a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - file: Source file (auto-filled)
    ///   - function: Source function (auto-filled)
    ///   - line: Source line (auto-filled)
    static func warning(
        _ message: String,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// Log an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - error: Optional error object
    ///   - file: Source file (auto-filled)
    ///   - function: Source function (auto-filled)
    ///   - line: Source line (auto-filled)
    static func error(
        _ message: String,
        category: Category = .general,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var fullMessage = message
        if let error = error {
            fullMessage += " - \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, category: category, file: file, function: function, line: line)
    }

    // MARK: - Private Methods

    private static func log(
        _ message: String,
        level: Level,
        category: Category,
        file: String,
        function: String,
        line: Int
    ) {
        guard isEnabled else { return }

        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "\(level.prefix) [\(category.rawValue)] \(message)"

        // Log to system using os_log
        os_log("%{public}@", log: category.osLog, type: level.osLogType, formattedMessage)

        // Also print to console in debug mode for easier development
        #if DEBUG
        print("\(formattedMessage) (\(fileName):\(line))")
        #endif
    }
}
