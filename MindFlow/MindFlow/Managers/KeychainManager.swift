//
//  KeychainManager.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import Security
import os.log

/// Keychain Manager - Securely stores sensitive information
class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.mindflow.app"
    private let log = OSLog(subsystem: "com.mindflow.app", category: "Keychain")

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

        // Attempt to add the item atomically.
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus == errSecSuccess {
            os_log("Successfully saved item", log: log, type: .debug)
            return true
        }

        // Item already exists: update its value in place (atomic upsert).
        if addStatus == errSecDuplicateItem {
            let matchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]

            let updateStatus = SecItemUpdate(matchQuery as CFDictionary, attributesToUpdate as CFDictionary)

            if updateStatus == errSecSuccess {
                os_log("Successfully updated item", log: log, type: .debug)
                return true
            } else {
                os_log("Failed to update item - status code: %{public}d", log: log, type: .error, updateStatus)
                return false
            }
        }

        os_log("Failed to save item - status code: %{public}d", log: log, type: .error, addStatus)
        return false
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

