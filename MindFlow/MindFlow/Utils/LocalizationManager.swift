//
//  LocalizationManager.swift
//  MindFlow
//
//  Created on 2025-10-12.
//

import Foundation

/// Localization manager for handling multi-language support
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var currentLanguage: String?
    private var bundle: Bundle?

    private init() {
        // Initialize with system language
        self.currentLanguage = nil
        self.bundle = Bundle.main
    }

    /// Set the app language
    /// - Parameter language: The language to use
    func setLanguage(_ language: AppLanguage) {
        if let languageCode = language.languageCode {
            // Use specific language
            if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                self.bundle = bundle
                self.currentLanguage = languageCode
                print("✅ Language set to: \(languageCode)")
            } else {
                print("⚠️ Language bundle not found for: \(languageCode), using default")
                self.bundle = Bundle.main
                self.currentLanguage = nil
            }
        } else {
            // Use system default
            self.bundle = Bundle.main
            self.currentLanguage = nil
            print("✅ Language set to system default")
        }

        // Trigger UI refresh
        objectWillChange.send()
    }

    /// Get localized string for a given key
    /// - Parameters:
    ///   - key: The localization key
    ///   - comment: Optional comment for context
    /// - Returns: Localized string
    func string(forKey key: String, comment: String = "") -> String {
        return bundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
    }

    /// Get localized string with format arguments
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Format arguments
    /// - Returns: Formatted localized string
    func string(forKey key: String, arguments: CVarArg...) -> String {
        let format = bundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
        return String(format: format, arguments: arguments)
    }
}

// MARK: - String Extension for Convenience

extension String {
    /// Convenience property to get localized string
    var localized: String {
        return LocalizationManager.shared.string(forKey: self)
    }

    /// Get localized string with format arguments
    /// - Parameter arguments: Format arguments
    /// - Returns: Formatted localized string
    func localized(with arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.string(forKey: self)
        return String(format: format, arguments: arguments)
    }
}
