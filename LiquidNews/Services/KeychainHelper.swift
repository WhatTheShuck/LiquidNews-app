// KeychainHelper.swift
// Thin wrapper around Security framework for storing string values.

import Foundation
import Security
import os

enum KeychainHelper {

    private static let service = "com.WhatTheShuck.LiquidNews"

    /// Stores or overwrites a string value for the given key.
    static func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete by identity only (class + service + account). Attributes like
        // kSecAttrAccessible must NOT appear here: an item written by a prior app
        // version under the default accessibility wouldn't match, so the delete
        // would miss it and the SecItemAdd below would fail with
        // errSecDuplicateItem — silently dropping the credential update on upgrade.
        let identityQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let deleteStatus = SecItemDelete(identityQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            Logger.keychain.error("SecItemDelete failed for key \(key, privacy: .public): \(deleteStatus)")
        }

        var addQuery = identityQuery
        addQuery[kSecValueData] = data
        // Available after the first unlock following a boot, including while
        // locked in the background — matches how the app refreshes state.
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            Logger.keychain.error("SecItemAdd failed for key \(key, privacy: .public): \(addStatus)")
        }
    }

    /// Returns the stored string for the given key, or nil if absent.
    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes the stored value for the given key.
    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.keychain.error("SecItemDelete failed for key \(key, privacy: .public): \(status)")
        }
    }
}
