//
//  KeychainManager.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import Security

/// Keychain 管理器 - 安全存储敏感信息
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.mindflow.app"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 保存数据到 Keychain
    /// - Parameters:
    ///   - key: 键名
    ///   - value: 要保存的值
    /// - Returns: 是否保存成功
    @discardableResult
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // 删除已存在的项
        delete(key: key)
        
        // 创建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Keychain: 成功保存 '\(key)'")
            return true
        } else {
            print("❌ Keychain: 保存失败 '\(key)' - 状态码: \(status)")
            return false
        }
    }
    
    /// 从 Keychain 获取数据
    /// - Parameter key: 键名
    /// - Returns: 对应的值，如果不存在则返回 nil
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
    
    /// 从 Keychain 删除数据
    /// - Parameter key: 键名
    /// - Returns: 是否删除成功
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
    
    /// 清空所有 Keychain 数据
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

