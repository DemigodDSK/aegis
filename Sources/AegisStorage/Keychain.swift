// Keychain.swift
// Thin wrapper over Apple's Keychain Services API.
// Internal-only — callers should go through `AegisStorage`.
//
// Why a wrapper at all: the C-style Keychain API is verbose,
// returns OSStatus codes, and benefits from a single
// well-tested mapping into Swift errors. Centralising it here
// also makes it easy to swap in (or mock around) a different
// secure store in the future without touching every call site.

import Foundation
import Security

enum Keychain {

    /// Set or update a generic-password item. If an item with
    /// the same (service, account) exists, its value and
    /// accessibility are updated; otherwise a new item is
    /// added.
    static func set(
        data: Data,
        service: String,
        account: String,
        accessibility: KeychainAccessibility
    ) throws {
        // Query identifies the item.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.cfAttribute,
        ]

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            updateAttributes as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            // Insert a new item.
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = accessibility.cfAttribute
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStorageError.unhandledStatus(addStatus, op: "SecItemAdd")
            }
        default:
            throw KeychainStorageError.unhandledStatus(updateStatus, op: "SecItemUpdate")
        }
    }

    /// Fetch the data for a generic-password item, or nil if
    /// no such item exists.
    static func get(
        service: String,
        account: String
    ) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStorageError.unhandledStatus(status, op: "SecItemCopyMatching")
        }
    }

    /// Delete a single (service, account) item. No-op if not
    /// present.
    static func delete(
        service: String,
        account: String
    ) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainStorageError.unhandledStatus(status, op: "SecItemDelete")
        }
    }

    /// Delete every generic-password item under `service`,
    /// regardless of account. Test-cleanup convenience.
    static func deleteAll(service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainStorageError.unhandledStatus(status, op: "SecItemDelete (bulk)")
        }
    }
}

/// Errors thrown by AegisStorage's Keychain layer.
public enum KeychainStorageError: Error, Equatable {
    /// A Security-framework call returned an OSStatus we did
    /// not handle explicitly. The associated `op` names the
    /// underlying SecItem… operation; the OSStatus value can
    /// be looked up in `<Security/SecBase.h>`.
    case unhandledStatus(OSStatus, op: String)
}
