//
//  ConfigurationManager.swift
//  MindFlow
//
//  Created on 2025-10-12.
//

import Foundation

/// Manages app configuration loaded from Configuration.plist
///
/// This manager provides secure access to configuration values such as:
/// - Supabase project credentials
/// - OAuth redirect URIs
/// - API endpoints
///
/// Configuration values are validated on load and warnings are logged for missing values.
final class ConfigurationManager {

    // MARK: - Singleton

    static let shared = ConfigurationManager()

    // MARK: - Private Properties

    private var configuration: [String: Any]?

    // MARK: - Initialization

    private init() {
        loadConfiguration()
    }

    // MARK: - Private Methods

    private func loadConfiguration() {
        guard let path = Bundle.main.path(forResource: "Configuration", ofType: "plist"),
              let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            Logger.warning("Configuration.plist not found or invalid", category: .general)
            return
        }

        configuration = plist
    }

    // MARK: - Supabase Configuration

    var supabaseURL: String {
        guard let supabase = configuration?["Supabase"] as? [String: String],
              let url = supabase["URL"],
              url != "YOUR_SUPABASE_URL_HERE" else {
            Logger.warning("Supabase URL not configured in Configuration.plist", category: .general)
            return ""
        }
        return url
    }

    var supabaseAnonKey: String {
        guard let supabase = configuration?["Supabase"] as? [String: String],
              let anonKey = supabase["AnonKey"],
              anonKey != "YOUR_SUPABASE_ANON_KEY_HERE" else {
            Logger.warning("Supabase Anon Key not configured in Configuration.plist", category: .general)
            return ""
        }
        return anonKey
    }

    var supabaseRedirectURI: String {
        guard let supabase = configuration?["Supabase"] as? [String: String],
              let redirectURI = supabase["RedirectURI"],
              redirectURI != "YOUR_REDIRECT_URI_HERE" else {
            Logger.warning("Supabase Redirect URI not configured in Configuration.plist, using default", category: .general)
            return "com.mindflow.app:/oauth/callback"
        }
        return redirectURI
    }

    // MARK: - API Configuration

    var zmemoryAPIURL: String {
        guard let api = configuration?["API"] as? [String: String],
              let url = api["ZMemoryURL"],
              url != "YOUR_ZMEMORY_API_URL_HERE" else {
            Logger.warning("ZMemory API URL not configured, using default", category: .general)
            return "https://zmemory.zephyros.app"
        }
        return url
    }
}
