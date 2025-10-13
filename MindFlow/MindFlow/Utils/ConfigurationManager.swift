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
            print("⚠️ Warning: Configuration.plist not found or invalid")
            return
        }

        configuration = plist
    }

    // MARK: - Supabase Configuration

    var supabaseURL: String {
        guard let supabase = configuration?["Supabase"] as? [String: String],
              let url = supabase["URL"],
              url != "YOUR_SUPABASE_URL_HERE" else {
            print("⚠️ Warning: Supabase URL not configured in Configuration.plist")
            return ""
        }
        return url
    }

    var supabaseAnonKey: String {
        guard let supabase = configuration?["Supabase"] as? [String: String],
              let anonKey = supabase["AnonKey"],
              anonKey != "YOUR_SUPABASE_ANON_KEY_HERE" else {
            print("⚠️ Warning: Supabase Anon Key not configured in Configuration.plist")
            return ""
        }
        return anonKey
    }

    var supabaseRedirectURI: String {
        guard let supabase = configuration?["Supabase"] as? [String: String],
              let redirectURI = supabase["RedirectURI"],
              redirectURI != "YOUR_REDIRECT_URI_HERE" else {
            print("⚠️ Warning: Supabase Redirect URI not configured in Configuration.plist")
            return "com.mindflow.app:/oauth/callback"
        }
        return redirectURI
    }
}
