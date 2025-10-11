//
//  KeychainManager.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import Security

/// Keychain Manager - Securely stores sensitive information
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.mindflow.app"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Saves data to Keychain
    /// - Parameters:
    ///   - key: The key name
    ///   - value: The value to save
    /// - Returns: Whether the save was successful
    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // Delete existing item if present
        delete(key: key)

        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Keychain: Successfully saved item")
            return true
        } else {
            print("❌ Keychain: Failed to save item - status code: \(status)")
            return false
        }
    }
    
    /// Retrieves data from Keychain
    /// - Parameter key: The key name
    /// - Returns: The corresponding value, or nil if not found
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    /// Deletes data from Keychain
    /// - Parameter key: The key name
    /// - Returns: Whether the deletion was successful
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Clears all Keychain data for this app
    @discardableResult
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

